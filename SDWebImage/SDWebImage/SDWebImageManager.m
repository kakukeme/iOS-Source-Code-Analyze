/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageManager.h"
#import <objc/message.h>
#import "NSImage+WebCache.h"


/**
 通过这个对象关联一个`SDWebImageDownloaderOperation`对象
 */
// 遵循SDWebImageOperation
@interface SDWebImageCombinedOperation : NSObject <SDWebImageOperation>

/**
 用于判断Operation是否已经取消
 */
@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;

/**
 取消回调
 */
// 注意SDWebImageCombinedOperation遵循SDWebImageOperation，所以实现了cancel方法
// 在cancel方法中，主要是调用了cancelBlock，这个设计很值得琢磨
@property (copy, nonatomic, nullable) SDWebImageNoParamsBlock cancelBlock;

/*
 *如果图片是从内存加载，则返回的cacheOperation是nil，
 *如果是从磁盘加载，则返回的cacheOperation是`NSOperation`对象。
 *如果是从网络加载，则返回的cacheOperation对象是`SDWebImageDownloaderOperation`对象。
 */

/**
 SDWebImageDownloaderOperation对象。可以通过这个属性取消一个NSOperation
 */

// 根据cacheType获取到image，这里虽然名字用的是cache，但是如果cache没有获取到图片
// 还是要把image下载下来的。此处只是把通过cache获取image和通过download获取image封装起来
@property (strong, nonatomic, nullable) NSOperation *cacheOperation;

@end

@interface SDWebImageManager ()

@property (strong, nonatomic, readwrite, nonnull) SDImageCache *imageCache;
@property (strong, nonatomic, readwrite, nonnull) SDWebImageDownloader *imageDownloader;
@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;
@property (strong, nonatomic, nonnull) NSMutableArray<SDWebImageCombinedOperation *> *runningOperations;

@end

@implementation SDWebImageManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

// 初始化过程
- (nonnull instancetype)init {
    SDImageCache *cache = [SDImageCache sharedImageCache];
    SDWebImageDownloader *downloader = [SDWebImageDownloader sharedDownloader];
    return [self initWithCache:cache downloader:downloader];
}

/**
 初始化SDImageCache和SDWebImageDownloader对象
 
 @param cache SDImageCache对象
 @param downloader SDWebImageDownloader对象
 @return 返回初始化结果
 */
- (nonnull instancetype)initWithCache:(nonnull SDImageCache *)cache downloader:(nonnull SDWebImageDownloader *)downloader {
    if ((self = [super init])) {
        _imageCache = cache;
        _imageDownloader = downloader;
        _failedURLs = [NSMutableSet new];           // 用于保存加载失败的url集合
        _runningOperations = [NSMutableArray new];  // 用于保存当前正在加载的Operation
    }
    return self;
}

/**
 根据url获取url对应的缓存key。
 如果有实现指定的url转换key的Block，则用这个方式转换为key。
 否则直接用url的绝对值多为key
 
 @param url url
 @return 缓存的key
 */
- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }

    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    } else {
        return url.absoluteString;
    }
}

/**
 一个url的缓存是否存在
 
 @param url 缓存数据对应的url
 @param completionBlock 缓存结果回调
 */
- (void)cachedImageExistsForURL:(nullable NSURL *)url
                     completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    // 内存里面是否有key的缓存
    BOOL isInMemoryCache = ([self.imageCache imageFromMemoryCacheForKey:key] != nil);
    
    // 内存缓存
    if (isInMemoryCache) {
        // making sure we call the completion block on the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(YES);
            }
        });
        return;
    }
    
    // 磁盘缓存
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

/**
url是否有磁盘缓存数据

@param url url
@param completionBlock 回调
*/
- (void)diskImageExistsForURL:(nullable NSURL *)url
                   completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}


/**
这个方法是核心方法。UIImageView等各种分类都默认通过调用这个方法来获取数据。

@param url 图片的url地址
@param options 获取图片的属性
@param progressBlock 加载进度回调
@param completedBlock 加载完成回调
@return 返回一个加载的载体对象。以便提供给后面取消删除等。
*/
- (id <SDWebImageOperation>)loadImageWithURL:(nullable NSURL *)url
                                     options:(SDWebImageOptions)options
                                    progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                                   completed:(nullable SDInternalCompletionBlock)completedBlock {
    
    // 如果你是想使用downloadImageWithURL来预先获取image，那就应该使用[SDWebImagePrefetcher prefetchURLs]，
    // 而不是直接调用SDWebImageManager中的downloadImageWithURL函数。
    
    // 如果调用此方法，而没有传completedBlock，那将是无意义的
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");

    /*
     如果传入的url是NSString格式的。则转换为NSURL类型再处理
     */
    // 使用NSString对象而非NSURL作为url是常见的错误. 因为某些奇怪的原因，Xcode不会报任何类型不匹配的警告，这里允许传NSString对象给URL。
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // 如果url不会NSURL类型的对象。则置为nil
    // 防止传了一个NSNull值给NSURL
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    /*
     图片加载获取获取过程中绑定一个`SDWebImageCombinedOperation`对象。以方便后续再通过这个对象对url的加载控制。
     */

    // 避免循环引用，使用了weak。
    __block SDWebImageCombinedOperation *operation = [SDWebImageCombinedOperation new];
    __weak SDWebImageCombinedOperation *weakOperation = operation;

    /**
     就是如果这个图片url无法下载，那就使用completedBlock进行错误处理。那什么情况下算这个图片url无法下载呢？第一种情况是该url为空，另一种情况就是如果是failedUrl也无法下载，但是要避免无法下载就放入failedUrl的情况，就要设置options为SDWebImageRetryFailed。一般默认image无法下载，这个url就会加入黑名单，但是设置了SDWebImageRetryFailed会禁止添加到黑名单，不停重新下载。
     */
    BOOL isFailedUrl = NO;
    
    // 当前url是否在失败url的集合里面
    if (url) {
        @synchronized (self.failedURLs) {
            // failedURLs从字面上理解就是一组下载失败的图片URL。
            isFailedUrl = [self.failedURLs containsObject:url];
        }
    }

    /*
     如果url是失败的url或者url有问题等各种问题。则直接根据opeation来做异常情况的处理
     */
    if (url.absoluteString.length == 0 || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        
        // 构建回调Block
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] url:url];
        return operation;
    }

    // 把加载图片的一个载体operation存入runningOperations。里面是所有正在做图片加载过程的operation的集合。
    // 如果该url可以下载，那么就添加一个新的operation到runningOperations中。
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    
    
    // 根据url获取url对应的key
    // 用图片的url来获取cache对应的key, 获取到key后，你就可以使用queryDiskCacheForKey函数去查找
    NSString *key = [self cacheKeyForURL:url];

    /*
     *如果图片是从内存加载，则返回的cacheOperation是nil，
     *如果是从磁盘加载，则返回的cacheOperation是`NSOperation`对象。
     *如果是从网络加载，则返回的cacheOperation对象是`SDWebImageDownloaderOperation`对象。
     */
    
    // 生成一个cacheOperation, 是一个NSOperation，所以加入NSOperationQueue会自动执行
    // 根据key去查找缓存
    operation.cacheOperation = [self.imageCache queryCacheOperationForKey:key done:^(UIImage *cachedImage, NSData *cachedData, SDImageCacheType cacheType) {
        
        //从缓存中获取图片数据返回
        //如果已经取消了操作。则直接返回并且移除对应的opetation对象
        
        // 判断该operation是否已经cancel了
        if (operation.isCancelled) {
            [self safelyRemoveOperationFromRunning:operation];
            return;
        }

       
        if ((!cachedImage || options & SDWebImageRefreshCached) && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url])) {
            
            
            /**
             如果从缓存获取图片失败。或者设置了SDWebImageRefreshCached来忽略缓存。则先把缓存的图片返回。
             
             */
            if (cachedImage && options & SDWebImageRefreshCached) {
                
                // 构建回调Block
                // If image was found in the cache but SDWebImageRefreshCached is provided, notify about the cached image
                // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                [self callCompletionBlockForOperation:weakOperation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            }

            
            /*
             把图片加载的`SDWebImageOptions`类型枚举转换为图片下载的`SDWebImageDownloaderOptions`类型的枚举
             */
            
            // download if no image or requested to refresh anyway, and download allowed by delegate
            SDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & SDWebImageLowPriority) downloaderOptions |= SDWebImageDownloaderLowPriority;
            if (options & SDWebImageProgressiveDownload) downloaderOptions |= SDWebImageDownloaderProgressiveDownload;
            if (options & SDWebImageRefreshCached) downloaderOptions |= SDWebImageDownloaderUseNSURLCache;
            if (options & SDWebImageContinueInBackground) downloaderOptions |= SDWebImageDownloaderContinueInBackground;
            if (options & SDWebImageHandleCookies) downloaderOptions |= SDWebImageDownloaderHandleCookies;
            if (options & SDWebImageAllowInvalidSSLCertificates) downloaderOptions |= SDWebImageDownloaderAllowInvalidSSLCertificates;
            if (options & SDWebImageHighPriority) downloaderOptions |= SDWebImageDownloaderHighPriority;
            if (options & SDWebImageScaleDownLargeImages) downloaderOptions |= SDWebImageDownloaderScaleDownLargeImages;
            
            /*
             如果设置了强制刷新缓存的选项。则`SDWebImageDownloaderProgressiveDownload`选项失效并且添加`SDWebImageDownloaderIgnoreCachedResponse`选项。
             */
            if (cachedImage && options & SDWebImageRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
            
            
            /*
             新建一个网络下载的操作。
             */
            SDWebImageDownloadToken *subOperationToken = [self.imageDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
                
                
                // 如果图片下载结束以后，对应的图片加载操作已经取消。则什么处理都不做
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                if (!strongOperation || strongOperation.isCancelled) {      // 被取消了
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                    
                    // 如果operation已经被取消了，则什么也不做
                } else if (error) { // 下载出错
                    
                    // 如果加载出错。则直接返回回调。并且添加到failedURLs中
                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock error:error url:url];

                    if (   error.code != NSURLErrorNotConnectedToInternet
                        && error.code != NSURLErrorCancelled
                        && error.code != NSURLErrorTimedOut
                        && error.code != NSURLErrorInternationalRoamingOff
                        && error.code != NSURLErrorDataNotAllowed
                        && error.code != NSURLErrorCannotFindHost
                        && error.code != NSURLErrorCannotConnectToHost
                        && error.code != NSURLErrorNetworkConnectionLost) {
                        @synchronized (self.failedURLs) {
                            [self.failedURLs addObject:url];
                        }
                    }
                }
                else {  // 网络图片加载成功
                    
                    // 如果有重试失败下载的选项。则把url从failedURLS中移除
                    if ((options & SDWebImageRetryFailed)) {
                        
                        @synchronized (self.failedURLs) {
                            [self.failedURLs removeObject:url];
                        }
                    }
                    
                    BOOL cacheOnDisk = !(options & SDWebImageCacheMemoryOnly);

                    // NSURLCache
                    if (options & SDWebImageRefreshCached && cachedImage && !downloadedImage) {
                        // Image refresh hit the NSURLCache cache, do not call the completion block
                        
                    
                        
                    // 如果成功下载图片。并且图片是动态图片。并且设置了SDWebImageTransformAnimatedImage属性。则处理图片
                    } else if (downloadedImage && (!downloadedImage.images || (options & SDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)]) {
                        
                        // 对图片进行变换，吸收YYWebImage思想
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                           
                            
                            // 获取transform以后的图片
                            UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];

                            // 存储transform以后的的图片
                            if (transformedImage && finished) {
                                BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                
                                // 如果image被transform变换了，存nil；以至于我们可以重新计算数据
                                // pass nil if the image was transformed, so we can recalculate the data from the image
                                [self.imageCache storeImage:transformedImage imageData:(imageWasTransformed ? nil : downloadedData) forKey:key toDisk:cacheOnDisk completion:nil];
                            }
                            
                            // 回调拼接
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:transformedImage data:downloadedData error:nil cacheType:SDImageCacheTypeNone finished:finished url:url];
                        });
                    } else {
                        
                        // 如果成功下载图片。并且图片不是动图()。则直接缓存和回调
                        if (downloadedImage && finished) {
                            
                            // 直接缓存
                            [self.imageCache storeImage:downloadedImage imageData:downloadedData forKey:key toDisk:cacheOnDisk completion:nil];
                        }
                        
                        // 回调拼接
                        [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:downloadedImage data:downloadedData error:nil cacheType:SDImageCacheTypeNone finished:finished url:url];
                    }
                }

                // 从正在加载的图片操作集合中(runningOperations)移除当前操作
                if (finished) {
                    [self safelyRemoveOperationFromRunning:strongOperation];
                }
            }];
            
            // 重置cancelBlock，取消下载operation
            operation.cancelBlock = ^{
                [self.imageDownloader cancel:subOperationToken];    // 先取消子operation(网络下载的操作。)
                
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                [self safelyRemoveOperationFromRunning:strongOperation];
            };
        } else if (cachedImage) {
            
            // 如果获取到了缓存图片。在直接通过缓存图片处理
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            
            [self safelyRemoveOperationFromRunning:operation];
        } else {
            
            // 图片没有缓存、并且图片也没有下载
            
            // Image not in cache and download disallowed by delegate
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:nil data:nil error:nil cacheType:SDImageCacheTypeNone finished:YES url:url];
            
            [self safelyRemoveOperationFromRunning:operation];
        }
    }];

    return operation;
}

- (void)saveImageToCache:(nullable UIImage *)image forURL:(nullable NSURL *)url {
    if (image && url) {
        NSString *key = [self cacheKeyForURL:url];
        [self.imageCache storeImage:image forKey:key toDisk:YES completion:nil];
    }
}

- (void)cancelAll {
    @synchronized (self.runningOperations) {
        NSArray<SDWebImageCombinedOperation *> *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning {
    BOOL isRunning = NO;
    @synchronized (self.runningOperations) {
        isRunning = (self.runningOperations.count > 0);
    }
    return isRunning;
}

// 安全移除运行的operation
- (void)safelyRemoveOperationFromRunning:(nullable SDWebImageCombinedOperation*)operation {
    
    /**
     @synchronized
     
     避免多个线程执行同一段代码，主要防止当前operation会被多次remove，从而造成crash。这里括号内的self.runningOperations是用作互斥信号量。 即此时其他线程不能修改self.runningOperations中的属性
     */
    @synchronized (self.runningOperations) {
        if (operation) {
            
            // runningOperations 用来存储正在运行的operation
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable SDWebImageCombinedOperation*)operation
                             completion:(nullable SDInternalCompletionBlock)completionBlock
                                  error:(nullable NSError *)error
                                    url:(nullable NSURL *)url {
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:SDImageCacheTypeNone finished:YES url:url];
}

- (void)callCompletionBlockForOperation:(nullable SDWebImageCombinedOperation*)operation
                             completion:(nullable SDInternalCompletionBlock)completionBlock
                                  image:(nullable UIImage *)image
                                   data:(nullable NSData *)data
                                  error:(nullable NSError *)error
                              cacheType:(SDImageCacheType)cacheType
                               finished:(BOOL)finished
                                    url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(image, data, error, cacheType, finished, url);
        }
    });
}

@end


@implementation SDWebImageCombinedOperation


/**
 取消Operation的回调Block
 
 @param cancelBlock 回调Block
 */
- (void)setCancelBlock:(nullable SDWebImageNoParamsBlock)cancelBlock {
    
    // 检测self（是一个SDWebImageCombinedOperation类型的operation）是否取消了，如果取消了，就执行对应的cancelBlock函数。
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        
        // 不要忘了置cancelBlock为nil，否则会crash
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

/**
 调用cancel方法。这个方法继承自`SDWebImageOperation`协议。方法里面会调用`SDWebImageDownlaoderOperation`或者`NSOperation`的cancel方法
 */
- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        
        // 调用`SDWebImageDownlaoderOperation`或者`NSOperation`的cancel方法
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        
        // TODO: this is a temporary fix to #809.
        // Until we can figure the exact cause of the crash, going with the ivar instead of the setter
//        self.cancelBlock = nil;
        _cancelBlock = nil;
    }
}

@end
