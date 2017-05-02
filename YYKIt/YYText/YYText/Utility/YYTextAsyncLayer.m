//
//  YYTextAsyncLayer.m
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextAsyncLayer.h"
#import <libkern/OSAtomic.h>

/// 在异步绘制过程中用到的异步队列
/// Global display queue, used for content rendering.
static dispatch_queue_t YYTextAsyncLayerGetDisplayQueue() {
#define MAX_QUEUE_COUNT 16
    static int queueCount;
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static int32_t counter = 0;
    dispatch_once(&onceToken, ^{
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            for (NSUInteger i = 0; i < queueCount; i++) {
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
                queues[i] = dispatch_queue_create("com.ibireme.text.render", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                queues[i] = dispatch_queue_create("com.ibireme.text.render", DISPATCH_QUEUE_SERIAL);
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            }
        }
    });
    uint32_t cur = (uint32_t)OSAtomicIncrement32(&counter);
    return queues[(cur) % queueCount];
#undef MAX_QUEUE_COUNT
}

static dispatch_queue_t YYTextAsyncLayerGetReleaseQueue() {
#ifdef YYDispatchQueuePool_h
    return YYDispatchQueueGetForQOS(NSQualityOfServiceDefault);
#else
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
#endif
}


/// YYSentinel是一个线程安全的原子递增计数器，用于判断更新是否取消。
/// a thread safe incrementing counter.
@interface _YYTextSentinel : NSObject
/// Returns the current value of the counter.
@property (atomic, readonly) int32_t value;
/// Increase the value atomically. @return The new value.
- (int32_t)increase;
@end

@implementation _YYTextSentinel {
    int32_t _value;
}
- (int32_t)value {
    return _value;
}
- (int32_t)increase {
    return OSAtomicIncrement32(&_value);
}
@end


@implementation YYTextAsyncLayerDisplayTask
@end


@implementation YYTextAsyncLayer {
    _YYTextSentinel *_sentinel;
}

#pragma mark - Override

+ (id)defaultValueForKey:(NSString *)key {
    if ([key isEqualToString:@"displaysAsynchronously"]) {
        return @(YES);
    } else {
        return [super defaultValueForKey:key];
    }
}

- (instancetype)init {
    self = [super init];
    static CGFloat scale; //global
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scale = [UIScreen mainScreen].scale;
    });
    self.contentsScale = scale;
    _sentinel = [_YYTextSentinel new];
    _displaysAsynchronously = YES;
    return self;
}

- (void)dealloc {
    [_sentinel increase];
}

- (void)setNeedsDisplay {
    [self _cancelAsyncDisplay];
    [super setNeedsDisplay];
}

- (void)display {
    super.contents = super.contents;
    [self _displayAsync:_displaysAsynchronously];
}

#pragma mark - Private

/// 用于异步刷新的
- (void)_displayAsync:(BOOL)async {
    __strong id<YYTextAsyncLayerDelegate> delegate = (id)self.delegate;
    YYTextAsyncLayerDisplayTask *task = [delegate newAsyncDisplayTask];
    
    if (!task.display) {    // 渲染时block为nil， 内容为空
        if (task.willDisplay) task.willDisplay(self);
        self.contents = nil;
        if (task.didDisplay) task.didDisplay(self, YES);
        return;
    }
    
    if (async) {    // 异步渲染
        if (task.willDisplay) task.willDisplay(self);   // 渲染前回调
        
        _YYTextSentinel *sentinel = _sentinel;
        int32_t value = sentinel.value;
        BOOL (^isCancelled)() = ^BOOL() {
            return value != sentinel.value;     // 是否被取消，why，难道被增加了；
        };
        
        // size尺寸、opaque不透明度、scale缩放比例2x-3x;
        CGSize size = self.bounds.size;
        BOOL opaque = self.opaque;
        CGFloat scale = self.contentsScale;
        
        // 不透明且有背景色
        CGColorRef backgroundColor = (opaque && self.backgroundColor) ? CGColorRetain(self.backgroundColor) : NULL;
        if (size.width < 1 || size.height < 1) {        // size < (1, 1);内容置空，同时释放内容image；
            CGImageRef image = (__bridge_retained CGImageRef)(self.contents);
            self.contents = nil;
            if (image) {
                dispatch_async(YYTextAsyncLayerGetReleaseQueue(), ^{
                    CFRelease(image);
                });
            }
            if (task.didDisplay) task.didDisplay(self, YES);
            CGColorRelease(backgroundColor);
            return;
        }
        
        // 异步渲染
        dispatch_async(YYTextAsyncLayerGetDisplayQueue(), ^{
            if (isCancelled()) {    // 取消了
                CGColorRelease(backgroundColor);
                return;
            }
            
            // UIGraphics 开始渲染
            UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (opaque) {
                CGContextSaveGState(context); {
                    
                    // 没有背景色，默认使用白色填充
                    if (!backgroundColor || CGColorGetAlpha(backgroundColor) < 1) {
                        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                    if (backgroundColor) {  // 有背景色
                        CGContextSetFillColorWithColor(context, backgroundColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                } CGContextRestoreGState(context);
                CGColorRelease(backgroundColor);
            }
            
            task.display(context, size, isCancelled);   // 渲染时回调
            
            if (isCancelled()) {    // 取消渲染
                UIGraphicsEndImageContext();
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if (isCancelled()) {    // 还在判断
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isCancelled()) {
                    if (task.didDisplay) task.didDisplay(self, NO);
                } else {
                    self.contents = (__bridge id)(image.CGImage);       // 设置contents为image；
                    if (task.didDisplay) task.didDisplay(self, YES);    // 渲染后回调
                }
            });
        });
    } else {    // 同步渲染，与上面类似
        [_sentinel increase];
        if (task.willDisplay) task.willDisplay(self);
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, self.contentsScale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (self.opaque) {
            CGSize size = self.bounds.size;
            size.width *= self.contentsScale;
            size.height *= self.contentsScale;
            CGContextSaveGState(context); {
                if (!self.backgroundColor || CGColorGetAlpha(self.backgroundColor) < 1) {
                    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                    CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                    CGContextFillPath(context);
                }
                if (self.backgroundColor) {
                    CGContextSetFillColorWithColor(context, self.backgroundColor);
                    CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                    CGContextFillPath(context);
                }
            } CGContextRestoreGState(context);
        }
        task.display(context, self.bounds.size, ^{return NO;});
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        self.contents = (__bridge id)(image.CGImage);
        if (task.didDisplay) task.didDisplay(self, YES);
    }
}

- (void)_cancelAsyncDisplay {
    [_sentinel increase];
}

@end
