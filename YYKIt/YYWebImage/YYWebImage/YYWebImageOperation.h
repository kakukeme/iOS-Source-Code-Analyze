//
//  YYWebImageOperation.h
//  YYWebImage <https://github.com/ibireme/YYWebImage>
//
//  Created by ibireme on 15/2/15.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

#if __has_include(<YYWebImage/YYWebImage.h>)
#import <YYWebImage/YYImageCache.h>
#import <YYWebImage/YYWebImageManager.h>
#else
#import "YYImageCache.h"
#import "YYWebImageManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN


/**
 *  YYWebImageOperation 类是NSOperation的子类,用来通过请求获取图片,
 
 @discussion 首先这个operation是异步的,你可以通过把operation添加到一个queue里面来让这个operation生效,或者直接调用'start'方法.当这个operation开始之后,将会做以下事情:
 1.从cache获取 图片,如果取到了,就返回'completion'block,并把图片传入block.
 2.通过图片URL开启一个请求,会通过'progress'参数来通知我们图片下载的进度,并且如果在传入option的时候开启了progressive option,会在completionblock里面返回一个渐进显示的图片
 3.通过'transform'block来处理图片
 4.把图片丢到cache中并且在'completion'block返回
 */

/**
 The YYWebImageOperation class is an NSOperation subclass used to fetch image
 from URL request.
 
 @discussion It's an asynchronous operation. You typically execute it by adding 
 it to an operation queue, or calls 'start' to execute it manually. When the 
 operation is started, it will:
 
     1. Get the image from the cache, if exist, return it with `completion` block.
     2. Start an URL connection to fetch image from the request, invoke the `progress`
        to notify request progress (and invoke `completion` block to return the 
        progressive image if enabled by progressive option).
     3. Process the image by invoke the `transform` block.
     4. Put the image to cache and return it with `completion` block.
 
 */
@interface YYWebImageOperation : NSOperation

@property (nonatomic, strong, readonly)           NSURLRequest      *request;  ///< The image URL request.      图片请求
@property (nullable, nonatomic, strong, readonly) NSURLResponse     *response; ///< The response for request.   请求的相应结果
@property (nullable, nonatomic, strong, readonly) YYImageCache      *cache;    ///< The image cache.            缓存
@property (nonatomic, strong, readonly)           NSString          *cacheKey; ///< The image cache key.        缓存key
@property (nonatomic, readonly)                   YYWebImageOptions options;   ///< The operation's option. 理解为下载图片模式,具体见YYWebImageManager


/**
 *  这个URL connection 是否是从 存储的认证里面授权查阅出来的.默认值为YES
 @discussion 这个值是 NSURLConnectionDelegate 的方法 -connectionShouldUseCredentialStorage: 的返回值
 */

/**
 Whether the URL connection should consult the credential storage for authenticating 
 the connection. Default is YES.
 
 @discussion This is the value that is returned in the `NSURLConnectionDelegate` 
 method `-connectionShouldUseCredentialStorage:`.
 */
@property (nonatomic) BOOL shouldUseCredentialStorage;

/**
 NSURLCredential类, 这个credential 在授权变化的回调 `-connection:didReceiveAuthenticationChallenge:` 使用
 
 @discussion 这将会覆盖共享的credentials，
 */
/**
 The credential used for authentication challenges in `-connection:didReceiveAuthenticationChallenge:`.
 
 @discussion This will be overridden by any shared credentials that exist for the 
 username or password of the request URL, if present.
 */
@property (nullable, nonatomic, strong) NSURLCredential *credential;


/**
 构造方法,会创建并返回一个新的operation
 
 你应该调用start方法来开启这个operation,或者把它加到一个operation queue
 
 @param request    图片请求,不可为nil
 @param options    下载模式
 @param cache      图片缓存,传nil的话就禁用了缓存
 @param cacheKey   缓存key,传nil禁用图片缓存
 @param progress   下载进度block
 @param transform  这个block会在图片下载完成之前调用，来让你对图片进行一些预处理,传nil禁用
 @param completion 图片下载完成后或者已经取消下载了调用
 
 @return operation实例,出现错误的话就为nil
 */

/**
 Creates and returns a new operation.
 
 You should call `start` to execute this operation, or you can add the operation
 to an operation queue.
 
 @param request    The Image request. This value should not be nil.
 @param options    A mask to specify options to use for this operation.
 @param cache      An image cache. Pass nil to avoid image cache.
 @param cacheKey   An image cache key. Pass nil to avoid image cache.
 @param progress   A block invoked in image fetch progress.
                     The block will be invoked in background thread. Pass nil to avoid it.
 @param transform  A block invoked before image fetch finished to do additional image process.
                     The block will be invoked in background thread. Pass nil to avoid it.
 @param completion A block invoked when image fetch finished or cancelled.
                     The block will be invoked in background thread. Pass nil to avoid it.
 
 @return The image request opeartion, or nil if an error occurs.
 */
- (instancetype)initWithRequest:(NSURLRequest *)request
                        options:(YYWebImageOptions)options
                          cache:(nullable YYImageCache *)cache
                       cacheKey:(nullable NSString *)cacheKey
                       progress:(nullable YYWebImageProgressBlock)progress
                      transform:(nullable YYWebImageTransformBlock)transform
                     completion:(nullable YYWebImageCompletionBlock)completion NS_DESIGNATED_INITIALIZER;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
