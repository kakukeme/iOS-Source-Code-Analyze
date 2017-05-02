//
//  YYWebImageOperation.m
//  YYWebImage <https://github.com/ibireme/YYWebImage>
//
//  Created by ibireme on 15/2/15.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYWebImageOperation.h"
#import "UIImage+YYWebImage.h"
#import <ImageIO/ImageIO.h>
#import <libkern/OSAtomic.h>

#if __has_include(<YYImage/YYImage.h>)
#import <YYImage/YYImage.h>
#else
#import "YYImage.h"
#endif


#define MIN_PROGRESSIVE_TIME_INTERVAL 0.2
#define MIN_PROGRESSIVE_BLUR_TIME_INTERVAL 0.4

/// App Extension中返回nil，否则返回sharedApplication；
/// Returns nil in App Extension.
static UIApplication *_YYSharedApplication() {
    static BOOL isAppExtension = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"UIApplication");
        if(!cls || ![cls respondsToSelector:@selector(sharedApplication)]) isAppExtension = YES;
        if ([[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"]) isAppExtension = YES;
    });
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    return isAppExtension ? nil : [UIApplication performSelector:@selector(sharedApplication)];
#pragma clang diagnostic pop
}

/// 如果右下角限速填充了，返回YES
/// Returns YES if the right-bottom pixel is filled.
static BOOL YYCGImageLastPixelFilled(CGImageRef image) {
    if (!image) return NO;
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    if (width == 0 || height == 0) return NO;
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, 1, 1, 8, 0, YYCGColorSpaceGetDeviceRGB(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrderDefault);
    if (!ctx) return NO;
    CGContextDrawImage(ctx, CGRectMake( -(int)width + 1, 0, width, height), image); // CG 中，原点在左下角；why，or right?
    uint8_t *bytes = CGBitmapContextGetData(ctx);
    BOOL isAlpha = bytes && bytes[0] == 0;
    CFRelease(ctx);
    return !isAlpha;
}

/// Returns JPEG SOS (Start Of Scan) Marker
static NSData *JPEGSOSMarker() {
    // "Start Of Scan" Marker
    static NSData *marker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uint8_t bytes[2] = {0xFF, 0xDA};
        marker = [NSData dataWithBytes:bytes length:2];
    });
    return marker;
}


static NSMutableSet *URLBlacklist;
static dispatch_semaphore_t URLBlacklistLock;   // 黑名单锁, 使用dispatch_semaphore_t 实现，而不是OSSpinLock(自旋锁)，具体见博主说明

static void URLBlacklistInit() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        URLBlacklist = [NSMutableSet new];
        URLBlacklistLock = dispatch_semaphore_create(1);
    });
}

// 黑名单是否已经包含这个url
static BOOL URLBlackListContains(NSURL *url) {
    if (!url || url == (id)[NSNull null]) return NO;
    URLBlacklistInit();
    dispatch_semaphore_wait(URLBlacklistLock, DISPATCH_TIME_FOREVER);
    BOOL contains = [URLBlacklist containsObject:url];
    dispatch_semaphore_signal(URLBlacklistLock);
    return contains;
}

// 把url添加进黑名单
static void URLInBlackListAdd(NSURL *url) {
    if (!url || url == (id)[NSNull null]) return;
    URLBlacklistInit();
    dispatch_semaphore_wait(URLBlacklistLock, DISPATCH_TIME_FOREVER);
    [URLBlacklist addObject:url];
    dispatch_semaphore_signal(URLBlacklistLock);
}


/// A proxy used to hold a weak object.
// 代理proxy用来持有弱引用对象。用来避免循环引用，YYImage中说明；

@interface _YYWebImageWeakProxy : NSProxy
@property (nonatomic, weak, readonly) id target;
- (instancetype)initWithTarget:(id)target;
+ (instancetype)proxyWithTarget:(id)target;
@end

@implementation _YYWebImageWeakProxy
- (instancetype)initWithTarget:(id)target {
    _target = target;
    return self;
}
+ (instancetype)proxyWithTarget:(id)target {
    return [[_YYWebImageWeakProxy alloc] initWithTarget:target];
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}
- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}
- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}
- (NSUInteger)hash {
    return [_target hash];
}
- (Class)superclass {
    return [_target superclass];
}
- (Class)class {
    return [_target class];
}
- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}
- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}
- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}
- (BOOL)isProxy {
    return YES;
}
- (NSString *)description {
    return [_target description];
}
- (NSString *)debugDescription {
    return [_target debugDescription];
}
@end


@interface YYWebImageOperation() <NSURLConnectionDelegate>
@property (readwrite, getter=isExecuting) BOOL executing;
@property (readwrite, getter=isFinished) BOOL finished;
@property (readwrite, getter=isCancelled) BOOL cancelled;
@property (readwrite, getter=isStarted) BOOL started;       // operation 状态管理

@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, assign) NSInteger expectedSize;
@property (nonatomic, assign) UIBackgroundTaskIdentifier taskID;

@property (nonatomic, assign) NSTimeInterval lastProgressiveDecodeTimestamp;
@property (nonatomic, strong) YYImageDecoder *progressiveDecoder;
@property (nonatomic, assign) BOOL progressiveIgnored;
@property (nonatomic, assign) BOOL progressiveDetected;
@property (nonatomic, assign) NSUInteger progressiveScanedLength;
@property (nonatomic, assign) NSUInteger progressiveDisplayCount;

@property (nonatomic, copy) YYWebImageProgressBlock progress;
@property (nonatomic, copy) YYWebImageTransformBlock transform;
@property (nonatomic, copy) YYWebImageCompletionBlock completion;
@end


@implementation YYWebImageOperation
@synthesize executing = _executing;
@synthesize finished = _finished;
@synthesize cancelled = _cancelled;

/// 线程加入runloop中进行保活吧； why，？

/// Network thread entry point.
+ (void)_networkThreadMain:(id)object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.ibireme.webimage.request"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

/// 这里是一个全局的网络请求线程,提供给 NSURLConnection 的代理使用的
/// Global image request network thread, used by NSURLConnection delegate.
+ (NSThread *)_networkThread {
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(_networkThreadMain:) object:nil];
        if ([thread respondsToSelector:@selector(setQualityOfService:)]) {
            thread.qualityOfService = NSQualityOfServiceBackground;     // 后台优先级
        }
        [thread start];     // 启动线程
    });
    return thread;
}

/// 全局图片并发队列,用于读取图片，并解码
/// Global image queue, used for image reading and decoding.
+ (dispatch_queue_t)_imageQueue {
    #define MAX_QUEUE_COUNT 16
    static int queueCount;
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static int32_t counter = 0;
    dispatch_once(&onceToken, ^{
        
        // 并发队列的个数，根据cpu内核数确定
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        
        // iOS 8.0之后，创建 并发队列 接口不同
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            for (NSUInteger i = 0; i < queueCount; i++) {
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
                queues[i] = dispatch_queue_create("com.ibireme.image.decode", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                queues[i] = dispatch_queue_create("com.ibireme.image.decode", DISPATCH_QUEUE_SERIAL);
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            }
        }
    });
    int32_t cur = OSAtomicIncrement32(&counter);
    if (cur < 0) cur = -cur;
    return queues[(cur) % queueCount];
    #undef MAX_QUEUE_COUNT
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYWebImageOperation init error" reason:@"YYWebImageOperation must be initialized with a request. Use the designated initializer to init." userInfo:nil];
    return [self initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@""]] options:0 cache:nil cacheKey:nil progress:nil transform:nil completion:nil];
}

/**
 *  构造方法
 *
 *  @param request    请求
 *  @param options    option
 *  @param cache      缓存
 *  @param cacheKey   缓存key
 *  @param progress   进入
 *  @param transform  预处理
 *  @param completion 完成
 *
 */
- (instancetype)initWithRequest:(NSURLRequest *)request
                        options:(YYWebImageOptions)options
                          cache:(YYImageCache *)cache
                       cacheKey:(NSString *)cacheKey
                       progress:(YYWebImageProgressBlock)progress
                      transform:(YYWebImageTransformBlock)transform
                     completion:(YYWebImageCompletionBlock)completion {
    self = [super init];
    if (!self) return nil;
    if (!request) return nil;
    _request = request;
    _options = options;
    _cache = cache;
    _cacheKey = cacheKey ? cacheKey : request.URL.absoluteString;
    _shouldUseCredentialStorage = YES;
    _progress = progress;
    _transform = transform;
    _completion = completion;
    _executing = NO;
    _finished = NO;
    _cancelled = NO;
    _taskID = UIBackgroundTaskInvalid;
    _lock = [NSRecursiveLock new];
    return self;
}

/**
 析构方法里面使用了递归锁防止死锁,因为请求可能是有多个的.
 这个方法里面的操作可以保证开启了新的操作队列不会被旧的影响,同时把该清理的状态都归位完毕
 */
- (void)dealloc {
    [_lock lock];
    if (_taskID != UIBackgroundTaskInvalid) {
        [_YYSharedApplication() endBackgroundTask:_taskID];
        _taskID = UIBackgroundTaskInvalid;
    }
    // 如果正在执行
    if ([self isExecuting]) {
        self.cancelled = YES;
        self.finished = YES;
        if (_connection) {
            [_connection cancel];   // 取消连接connection
            
            if (![_request.URL isFileURL] && (_options & YYWebImageOptionShowNetworkActivity)) {
                [YYWebImageManager decrementNetworkActivityCount];  // 请求指示符数量-1
            }
        }
        
         // 如果完成的回调存在,开启一个自动释放池,把参数传空,全置为nil,
        if (_completion) {
            @autoreleasepool {
                _completion(nil, _request.URL, YYWebImageFromNone, YYWebImageStageCancelled, nil);
            }
        }
    }
    [_lock unlock];
}

// 结束后台任务，加递归锁
- (void)_endBackgroundTask {
    [_lock lock];
    if (_taskID != UIBackgroundTaskInvalid) {
        [_YYSharedApplication() endBackgroundTask:_taskID];
        _taskID = UIBackgroundTaskInvalid;
    }
    [_lock unlock];
}

#pragma mark - Runs in operation thread

/**
 
 由于NSOperation的isCancelled方法并不是能够实时监测的,所以在进行任何一个关键操作步骤的时候都要进行检测请求是否被取消掉了,
 如果取消,直接结束当前所有任务,并对状态值进行正确的赋值.
 
 */


// 结束方法
- (void)_finish {
    self.executing = NO;
    self.finished = YES;
    [self _endBackgroundTask];
}

// 开启一个操作,
// runs on network thread
- (void)_startOperation {
    
    // 如果取消了直接返回,开启一个自动释放池完成以下操作
    if ([self isCancelled]) return;
    @autoreleasepool {
        // get image from cache
        
        // 如果缓存存在,并且option不等于使用NSURLCache,并且option不是刷新缓存,
        // 那么直接通过缓存key从缓存中取取图片,同时设置缓存类型为内存缓存;
        if (_cache &&
            !(_options & YYWebImageOptionUseNSURLCache) &&
            !(_options & YYWebImageOptionRefreshImageCache)) {
            
            // 1.1 从内存缓存中获取
            UIImage *image = [_cache getImageForKey:_cacheKey withType:YYImageCacheTypeMemory];
            if (image) {
                [_lock lock];
                if (![self isCancelled]) {
                    
                    // 将数据，通过completion block传递回去；
                    if (_completion) _completion(image, _request.URL, YYWebImageFromMemoryCache, YYWebImageStageFinished, nil);
                }
                [self _finish];
                [_lock unlock];
                return;
            }
            
            
            if (!(_options & YYWebImageOptionIgnoreDiskCache)) {
                __weak typeof(self) _self = self;
                
                // 开启一个同步的线程
                dispatch_async([self.class _imageQueue], ^{
                    __strong typeof(_self) self = _self;
                    if (!self || [self isCancelled]) return;
                    
                    // 1.2 从磁盘缓存中获取；
                    UIImage *image = [self.cache getImageForKey:self.cacheKey withType:YYImageCacheTypeDisk];
                    if (image) {
                        
                        // 先把图片再存进内存缓存
                        [self.cache setImage:image imageData:nil forKey:self.cacheKey withType:YYImageCacheTypeMemory];
                        
                        // 在网络线程调用_didReceiveImageFromDiskCache方法
                        [self performSelector:@selector(_didReceiveImageFromDiskCache:) onThread:[self.class _networkThread] withObject:image waitUntilDone:NO];
                    } else {
                        
                        // 1.3 没有取到图片,就开始在网络线程,开始请求
                        [self performSelector:@selector(_startRequest:) onThread:[self.class _networkThread] withObject:nil waitUntilDone:NO];
                    }
                });
                return;
            }
        }
    }
    
    // 2、不存在缓存，在网络线程立刻开始请求
    [self performSelector:@selector(_startRequest:) onThread:[self.class _networkThread] withObject:nil waitUntilDone:NO];
}

// 开始网罗请求
// runs on network thread
- (void)_startRequest:(id)object {
    if ([self isCancelled]) return;
    @autoreleasepool {
        
        // 如果模式是YYWebImageOptionIgnoreFailedURL,并且黑名单里面存在这个URL,
        if ((_options & YYWebImageOptionIgnoreFailedURL) && URLBlackListContains(_request.URL)) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{ NSLocalizedDescriptionKey : @"Failed to load URL, blacklisted." }];
            [_lock lock];
            if (![self isCancelled]) {
                if (_completion) _completion(nil, _request.URL, YYWebImageFromNone, YYWebImageStageFinished, error);
            }
            [self _finish];
            [_lock unlock];
            return;
        }
        
        // 文件url；这步计算文件size的
        if (_request.URL.isFileURL) {
            NSArray *keys = @[NSURLFileSizeKey];
            NSDictionary *attr = [_request.URL resourceValuesForKeys:keys error:nil];
            NSNumber *fileSize = attr[NSURLFileSizeKey];
            _expectedSize = fileSize ? fileSize.unsignedIntegerValue : -1;
        }
        
        // 开始下载了,先锁一下
        // request image from web
        [_lock lock];
        if (![self isCancelled]) {
            
            // 创建NSURLConnection，并设置代理
            _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:[_YYWebImageWeakProxy proxyWithTarget:self]];
            
            // 不是文件，增加网络指示符
            if (![_request.URL isFileURL] && (_options & YYWebImageOptionShowNetworkActivity)) {
                [YYWebImageManager incrementNetworkActivityCount];
            }
        }
        
        // 结果出来了,解锁
        [_lock unlock];
    }
}

// 取消操作，运行在网络线程 network thread
// runs on network thread, called from outer "cancel"
- (void)_cancelOperation {
    
    // 过程和dealloc类似
    @autoreleasepool {
        if (_connection) {
            if (![_request.URL isFileURL] && (_options & YYWebImageOptionShowNetworkActivity)) {
                [YYWebImageManager decrementNetworkActivityCount];
            }
        }
        [_connection cancel];
        _connection = nil;
        if (_completion) _completion(nil, _request.URL, YYWebImageFromNone, YYWebImageStageCancelled, nil);
        [self _endBackgroundTask];
    }
}

// 从disk缓存中找到image数据，运行在网络线程 network thread
// runs on network thread
- (void)_didReceiveImageFromDiskCache:(UIImage *)image {
    @autoreleasepool {
        [_lock lock];
        if (![self isCancelled]) {   // 内存警告, 没有被取消，需要处理image数据；
            if (image) {
                if (_completion) _completion(image, _request.URL, YYWebImageFromDiskCache, YYWebImageStageFinished, nil);
                [self _finish];
            } else {
                [self _startRequest:nil];   // 重新开请求
            }
        }
        [_lock unlock];
    }
}

// 从网络中，下载到图片image；
- (void)_didReceiveImageFromWeb:(UIImage *)image {
    @autoreleasepool {
        [_lock lock];
        if (![self isCancelled]) {
            
            
            if (_cache) {
                if (image || (_options & YYWebImageOptionRefreshImageCache)) {
                    
                    // 设置缓存
                    NSData *data = _data;
                    dispatch_async([YYWebImageOperation _imageQueue], ^{
                        [_cache setImage:image imageData:data forKey:_cacheKey withType:YYImageCacheTypeAll];
                    });
                }
            }
            _data = nil;
            NSError *error = nil;
            
            // 如果没有图片
            if (!image) {
                error = [NSError errorWithDomain:@"com.ibireme.image" code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"Web image decode fail." }];
                if (_options & YYWebImageOptionIgnoreFailedURL) {
                    if (URLBlackListContains(_request.URL)) {
                        error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{ NSLocalizedDescriptionKey : @"Failed to load URL, blacklisted." }];
                    } else {
                        URLInBlackListAdd(_request.URL);
                    }
                }
            }
            
            // 把结果与error同时传递给完成block
            if (_completion) _completion(image, _request.URL, YYWebImageFromRemote, YYWebImageStageFinished, error);
            
            // 结束
            [self _finish];
        }
        [_lock unlock];
    }
}

#pragma mark - NSURLConnectionDelegate runs in operation thread

/**
 
 NSURLColleciton 接收数据 代理
 */

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
    return _shouldUseCredentialStorage;
}

// 即将发送请求验证, 暂时不管
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    @autoreleasepool {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            if (!(_options & YYWebImageOptionAllowInvalidSSLCertificates) &&
                [challenge.sender respondsToSelector:@selector(performDefaultHandlingForAuthenticationChallenge:)]) {
                [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
            } else {
                NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            }
        } else {
            if ([challenge previousFailureCount] == 0) {
                if (_credential) {
                    [[challenge sender] useCredential:_credential forAuthenticationChallenge:challenge];
                } else {
                    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
                }
            } else {
                [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
            }
        }
    }
}

// 即将缓存请求结果
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    if (!cachedResponse) return cachedResponse;
    if (_options & YYWebImageOptionUseNSURLCache) {     // 使用 NSURLCache
        return cachedResponse;
    } else {
        // ignore NSURLCache
        return nil;
    }
}

// 请求已经收到响应
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    @autoreleasepool {
        NSError *error = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (id) response;
            NSInteger statusCode = httpResponse.statusCode;
            if (statusCode >= 400 || statusCode == 304) {   // NSHTTPURLResponse 出错的响应码
                error = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:nil];
            }
        }
        if (error) {    // 有error了,取消连接,调用连接失败的方法同时把error传递过去
            [_connection cancel];
            [self connection:_connection didFailWithError:error];
        } else {
            if (response.expectedContentLength) {
                _expectedSize = (NSInteger)response.expectedContentLength;  // expectedSize是总共大小
                if (_expectedSize < 0) _expectedSize = -1;
            }
            _data = [NSMutableData dataWithCapacity:_expectedSize > 0 ? _expectedSize : 0];
            if (_progress) {
                [_lock lock];
                if (![self isCancelled]) _progress(0, _expectedSize);   // 进度回调block;
                [_lock unlock];
            }
        }
    }
}

// 收到数据回调
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    @autoreleasepool {
        [_lock lock];
        BOOL canceled = [self isCancelled];
        [_lock unlock];
        if (canceled) return;   // 如果取消了,直接返回
        
        // 如果data存在,拼接data,把计算data大小传递给进度回调block
        if (data) [_data appendData:data];
        if (_progress) {
            [_lock lock];
            if (![self isCancelled]) {
                _progress(_data.length, _expectedSize);
            }
            [_lock unlock];
        }
        
        /*--------------------------- progressive ----------------------------*/
        // 根据模式判断是否需要返回进度,以及是否需要渐进显示
        BOOL progressive = (_options & YYWebImageOptionProgressive) > 0;
        BOOL progressiveBlur = (_options & YYWebImageOptionProgressiveBlur) > 0;
        if (!_completion || !(progressive || progressiveBlur)) return;
        
        if (data.length <= 16) return;  // 如果data长度小于一个字,直接返回
        if (_expectedSize > 0 && data.length >= _expectedSize * 0.99) return;   // 超过总共大小
        if (_progressiveIgnored) return;    // 如果设置了忽略渐进式加载,直接返回
        
        NSTimeInterval min = progressiveBlur ? MIN_PROGRESSIVE_BLUR_TIME_INTERVAL : MIN_PROGRESSIVE_TIME_INTERVAL;
        NSTimeInterval now = CACurrentMediaTime();
        if (now - _lastProgressiveDecodeTimestamp < min) return;
        
        // 没有解码,初始化一个解码器
        if (!_progressiveDecoder) {
            _progressiveDecoder = [[YYImageDecoder alloc] initWithScale:[UIScreen mainScreen].scale];
        }
        
        // 解码器更新数据
        [_progressiveDecoder updateData:_data final:NO];
        if ([self isCancelled]) return;     // 如果调用取消方法,直接返回
        
        // 不需要渐进式加载
        if (_progressiveDecoder.type == YYImageTypeUnknown ||
            _progressiveDecoder.type == YYImageTypeWebP ||
            _progressiveDecoder.type == YYImageTypeOther) {
            _progressiveDecoder = nil;
            _progressiveIgnored = YES;
            return;
        }
        
        // 只支持渐进式的JPEG图像和interlanced类型的PNG图像
        if (progressiveBlur) { // only support progressive JPEG and interlaced PNG
            if (_progressiveDecoder.type != YYImageTypeJPEG &&
                _progressiveDecoder.type != YYImageTypePNG) {
                _progressiveDecoder = nil;
                _progressiveIgnored = YES;
                return;
            }
        }
        if (_progressiveDecoder.frameCount == 0) return;    // 解码器中图片帧数为0，直接返回
        
        // 不需要`模糊的` 渐渐式显示
        if (!progressiveBlur) {
            
            // 从解码中获取图片帧
            YYImageFrame *frame = [_progressiveDecoder frameAtIndex:0 decodeForDisplay:YES];
            if (frame.image) {
                [_lock lock];
                if (![self isCancelled]) {
                    
                    // 没有取消,把数据传递给完成block,
                    _completion(frame.image, _request.URL, YYWebImageFromRemote, YYWebImageStageProgress, nil);
                    _lastProgressiveDecodeTimestamp = now;  // 记录上次  渐渐式显示解码时间戳
                }
                [_lock unlock];
            }
            return;
        } else {    // 需要模糊处理的
            if (_progressiveDecoder.type == YYImageTypeJPEG) {  // jpeg
                
                // 如果表明了不是渐进式加载
                if (!_progressiveDetected) {
                    
                    // 从解码中取image帧属性
                    NSDictionary *dic = [_progressiveDecoder framePropertiesAtIndex:0];
                    NSDictionary *jpeg = dic[(id)kCGImagePropertyJFIFDictionary];
                    NSNumber *isProg = jpeg[(id)kCGImagePropertyJFIFIsProgressive];
                    if (!isProg.boolValue) {
                        _progressiveIgnored = YES;
                        _progressiveDecoder = nil;
                        return;
                    }
                    _progressiveDetected = YES;
                }
                
                
                // 这是什么，看不懂
                // 扫描长度为 接收到数据length - _progressiveScanedLength - 4
                NSInteger scanLength = (NSInteger)_data.length - (NSInteger)_progressiveScanedLength - 4;
                if (scanLength <= 2) return;
                NSRange scanRange = NSMakeRange(_progressiveScanedLength, scanLength);
                NSRange markerRange = [_data rangeOfData:JPEGSOSMarker() options:kNilOptions range:scanRange];
                _progressiveScanedLength = _data.length;
                if (markerRange.location == NSNotFound) return;
                if ([self isCancelled]) return;
                
            } else if (_progressiveDecoder.type == YYImageTypePNG) {
                if (!_progressiveDetected) {
                    NSDictionary *dic = [_progressiveDecoder framePropertiesAtIndex:0];
                    NSDictionary *png = dic[(id)kCGImagePropertyPNGDictionary];
                    NSNumber *isProg = png[(id)kCGImagePropertyPNGInterlaceType];
                    if (!isProg.boolValue) {
                        _progressiveIgnored = YES;
                        _progressiveDecoder = nil;
                        return;
                    }
                    _progressiveDetected = YES;
                }
            }
            
            YYImageFrame *frame = [_progressiveDecoder frameAtIndex:0 decodeForDisplay:YES];
            UIImage *image = frame.image;
            if (!image) return;
            if ([self isCancelled]) return;     // 再次检查是否取消了
            
             // 最后一个像素没有填充完毕,以为没有下载成功,返回
            if (!YYCGImageLastPixelFilled(image.CGImage)) return;
            _progressiveDisplayCount++;      // 进度++
            
            // 数据全部下载完成，进行模糊处理
            CGFloat radius = 32;
            if (_expectedSize > 0) {
                radius *= 1.0 / (3 * _data.length / (CGFloat)_expectedSize + 0.6) - 0.25;
            } else {
                radius /= (_progressiveDisplayCount);
            }
            
            // 模糊处理
            image = [image yy_imageByBlurRadius:radius tintColor:nil tintMode:0 saturation:1 maskImage:nil];
            
            if (image) {
                [_lock lock];
                if (![self isCancelled]) {
                    
                    // 图片存在,给完成block赋值
                    _completion(image, _request.URL, YYWebImageFromRemote, YYWebImageStageProgress, nil);
                    _lastProgressiveDecodeTimestamp = now;
                }
                [_lock unlock];
            }
        }
    }
}

// 连接已经结束加载
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    @autoreleasepool {
        [_lock lock];
        _connection = nil;
        if (![self isCancelled]) {
            __weak typeof(self) _self = self;
            
            
            // 开启一个异步线程
            dispatch_async([self.class _imageQueue], ^{
                __strong typeof(_self) self = _self;
                if (!self) return;
                
                // 通过是否是YYWebImageOptionIgnoreImageDecoding模式判断是否需要解码
                BOOL shouldDecode = (self.options & YYWebImageOptionIgnoreImageDecoding) == 0;
                BOOL allowAnimation = (self.options & YYWebImageOptionIgnoreAnimatedImage) == 0;
                UIImage *image;
                BOOL hasAnimation = NO;
                
                if (allowAnimation) {    // 如果允许动画,通过YYImage这个类加载图片
                    image = [[YYImage alloc] initWithData:self.data scale:[UIScreen mainScreen].scale];
                    
                    // 如果需要解码,就解码
                    if (shouldDecode) image = [image yy_imageByDecoded];
                    if ([((YYImage *)image) animatedImageFrameCount] > 1) {
                        hasAnimation = YES;
                    }
                } else {    // 不允许动画
                    
                    // 解码
                    YYImageDecoder *decoder = [YYImageDecoder decoderWithData:self.data scale:[UIScreen mainScreen].scale];
                    
                    // 直接取图片
                    image = [decoder frameAtIndex:0 decodeForDisplay:shouldDecode].image;
                }
                
                
                // 如果是动图,保存原始图片数据到磁盘缓存,
                // 如果图片不是PNG或者JPEG格式,把图片转码成PNG或者JPEG格式,此举是为了得到更好的解码表现;
                /*
                 If the image has animation, save the original image data to disk cache.
                 If the image is not PNG or JPEG, re-encode the image to PNG or JPEG for
                 better decoding performance.
                 */
                YYImageType imageType = YYImageDetectType((__bridge CFDataRef)self.data);
                switch (imageType) {
                    case YYImageTypeJPEG:
                    case YYImageTypeGIF:
                    case YYImageTypePNG:
                    case YYImageTypeWebP: { // save to disk cache
                        if (!hasAnimation) {
                            if (imageType == YYImageTypeGIF ||
                                imageType == YYImageTypeWebP) {
                                self.data = nil; // clear the data, re-encode for disk cache
                            }
                        }
                    } break;
                    default: {
                        self.data = nil; // clear the data, re-encode for disk cache
                    } break;
                }
                if ([self isCancelled]) return; // 还要判断,自定义NSOperation真的好麻烦
                
                if (self.transform && image) {
                    
                    // 图片transform回调，
                    UIImage *newImage = self.transform(image, self.request.URL);
                    if (newImage != image) {    // 图片错了,清空
                        self.data = nil;
                    }
                    image = newImage;
                    if ([self isCancelled]) return;
                }
                
                // 调用_didReceiveImageFromWeb方法表明 正确从网络上下载到图片
                [self performSelector:@selector(_didReceiveImageFromWeb:) onThread:[self.class _networkThread] withObject:image waitUntilDone:NO];
            });
            if (![self.request.URL isFileURL] && (self.options & YYWebImageOptionShowNetworkActivity)) {
                [YYWebImageManager decrementNetworkActivityCount];  // 网络请求数量-1
            }
        }
        [_lock unlock];
    }
}

// 连接失败
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @autoreleasepool {
        [_lock lock];
        if (![self isCancelled]) {
            if (_completion) {   // 把失败信息也传递给完成block
                _completion(nil, _request.URL, YYWebImageFromNone, YYWebImageStageFinished, error);
            }
            _connection = nil;
            _data = nil;
            if (![_request.URL isFileURL] && (_options & YYWebImageOptionShowNetworkActivity)) {
                [YYWebImageManager decrementNetworkActivityCount];  // 网络请求数量-1
            }
            [self _finish]; // 手动调一下结束方法
            
            // 如果模式是忽略错误URL:YYWebImageOptionIgnoreFailedURL
            if (_options & YYWebImageOptionIgnoreFailedURL) {
                if (error.code != NSURLErrorNotConnectedToInternet &&
                    error.code != NSURLErrorCancelled &&
                    error.code != NSURLErrorTimedOut &&
                    error.code != NSURLErrorUserCancelledAuthentication) {
                    URLInBlackListAdd(_request.URL);        // 加入黑名单
                }
            }
        }
        [_lock unlock];
    }
}

#pragma mark - Override NSOperation

// 重写的NSOperation的状态值方法, 主要看start跟cancel

/**
 *  开始这个NSOperation
 */
- (void)start {
    @autoreleasepool {
        [_lock lock];
        self.started = YES;     // 标记开始位为YES
        
        if ([self isCancelled]) {   // 如果这时候被取消了,调用取消方法
            [self performSelector:@selector(_cancelOperation) onThread:[[self class] _networkThread] withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
            self.finished = YES;    // 标记结束位YES
        } else if ([self isReady] && ![self isFinished] && ![self isExecuting]) {    // 或者如果在准备开始,并且没有结束,并且没有运行中,执行以下操作
            
            if (!_request) {    // 请求不存在
                self.finished = YES;
                if (_completion) {
                    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{NSLocalizedDescriptionKey:@"request in nil"}];
                    _completion(nil, _request.URL, YYWebImageFromNone, YYWebImageStageFinished, error);
                }
            } else {
                self.executing = YES;   // 正在执行为YES
                
                // 调用开始方法
                [self performSelector:@selector(_startOperation) onThread:[[self class] _networkThread] withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
                
                 // 如果模式为YYWebImageOptionAllowBackgroundTask并且在后台, 后台下载
                if ((_options & YYWebImageOptionAllowBackgroundTask) && _YYSharedApplication()) {
                    __weak __typeof__ (self) _self = self;
                    if (_taskID == UIBackgroundTaskInvalid) {
                        _taskID = [_YYSharedApplication() beginBackgroundTaskWithExpirationHandler:^{
                            __strong __typeof (_self) self = _self;
                            if (self) {
                                [self cancel];
                                self.finished = YES;
                            }
                        }];
                    }
                }
            }
        }
        [_lock unlock];
    }
}

/**
 *  取消operaion方法
 */
- (void)cancel {
    [_lock lock];
    
    // 先检查是不是取消了,没有取消调用父类取消,设置自己取消状态为YES
    if (![self isCancelled]) {
        [super cancel];
        self.cancelled = YES;
        
        // 如果正在执行中,设置执行状态为NO,调用取消操作
        if ([self isExecuting]) {
            self.executing = NO;
            [self performSelector:@selector(_cancelOperation) onThread:[[self class] _networkThread] withObject:nil waitUntilDone:NO modes:@[NSDefaultRunLoopMode]];
        }
        
        // 如果已经开始,直接标记结束,不做其他处理
        if (self.started) {
            self.finished = YES;
        }
    }
    [_lock unlock];
}

- (void)setExecuting:(BOOL)executing {
    [_lock lock];
    if (_executing != executing) {
        [self willChangeValueForKey:@"isExecuting"];        // KVO
        _executing = executing;
        [self didChangeValueForKey:@"isExecuting"];
    }
    [_lock unlock];
}

- (BOOL)isExecuting {
    [_lock lock];
    BOOL executing = _executing;
    [_lock unlock];
    return executing;
}

- (void)setFinished:(BOOL)finished {
    [_lock lock];
    if (_finished != finished) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
    [_lock unlock];
}

- (BOOL)isFinished {
    [_lock lock];
    BOOL finished = _finished;
    [_lock unlock];
    return finished;
}

- (void)setCancelled:(BOOL)cancelled {
    [_lock lock];
    if (_cancelled != cancelled) {
        [self willChangeValueForKey:@"isCancelled"];
        _cancelled = cancelled;
        [self didChangeValueForKey:@"isCancelled"];
    }
    [_lock unlock];
}

- (BOOL)isCancelled {
    [_lock lock];
    BOOL cancelled = _cancelled;
    [_lock unlock];
    return cancelled;
}

- (BOOL)isConcurrent {  // 是并发
    return YES;
}

- (BOOL)isAsynchronous { // 是异步
    return YES;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"isExecuting"] ||
        [key isEqualToString:@"isFinished"] ||
        [key isEqualToString:@"isCancelled"]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (NSString *)description {
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@: %p ",self.class, self];
    [string appendFormat:@" executing:%@", [self isExecuting] ? @"YES" : @"NO"];
    [string appendFormat:@" finished:%@", [self isFinished] ? @"YES" : @"NO"];
    [string appendFormat:@" cancelled:%@", [self isCancelled] ? @"YES" : @"NO"];
    [string appendString:@">"];
    return string;
}

@end
