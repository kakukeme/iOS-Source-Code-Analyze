/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDImageCacheConfig.h"

// 缓存类型
typedef NS_ENUM(NSInteger, SDImageCacheType) {
    /**
     * The image wasn't available the SDWebImage caches, but was downloaded from the web.
     * 该图片无法从SDWebImage的缓存中获取，必须从web端下载。
     */
    SDImageCacheTypeNone,       // 网络下载图片
    
    /**
     * The image was obtained from the disk cache.
     *  图片从硬盘缓存(disk cache)中获取
     */
    SDImageCacheTypeDisk,       // 磁盘缓存
    /**
     * The image was obtained from the memory cache.
     * 图像从内存缓存(memory cache)获得
     */
    SDImageCacheTypeMemory      // 内存缓存
};

// 查询图片缓存，完成block
typedef void(^SDCacheQueryCompletedBlock)(UIImage * _Nullable image, NSData * _Nullable data, SDImageCacheType cacheType);

// 检查image是否存在disk，完成block
typedef void(^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);

// image计算size，完成block
typedef void(^SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);


/**
 SDImageCache维护了一个内存缓存和一个可选的磁盘缓存；disk缓存写操作是异步的，不会增加UI延迟
 */
/**
 * SDImageCache maintains a memory cache and an optional disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 */
@interface SDImageCache : NSObject

#pragma mark - Properties

/**
 *  Cache Config object - storing all kind of settings
 */
@property (nonatomic, nonnull, readonly) SDImageCacheConfig *config;

/**
 * The maximum "total cost" of the in-memory image cache. The cost function is the number of pixels held in memory.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 * The maximum number of objects the cache should hold.
 */
@property (assign, nonatomic) NSUInteger maxMemoryCountLimit;

#pragma mark - Singleton and initialization

/**
 * Returns global shared cache instance
 *
 * @return SDImageCache global instance
 */
+ (nonnull instancetype)sharedImageCache;

/**
 * Init a new cache store with a specific namespace
 *
 * @param ns The namespace to use for this cache store
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns;

/**
 * Init a new cache store with a specific namespace and directory
 *
 * @param ns        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nonnull NSString *)directory NS_DESIGNATED_INITIALIZER;

#pragma mark - Cache paths

- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace;

/**
 * Add a read-only cache path to search for images pre-cached by SDImageCache
 * Useful if you want to bundle pre-loaded images with your app
 *
 * @param path The path to use for this read-only cache path
 */
- (void)addReadOnlyCachePath:(nonnull NSString *)path;

#pragma mark - Store Ops 增加缓存

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param toDisk          Store the image to disk cache if YES
 * @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param imageData       The image data as returned by the server, this representation will be used for disk storage
 *                        instead of converting the given image object into a storable/compressed image format in order
 *                        to save quality and CPU
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param toDisk          Store the image to disk cache if YES
 * @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Synchronously store image NSData into disk cache at the given key.
 *
 * @warning This method is synchronous, make sure to call it from the ioQueue
 *
 * @param imageData  The image data to store
 * @param key        The unique image cache key, usually it's image absolute URL
 */
- (void)storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key;

#pragma mark - Query and Retrieve Ops  查询缓存并获取

/**
 *  Async check if image exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 */
- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock;

// 异步的查询图片缓存.
/**
 * Operation that queries the cache asynchronously and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable SDCacheQueryCompletedBlock)doneBlock;

/**
 * Query the memory cache synchronously.
 *
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key;

/**
 * Query the disk cache synchronously.
 *
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key;

/**
 * Query the cache (memory and or disk) synchronously after checking the memory cache.
 *
 * @param key The unique key used to store the image
 */
- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key;

#pragma mark - Remove Ops  删除缓存

// 异步的，从内存或disk删除image
/**
 * Remove the image from memory and disk cache asynchronously
 *
 * @param key             The unique image cache key
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion;

// 异步的，从内存或disk删除image, 可选是否删除disk缓存
/**
 * Remove the image from memory and optionally disk cache asynchronously
 *
 * @param key             The unique image cache key
 * @param fromDisk        Also remove cache entry from disk if YES
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion;

#pragma mark - Cache clean Ops  清空缓存

// 清除内存缓存上的所有image
/**
 * Clear all memory cached images
 */
- (void)clearMemory;


// 同步的，删除所有的磁盘缓存图片，非阻塞方法-立即返回 (带完成block)
/**
 * Async clear all disk cached images. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion;

// 同步的，从disk中，删除所有过期的缓存图片, 非阻塞方法-立即返回(带完成block)
/**
 * Async remove all expired cached image from disk. Non-blocking method - returns immediately.
 * @param completionBlock A block that should be executed after cache expiration completes (optional)
 */
- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock;

#pragma mark - Cache Info  缓存信息

// 获取disk缓存，使用的大小
/**
 * Get the size used by the disk cache
 */
- (NSUInteger)getSize;

// 获取disk缓存中，图片数量
/**
 * Get the number of images in the disk cache
 */
- (NSUInteger)getDiskCount;

// 异步的，计算磁盘缓存大小
/**
 * Asynchronously calculate the disk cache's size.
 */
- (void)calculateSizeWithCompletionBlock:(nullable SDWebImageCalculateSizeBlock)completionBlock;

#pragma mark - Cache Paths 缓存路径

// 根据key，获取缓存路径，(需要缓存的根路径)
/**
 *  Get the cache path for a certain key (needs the cache path root folder)
 *
 *  @param key  the key (can be obtained from url using cacheKeyForURL)
 *  @param path the cache path root folder
 *
 *  @return the cache path
 */
- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path;

// 根据key，获取默认的缓存路径
/**
 *  Get the default cache path for a certain key
 *
 *  @param key the key (can be obtained from url using cacheKeyForURL)
 *
 *  @return the default cache path
 */
- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key;

@end
