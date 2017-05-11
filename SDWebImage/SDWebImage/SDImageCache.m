/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <CommonCrypto/CommonDigest.h>
#import "UIImage+GIF.h"
#import "NSData+ImageContentType.h"
#import "NSImage+WebCache.h"

// See https://github.com/rs/SDWebImage/pull/1141 for discussion
@interface AutoPurgeCache : NSCache
@end

/**
 通过AutoPurgeCache这个NSCache子类来管理内存缓存。当接收到内存警告的时候，移除内存缓存的所有对象。
 */
/**
 *  AutoPurgeCache收到一个内存警告，就会自动释放内存，调用NSCache的removeAllObjects
 *
 */
@implementation AutoPurgeCache

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
#if SD_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
#if SD_UIKIT
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

@end


/**
 计算一张图片占用内存的大小
 
 @param image 图片
 @return 占用内存大小
 */
// C语言函数, 返回图片大小
// FOUNDATION_STATIC_INLINE 表示 static __inline__，属于runtime范畴
FOUNDATION_STATIC_INLINE NSUInteger SDCacheCostForImage(UIImage *image) {
#if SD_MAC
    return image.size.height * image.size.width;
#elif SD_UIKIT || SD_WATCH
    
    // 这里我觉得这样写不是很好，如果这样写就更直观了
    // return (height * scale) * (width * scale)
    return image.size.height * image.size.width * image.scale * image.scale;
#endif
}


/**
单列对象、用处管理图片的缓存以及缓存图片的处理
*/
@interface SDImageCache ()

#pragma mark - Properties
@property (strong, nonatomic, nonnull) NSCache *memCache;
@property (strong, nonatomic, nonnull) NSString *diskCachePath;
@property (strong, nonatomic, nullable) NSMutableArray<NSString *> *customPaths;
@property (SDDispatchQueueSetterSementics, nonatomic, nullable) dispatch_queue_t ioQueue;

@end


@implementation SDImageCache {
    NSFileManager *_fileManager;
}

#pragma mark - Singleton, init, dealloc

+ (nonnull instancetype)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    return [self initWithNamespace:@"default"];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    NSString *path = [self makeDiskCachePath:ns];
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nonnull NSString *)directory {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        
        // 初始化一个串行的dispatch_queue_t
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        // 初始化缓存策略配置对象
        _config = [[SDImageCacheConfig alloc] init];
        
        // 初始化内存缓存对象
        // Init the memory cache
        _memCache = [[AutoPurgeCache alloc] init];
        _memCache.name = fullNamespace;

        // 初始化磁盘缓存路径
        // Init the disk cache
        if (directory != nil) {
            _diskCachePath = [directory stringByAppendingPathComponent:fullNamespace];
        } else {
            NSString *path = [self makeDiskCachePath:ns];
            _diskCachePath = path;
        }

        dispatch_sync(_ioQueue, ^{
            _fileManager = [NSFileManager new];
        });

#if SD_UIKIT
        
        /*
         当应用收到内存警告的时候，清除内存缓存。
         */
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];

        /*
         当应用终止的时候，清除老数据
         */
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteOldFiles)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        /*
         当应用进入后台的时候，在后台删除老数据
         */
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

/**
 当前queue是否在ioQueue
 */
- (void)checkIfQueueIsIOQueue {
    const char *currentQueueLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char *ioQueueLabel = dispatch_queue_get_label(self.ioQueue);
    if (strcmp(currentQueueLabel, ioQueueLabel) != 0) {
        NSLog(@"This method should be called from the ioQueue");
    }
}

#pragma mark - Cache paths

/*
 添加到只读的缓存目录
 */
- (void)addReadOnlyCachePath:(nonnull NSString *)path {
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray new];
    }

    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}

/**
 获取指定key对应的完整缓存路径
 
 @param key key，对应一张图片。比如图片的名字
 @param path 指定根目录
 @return 完整目录
 */
- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path {
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}


/**
 获取一张图片对应的MD5加密的缓存名字。
 
 MD5加密
 X 表示以十六进制形式输出
 02 表示不足两位，前面补0输出；出过两位，不影响
 
 @param key key
 @return 加密后的数据
 */
- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [key.pathExtension isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", key.pathExtension]];

    return filename;
}

/**
 图片缓存目录
 
 @param fullNamespace 自定义目录
 @return 完整目录
 */
- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

#pragma mark - 图片缓存具体实现的一些列方法
#pragma mark - Store Ops

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:YES completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:toDisk completion:completionBlock];
}

/**
 把一张图片存入缓存的具体实现
 
 @param image 缓存的图片对象
 @param imageData 缓存的图片数据
 @param key 缓存对应的key
 @param toDisk 是否缓存到disk磁盘
 @param completionBlock 缓存完成回调
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    if (!image || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    
    // 缓存到内存
    // if memory cache is enabled
    if (self.config.shouldCacheImagesInMemory) {
        
        // 计算缓存数据的大小
        NSUInteger cost = SDCacheCostForImage(image);
        
        // 加入到内存缓存
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk) {
        
        /*
         在一个线性队列中做磁盘缓存操作。
         */
        dispatch_async(self.ioQueue, ^{
            NSData *data = imageData;
            
            if (!data && image) {
                
                // 获取图片的类型GIF/PNG等
                SDImageFormat imageFormatFromData = [NSData sd_imageFormatForImageData:data];
                
                // 根据指定的SDImageFormat。把图片转换为对应的data数据
                data = [image sd_imageDataAsFormat:imageFormatFromData];
            }
            
            // 把处理好了的数据存入磁盘
            [self storeImageDataToDisk:data forKey:key];
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        });
    } else {
        if (completionBlock) {
            completionBlock();
        }
    }
}

/**
 把图片资源存入磁盘
 
 @param imageData 图片数据
 @param key key
 */
- (void)storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    // 当前queue是否在ioQueue
    [self checkIfQueueIsIOQueue];
    
    // 缓存目录是否已经初始化
    if (![_fileManager fileExistsAtPath:_diskCachePath]) {
        [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // 获取key对应的完整缓存路径
    // get cache Path for image key
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    // transform to NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    
    // 把数据存入路径
    [_fileManager createFileAtPath:cachePathForKey contents:imageData attributes:nil];
    
    // 关闭iCloud 备份属性
    // disable iCloud backup
    if (self.config.shouldDisableiCloud) {
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

#pragma mark - Query and Retrieve Ops


/**
url(key) 是否有磁盘缓存数据

@param url url
@param completionBlock 回调
*/
- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock {
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];

        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        if (!exists) {
            exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

/**
根据key获取缓存在内存中的图片

@param key key
@return 缓存的图片
*/
- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key {
    return [self.memCache objectForKey:key];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key {
    UIImage *diskImage = [self diskImageForKey:key];
    if (diskImage && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = SDCacheCostForImage(diskImage);
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key {
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    image = [self imageFromDiskCacheForKey:key];
    return image;
}


/**
 根据指定的key，获取存储在磁盘上的数据
 
 @param key 图片对应的key
 @return 返回图片数据
 */
- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    
    // 获取key对应的path
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
        return data;
    }

    /*
     如果key么有后缀名，则会走到这里通过这里读取
     */
    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
    data = [NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension];
    if (data) {
        return data;
    }

    /*
     如果在默认路径没有找到图片，则在自定义路径迭代查找
     */
    NSArray<NSString *> *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }

        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        imageData = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension];
        if (imageData) {
            return imageData;
        }
    }

    return nil;
}


/**
 根据指定的key获取image对象
 
 @param key key
 @return image对象
 */
- (nullable UIImage *)diskImageForKey:(nullable NSString *)key {
    
    // 获取磁盘数据
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    if (data) {
        UIImage *image = [UIImage sd_imageWithData:data];
        image = [self scaledImageForKey:key image:image];
        if (self.config.shouldDecompressImages) {
            image = [UIImage decodedImageWithImage:image];
        }
        return image;
    }
    else {
        return nil;
    }
}

- (nullable UIImage *)scaledImageForKey:(nullable NSString *)key image:(nullable UIImage *)image {
    return SDScaledImageForKey(key, image);
}


/**
 在缓存中查询对应key的数据。通过一个NSOperation来完成
 
 @param key 要查询的key
 @param doneBlock 查询结束以后的Block
 @return 返回做查询操作的Block
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable SDCacheQueryCompletedBlock)doneBlock {
    
    // 如果key为nil，说明cache中没有该image。所以doneBlock中传入SDImageCacheTypeNone，
    // 表示cache中没有图片，要从网络重新获取。
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }

    // 如果key不为nil, 首先在内存cache中查找
    
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        NSData *diskData = nil;
        
        // 是否是gif图片
        if ([image isGIF]) {
            diskData = [self diskImageDataBySearchingAllPathsForKey:key];
        }
        if (doneBlock) {
            doneBlock(image, diskData, SDImageCacheTypeMemory);
        }
        return nil;
    }

    // 新建一个NSOperation来获取磁盘图片
    // 否则，说明图片就在磁盘cache中。
    // 使用异步队列，获取磁盘缓存；
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }

        
        // 在一个自动释放池中处理图片从磁盘加载
        @autoreleasepool {
            NSData *diskData = [self diskImageDataBySearchingAllPathsForKey:key];
            UIImage *diskImage = [self diskImageForKey:key];
            
            
            
            // 如果磁盘中得到了该image，并且还需要缓存到内存中，为了同步最新数据
            if (diskImage && self.config.shouldCacheImagesInMemory) {
                NSUInteger cost = SDCacheCostForImage(diskImage);
                
                // 把从磁盘取出的缓存图片加入内存缓存中
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }

            // 传入SDImageCacheTypeDisk，说明是从磁盘中获取的
            if (doneBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // 图片处理完成以后回调Block
                    doneBlock(diskImage, diskData, SDImageCacheTypeDisk);
                });
            }
        }
    });

    return operation;
}

#pragma mark - Remove Ops

- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

/**
 移除指定key对应的缓存数据
 
 @param key key
 @param fromDisk 是否也清除磁盘缓存
 @param completion 回调
 */
- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    if (key == nil) {
        return;
    }

    if (self.config.shouldCacheImagesInMemory) {
        [self.memCache removeObjectForKey:key];
    }

    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion){
        completion();
    }
    
}

# pragma mark - Mem Cache settings

- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost {
    return self.memCache.totalCostLimit;
}

- (NSUInteger)maxMemoryCountLimit {
    return self.memCache.countLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxCountLimit {
    self.memCache.countLimit = maxCountLimit;
}

#pragma mark - Cache clean Ops

- (void)clearMemory {
    [self.memCache removeAllObjects];
}

- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        [_fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

/**
 删除老的图片。具体删除规则如下：
 
 缓存大小、过期日期、是否解压缩缓存、是否允许内存缓存都是通过SDImageCacheConfig这个对象来配置的。
 首先会迭代缓存目录下的所有文件，对于大于一周的图片数据全部删除。
 
 然后会记录缓存目录的所有大小，如果当前缓存大于默认缓存，则按照创建日期开始删除图片缓存，直到缓存大小小于默认缓存大小。
 
 */
- (void)deleteOldFiles {
    [self deleteOldFilesWithCompletionBlock:nil];
}

- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];

        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;

        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];

            // Skip directories and errors.
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }

            // Remove files that are older than the expiration date;
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }

            // Store a reference to this file and account for its total size.
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }

        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;

            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];

            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;

                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

#if SD_UIKIT
- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}
#endif

#pragma mark - Cache Info

- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(nullable SDWebImageCalculateSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];

    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;

        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end

