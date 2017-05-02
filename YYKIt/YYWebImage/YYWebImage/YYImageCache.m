//
//  YYImageCache.m
//  YYWebImage <https://github.com/ibireme/YYWebImage>
//
//  Created by ibireme on 15/2/15.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYImageCache.h"
#import "YYImage.h"
#import "UIImage+YYWebImage.h"

#if __has_include(<YYImage/YYImage.h>)
#import <YYImage/YYImage.h>
#else
#import "YYImage.h"
#endif

#if __has_include(<YYCache/YYCache.h>)
#import <YYCache/YYCache.h>
#else
#import "YYCache.h"
#endif


// 异步的缓存IO队列 (用于缓存到磁盘)
static inline dispatch_queue_t YYImageCacheIOQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

// 异步的解码队列
static inline dispatch_queue_t YYImageCacheDecodeQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
}


@interface YYImageCache ()
- (NSUInteger)imageCost:(UIImage *)image;
- (UIImage *)imageFromData:(NSData *)data;
@end


@implementation YYImageCache

/**
 *  图片消耗
 */
- (NSUInteger)imageCost:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return 1;
    CGFloat height = CGImageGetHeight(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage); //
    
    NSUInteger cost = bytesPerRow * height;
    if (cost == 0) cost = 1;
    return cost;
}

/**
 *  通过data转换为image
 */
- (UIImage *)imageFromData:(NSData *)data {
    NSData *scaleData = [YYDiskCache getExtendedDataFromObject:data];
    CGFloat scale = 0;
    if (scaleData) {
        scale = ((NSNumber *)[NSKeyedUnarchiver unarchiveObjectWithData:scaleData]).doubleValue;
    }
    if (scale <= 0) scale = [UIScreen mainScreen].scale;
    UIImage *image;
    if (_allowAnimatedImage) {
        image = [[YYImage alloc] initWithData:data scale:scale];
        if (_decodeForDisplay) image = [image yy_imageByDecoded];
    } else {
        YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:scale];
        image = [decoder frameAtIndex:0 decodeForDisplay:_decodeForDisplay].image;
    }
    return image;
}

#pragma mark Public

+ (instancetype)sharedCache {
    static YYImageCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                                   NSUserDomainMask, YES) firstObject];
        // 拼接路径
        cachePath = [cachePath stringByAppendingPathComponent:@"com.ibireme.yykit"];
        cachePath = [cachePath stringByAppendingPathComponent:@"images"];
        cache = [[self alloc] initWithPath:cachePath];
    });
    return cache;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYImageCache init error" reason:@"YYImageCache must be initialized with a path. Use 'initWithPath:' instead." userInfo:nil];
    return [self initWithPath:@""];
}

// 在初始化的时候同时初始化内存缓存跟磁盘缓存
- (instancetype)initWithPath:(NSString *)path {
    
    // 在调用父类init之前先初始化一个内存缓存跟磁盘缓存
    YYMemoryCache *memoryCache = [YYMemoryCache new];   // 生成内存缓存
    memoryCache.shouldRemoveAllObjectsOnMemoryWarning = YES;    // 内存警告的时候删除所有内容
    memoryCache.shouldRemoveAllObjectsWhenEnteringBackground = YES; // 进入后台删除所有内容
    memoryCache.countLimit = NSUIntegerMax; // 不予限制
    memoryCache.costLimit = NSUIntegerMax;  // 不予限制
    memoryCache.ageLimit = 12 * 60 * 60;    // cache存在的时间限制设置为12个小时
    
    YYDiskCache *diskCache = [[YYDiskCache alloc] initWithPath:path];   // 生成磁盘缓存
    diskCache.customArchiveBlock = ^(id object) { return (NSData *)object; };   // 自己来archive数据
    diskCache.customUnarchiveBlock = ^(NSData *data) { return (id)data; };      // 自己unarchive数据
    if (!memoryCache || !diskCache) return nil; // 如果有任意一个初始化失败,返回nil
    
    self = [super init];
    _memoryCache = memoryCache;
    _diskCache = diskCache;
    _allowAnimatedImage = YES;
    _decodeForDisplay = YES;
    return self;
}

- (void)setImage:(UIImage *)image forKey:(NSString *)key {
    [self setImage:image imageData:nil forKey:key withType:YYImageCacheTypeAll];
}

// 通过一个key把图片缓存, 在后台执行；
- (void)setImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key withType:(YYImageCacheType)type {
    
     // 在每一个方法执行前先检查参数的有效性,非常好的习惯
    if (!key || (image == nil && imageData.length == 0)) return;
    
    __weak typeof(self) _self = self;
    if (type & YYImageCacheTypeMemory) { // add to memory cache 添加到内存缓存
        if (image) {
            if (image.yy_isDecodedForDisplay) {     // 直接存image,会减小很多解码的消耗
                
                // 开启了位图解码的话直接把图片丢进内存缓存里面
                [_memoryCache setObject:image forKey:key withCost:[_self imageCost:image]];
            } else {
                // 否则开启一个异步的解码队列,把图片转成位图,再丢进缓存里面
                dispatch_async(YYImageCacheDecodeQueue(), ^{
                    __strong typeof(_self) self = _self;
                    if (!self) return;
                    [self.memoryCache setObject:[image yy_imageByDecoded] forKey:key withCost:[self imageCost:image]];
                });
            }
        } else if (imageData) { // 如果图片不存在,图片数据存在,那就通过data生成一个图片,丢进内存中存起来;
            
            // 开启一个异步的解码队列,把图片转成位图,再丢进缓存里面
            dispatch_async(YYImageCacheDecodeQueue(), ^{
                __strong typeof(_self) self = _self;
                if (!self) return;
                UIImage *newImage = [self imageFromData:imageData];
                [self.memoryCache setObject:newImage forKey:key withCost:[self imageCost:newImage]];
            });
        }
    }
    if (type & YYImageCacheTypeDisk) { // add to disk cache 添加到磁盘缓存
        if (imageData) {
            
            // imageData存在，image为nil，直接将imageData存到磁盘；否则将image转为imageData再存；
            if (image) {
                [YYDiskCache setExtendedData:[NSKeyedArchiver archivedDataWithRootObject:@(image.scale)] toObject:imageData];
            }
            [_diskCache setObject:imageData forKey:key];
        } else if (image) {
            
            // 开启一个异步IO队列，将image转为imageData，并缓存到磁盘
            dispatch_async(YYImageCacheIOQueue(), ^{
                __strong typeof(_self) self = _self;
                if (!self) return;
                NSData *data = [image yy_imageDataRepresentation];
                [YYDiskCache setExtendedData:[NSKeyedArchiver archivedDataWithRootObject:@(image.scale)] toObject:data];
                [self.diskCache setObject:data forKey:key];
            });
        }
    }
}

// 有哪个类型删哪个
- (void)removeImageForKey:(NSString *)key {
    [self removeImageForKey:key withType:YYImageCacheTypeAll];
}

- (void)removeImageForKey:(NSString *)key withType:(YYImageCacheType)type {
    if (type & YYImageCacheTypeMemory) [_memoryCache removeObjectForKey:key];
    if (type & YYImageCacheTypeDisk) [_diskCache removeObjectForKey:key];
}

// 通过key检查缓存中是否有某个图片

- (BOOL)containsImageForKey:(NSString *)key {
    return [self containsImageForKey:key withType:YYImageCacheTypeAll];
}

- (BOOL)containsImageForKey:(NSString *)key withType:(YYImageCacheType)type {
    if (type & YYImageCacheTypeMemory) {
        if ([_memoryCache containsObjectForKey:key]) return YES;
    }
    if (type & YYImageCacheTypeDisk) {
        if ([_diskCache containsObjectForKey:key]) return YES;
    }
    return NO;
}

// 通过key找图片,都比较简单
- (UIImage *)getImageForKey:(NSString *)key {
    return [self getImageForKey:key withType:YYImageCacheTypeAll];
}

- (UIImage *)getImageForKey:(NSString *)key withType:(YYImageCacheType)type {
    if (!key) return nil;
    if (type & YYImageCacheTypeMemory) {
        UIImage *image = [_memoryCache objectForKey:key];
        if (image) return image;
    }
    if (type & YYImageCacheTypeDisk) {
        NSData *data = (id)[_diskCache objectForKey:key];
        UIImage *image = [self imageFromData:data];
        if (image && (type & YYImageCacheTypeMemory)) {
            [_memoryCache setObject:image forKey:key withCost:[self imageCost:image]];
        }
        return image;
    }
    return nil;
}

// 跟上个方法类似,只不过把查询的结果通过block传递了回去
- (void)getImageForKey:(NSString *)key withType:(YYImageCacheType)type withBlock:(void (^)(UIImage *image, YYImageCacheType type))block {
    if (!block) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = nil;
        
        // 内存缓存
        if (type & YYImageCacheTypeMemory) {
            image = [_memoryCache objectForKey:key];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(image, YYImageCacheTypeMemory);
                });
                return;
            }
        }
        
        // 磁盘缓存，
        if (type & YYImageCacheTypeDisk) {
            NSData *data = (id)[_diskCache objectForKey:key];
            image = [self imageFromData:data];
            if (image) {
                [_memoryCache setObject:image forKey:key];      // 磁盘缓存，拿到收据后，要设置到内存缓存
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(image, YYImageCacheTypeDisk);
                });
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(nil, YYImageCacheTypeNone);
        });
    });
}

- (NSData *)getImageDataForKey:(NSString *)key {
    return (id)[_diskCache objectForKey:key];
}



// 异步操作，dispatch_async开线程，最后在主线程调用回调block
- (void)getImageDataForKey:(NSString *)key withBlock:(void (^)(NSData *imageData))block {
    if (!block) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = (id)[_diskCache objectForKey:key];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(data);
        });
    });
}

@end
