//
//  YYImageCache.h
//  YYWebImage <https://github.com/ibireme/YYWebImage>
//
//  Created by ibireme on 15/2/15.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

@class YYMemoryCache, YYDiskCache;

NS_ASSUME_NONNULL_BEGIN

/// 图片缓存类型
/// Image cache type
typedef NS_OPTIONS(NSUInteger, YYImageCacheType) {
    /// No value.
    YYImageCacheTypeNone   = 0,
    
    /// Get/store image with memory cache.  从内存中获取
    YYImageCacheTypeMemory = 1 << 0,
    
    /// Get/store image with disk cache.  从磁盘中获取
    YYImageCacheTypeDisk   = 1 << 1,
    
    /// Get/store image with both memory cache and disk cache.  同时获取
    YYImageCacheTypeAll    = YYImageCacheTypeMemory | YYImageCacheTypeDisk,
};


/**
 YYImageCache是一个用来存储UIImage和image数据的缓存,是基于内存缓存与磁盘缓存实现的
 
 @discussion 磁盘缓存会尝试保护原始的图片数据
 
 * 如果原始的图片仍是image,会保存为一个png或者jpeg，根据alpha信息
 * 如果原始图片是一个gif,apng,webp动图,会保存为原始格式
 * 如果原始图片缩放比例不是1,那么缩放值会被保存为一个缩放的数据
 
 虽然图片能被NSCoding协议解码,但是这不是一个最优解:
 苹果的确使用UIImagePNGRepresentation()来解码所有类型的图片,但是可能会丢失原始的可变帧数据.
 结果就是打包成plist文件不能直接查看照片. 如果图片没有alpha通道,使用JPEG代替PNG保存，能够节省更多的磁盘空间和编解码时间.
 */

/**
 YYImageCache is a cache that stores UIImage and image data based on memory cache and disk cache.
 
 @discussion The disk cache will try to protect the original image data:
 
 * If the original image is still image, it will be saved as png/jpeg file based on alpha information.
 * If the original image is animated gif, apng or webp, it will be saved as original format.
 * If the original image's scale is not 1, the scale value will be saved as extended data.
 
 Although UIImage can be serialized with NSCoding protocol, but it's not a good idea:
 Apple actually use UIImagePNGRepresentation() to encode all kind of image, it may 
 lose the original multi-frame data. The result is packed to plist file and cannot
 view with photo viewer directly. If the image has no alpha channel, using JPEG 
 instead of PNG can save more disk size and encoding/decoding time.
 */
@interface YYImageCache : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

// 缓存名字,默认为nil
/** The name of the cache. Default is nil. */
@property (nullable, copy) NSString *name;

// 内存缓存,具体信息看 YYMemoryCache
/** The underlying memory cache. see `YYMemoryCache` for more information.*/
@property (strong, readonly) YYMemoryCache *memoryCache;

// 磁盘缓存,具体信息看YYDiskCache
/** The underlying disk cache. see `YYDiskCache` for more information.*/
@property (strong, readonly) YYDiskCache *diskCache;

/**
 *  当从磁盘缓存请求图片的时候,是否解码动图,默认为YES
 
 @discussion 当从磁盘缓存读取图片,会使用YYImage来解码比如WebP/APNG/GIF格式的动图,设置这个值为NO可以忽略动图
 */

/**
 Whether decode animated image when fetch image from disk cache. Default is YES.
 
 @discussion When fetch image from disk cache, it will use 'YYImage' to decode 
 animated image such as WebP/APNG/GIF. Set to 'NO' to ignore animated image.
 */
@property BOOL allowAnimatedImage;

/**
 *  是否解码图片到存储位图,默认为YES
 
 @discussion 如果这个值为YES,图片会通过位图解码来获得更好的用户体验,但是可能会消耗更大的内存资源
 */

/**
 Whether decode the image to memory bitmap. Default is YES.
 
 @discussion If the value is YES, then the image will be decoded to memory bitmap
 for better display performance, but may cost more memory.
 */
@property BOOL decodeForDisplay;


#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


/**
 *  单例类初始化方法
 */
/**
 Returns global shared image cache instance.
 @return  The singleton YYImageCache instance.
 */
+ (instancetype)sharedCache;



/**
 *  初始化方法,在多个实例访问同一个路径会导致缓存不稳定
 *
 *  @param path cache读写的全路径,只初始化一次,你不应该来读写这个路径
 *
 *  @return 一个新的缓存对象,或者返回带nil带error信息
 */

/**
 The designated initializer. Multiple instances with the same path will make the
 cache unstable.
 
 @param path Full path of a directory in which the cache will write data.
 Once initialized you should not read and write to this directory.
 @result A new cache object, or nil if an error occurs.
 */
- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;


#pragma mark - Access Methods
///=============================================================================
/// @name Access Methods
///=============================================================================


/**
 *  把图片通过一个具体的key存进缓存,同时memory跟disk都会存,这个方法会立刻返回,在后台线程执行
 *
 *  @param image 要存储的图片，如果为nil这个方法无效
 *  @param key 存储图片的key,为nil这个方法无效
 */

/**
 Sets the image with the specified key in the cache (both memory and disk).
 This method returns immediately and executes the store operation in background.
 
 @param image The image to be stored in the cache. If nil, this method has no effect.
 @param key   The key with which to associate the image. If nil, this method has no effect.
 */
- (void)setImage:(UIImage *)image forKey:(NSString *)key;


/**
 *  通过一个key把图片缓存,这个方法会立刻返回并在后台执行；
 
 如果'type'包括'YYImageCacheTypeMemory',那么图片会被存进memory,如果image为nil会用'imageData'代替；
 如果'type'包括'YYImageCacheTypeDisk',那么'imageData'会被存进磁盘缓存,如果'imageData'为nil会用image代替
 
 //这里可以看到作者一个思想,如果存进memory,直接存image,会减小很多解码的消耗,如果存disk,会存imageData
 
 */

/**
 Sets the image with the specified key in the cache.
 This method returns immediately and executes the store operation in background.
 
 @discussion If the `type` contain `YYImageCacheTypeMemory`, then the `image` will 
 be stored in the memory cache; `imageData` will be used instead if `image` is nil.
 If the `type` contain `YYImageCacheTypeDisk`, then the `imageData` will
 be stored in the disk cache; `image` will be used instead if `imageData` is nil.
 
 @param image     The image to be stored in the cache.
 @param imageData The image data to be stored in the cache.
 @param key       The key with which to associate the image. If nil, this method has no effect.
 @param type      The cache type to store image.
 */
- (void)setImage:(nullable UIImage *)image
       imageData:(nullable NSData *)imageData
          forKey:(NSString *)key
        withType:(YYImageCacheType)type;

/**
 *  通过key移除cache中的一个图片,memory跟disk会同时移除
    这个方法会立刻返回并在后台线程执行

 *  @param key 移除图片用的key,为nil的话这个方法没啥用
 */

/**
 Removes the image of the specified key in the cache (both memory and disk).
 This method returns immediately and executes the remove operation in background.
 
 @param key The key identifying the image to be removed. If nil, this method has no effect.
 */
- (void)removeImageForKey:(NSString *)key;

/**
 *  从缓存中通过key删图片，
    这个方法会立刻返回并在后台线程执行
 *
 *  @param key  key
 *  @param type 从哪删除,跟上个方法不同,这个可以删除指定类型的缓存
 */

/**
 Removes the image of the specified key in the cache.
 This method returns immediately and executes the remove operation in background.
 
 @param key  The key identifying the image to be removed. If nil, this method has no effect.
 @param type The cache type to remove image.
 */
- (void)removeImageForKey:(NSString *)key withType:(YYImageCacheType)type;


/**
 *  通过key检查缓存中是否有某个图片
    如果图片不在内存中,这个方法可能会阻塞线程,直到这个文件读取完毕
 
 */

/**
 Returns a Boolean value that indicates whether a given key is in cache.
 If the image is not in memory, this method may blocks the calling thread until 
 file read finished.
 
 @param key A string identifying the image. If nil, just return NO.
 @return Whether the image is in cache.
 */
- (BOOL)containsImageForKey:(NSString *)key;

// 跟上个差不多,只不过可以查具体类型的缓存
/**
 Returns a Boolean value that indicates whether a given key is in cache.
 If the image is not in memory and the `type` contains `YYImageCacheTypeDisk`,
 this method may blocks the calling thread until file read finished.
 
 @param key  A string identifying the image. If nil, just return NO.
 @param type The cache type.
 @return Whether the image is in cache.
 */
- (BOOL)containsImageForKey:(NSString *)key withType:(YYImageCacheType)type;

// 通过key获取图片,如果图片不在内存中,这个方法可能会阻塞线程直到文件读取完毕
/**
 Returns the image associated with a given key.
 If the image is not in memory, this method may blocks the calling thread until
 file read finished.
 
 @param key A string identifying the image. If nil, just return nil.
 @return The image associated with key, or nil if no image is associated with key.
 */
- (nullable UIImage *)getImageForKey:(NSString *)key;

// 跟上个方法差不多,只不过从指定缓存类型中获取图片
/**
 Returns the image associated with a given key.
 If the image is not in memory and the `type` contains `YYImageCacheTypeDisk`,
 this method may blocks the calling thread until file read finished.
 
 @param key A string identifying the image. If nil, just return nil.
 @return The image associated with key, or nil if no image is associated with key.
 */
- (nullable UIImage *)getImageForKey:(NSString *)key withType:(YYImageCacheType)type;

/**
 Asynchronously get the image associated with a given key.
 
 通过key异步的获取图片
 
 @param key   A string identifying the image. If nil, just return nil.
 @param type  The cache type.
 @param block A completion block which will be called on main thread.
 */
- (void)getImageForKey:(NSString *)key
              withType:(YYImageCacheType)type
             withBlock:(void(^)(UIImage * _Nullable image, YYImageCacheType type))block;

/**
 Returns the image data associated with a given key.
 This method may blocks the calling thread until file read finished.
 
 通过key查找图片数据data格式,方法会阻塞主线程直到文文件读取完毕
 
 @param key A string identifying the image. If nil, just return nil.
 @return The image data associated with key, or nil if no image is associated with key.
 */
- (nullable NSData *)getImageDataForKey:(NSString *)key;

/**
 Asynchronously get the image data associated with a given key.
 
 通过key来异步的获取图片数据
 
 @param key   A string identifying the image. If nil, just return nil.
 @param block A completion block which will be called on main thread.
 */
- (void)getImageDataForKey:(NSString *)key
                 withBlock:(void(^)(NSData * _Nullable imageData))block;

@end

NS_ASSUME_NONNULL_END
