/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"

#if SD_UIKIT || SD_MAC

#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"

static char imageURLKey;

#if SD_UIKIT
static char TAG_ACTIVITY_INDICATOR;
static char TAG_ACTIVITY_STYLE;
#endif
static char TAG_ACTIVITY_SHOW;

@implementation UIView (WebCache)

- (nullable NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, &imageURLKey);
}

/**
 框架中的所有操作实际上都是通过一个 operationDictionary 来管理, 而这个字典实际上是动态的添加到 UIView 上的一个属性,
 至于为什么添加到 UIView 上, 主要是因为这个 operationDictionary 需要在 UIButton 和 UIImageView 上重用, 所以需要添加到它们的根类上.
 */
- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock {
    
    // 先取消当前的operation，和sd_setImageLoadOperation中一开始取消索引key的操作思路一致；
    
    
    /**
     取消当前类所对应的所有下载Operation对象，
     key 默认为类名
     */
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];
    
    // 给UIImageView当前这个对象添加一个NSString的关联对象url。相当于现在这个图片的url属性绑定到了UIImageView对象上
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 如果options中没有有SDWebImageDelayPlaceholder这一选项，就不给image赋值，
    // 如果有这一项，那么就给image赋值placeholder
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
        });
    }
    
    if (url) {
        
        // activityView 是否需要显示菊花
        // check if activityView is enabled or not
        if ([self sd_showActivityIndicatorView]) {
            [self sd_addActivityIndicator];
        }
        
        /**
         operation是一个`SDWebImageCombinedOperation`对象。通过这个对象来获取图片
         
         SDWebImageOperation是一个NSOperation子类（这样才能放到NSOperationQueue中进行多任务嘛）
         
         */
        __weak __typeof(self)wself = self;
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager loadImageWithURL:url options:options progress:progressBlock completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            
            __strong __typeof (wself) sself = wself;
            [sself sd_removeActivityIndicator];     // 停止菊花
            if (!sself) {
                return;
            }
            dispatch_main_async_safe(^{
                if (!sself) {
                    return;
                }
                
                /**
                 如果设置了不自动显示图片，则直接调用completedBlock，让调用者处理图片的显示
                 
                 SDWebImageAvoidAutoSetImage对图片做一些处理,在compeletedBlock手动处理
                 */
                if (image && (options & SDWebImageAvoidAutoSetImage) && completedBlock) {
                    completedBlock(image, error, cacheType, url);
                    return;
                } else if (image) {     // 下载到图片
                     // 自动显示图片
                    [sself sd_setImage:image imageData:data basedOnClassOrViaCustomSetImageBlock:setImageBlock];
                    [sself sd_setNeedsLayout];
                } else {
                    
                    /**
                     如果设置了延迟显示占位图，则图片加载失败的情况下显示占位图
                     
                     */
                    // 如果options中没有有SDWebImageDelayPlaceholder这一选项，就不给image赋值，
                    // 如果有这一项，那么就给image赋值placeholder
                    if ((options & SDWebImageDelayPlaceholder)) {
                        [sself sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
                        [sself sd_setNeedsLayout];
                    }
                }
                
                // 完成回调
                if (completedBlock && finished) {
                    completedBlock(image, error, cacheType, url);
                }
            });
        }];
        
        // 关联Operationkey与Operation对象。方便后面根据key取消operation操作等。
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        
        // url不存在的情况
        dispatch_main_async_safe(^{
            [self sd_removeActivityIndicator];  // 移除菊花
            if (completedBlock) {
                
                // 首先自定义一个NSError的对象，表示url为空的错误。然后传给compeletedBlock。
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

/**
 取消当前Class对应的所有加载请求
 */
/**
 上面这个方法又会调用UIView+WebCacheOperation分类的sd_cancelImageLoadOperationWithKey方法来实现，这个方法会调用SDWebImageCombinedOperation对象的cancel方法,然后在cancel方法中再调用SDWebImageDownloadOperation或者NSOperation的cancel方法
 */
- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock {
    if (setImageBlock) {
        setImageBlock(image, imageData);
        return;
    }
    
#if SD_UIKIT || SD_MAC
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        imageView.image = image;
    }
#endif
    
#if SD_UIKIT
    if ([self isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)self;
        [button setImage:image forState:UIControlStateNormal];
    }
#endif
}

- (void)sd_setNeedsLayout {
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#endif
}

#pragma mark - Activity indicator

/**
 给UIView及其子类添加旋转菊花是通过关联对象来实现的
 
 */

#pragma mark -
#if SD_UIKIT

// 通过关联对象来实现菊花的添加
- (UIActivityIndicatorView *)activityIndicator {
    return (UIActivityIndicatorView *)objc_getAssociatedObject(self, &TAG_ACTIVITY_INDICATOR);
}

- (void)setActivityIndicator:(UIActivityIndicatorView *)activityIndicator {
    objc_setAssociatedObject(self, &TAG_ACTIVITY_INDICATOR, activityIndicator, OBJC_ASSOCIATION_RETAIN);
}
#endif

// 是否显示旋转菊花
- (void)sd_setShowActivityIndicatorView:(BOOL)show {
    objc_setAssociatedObject(self, &TAG_ACTIVITY_SHOW, @(show), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)sd_showActivityIndicatorView {
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_SHOW) boolValue];
}

#if SD_UIKIT

// 旋转菊花的样式
- (void)sd_setIndicatorStyle:(UIActivityIndicatorViewStyle)style{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_STYLE, [NSNumber numberWithInt:style], OBJC_ASSOCIATION_RETAIN);
}

- (int)sd_getIndicatorStyle{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_STYLE) intValue];
}
#endif

// 添加转动的菊花
- (void)sd_addActivityIndicator {
#if SD_UIKIT
    dispatch_main_async_safe(^{
        if (!self.activityIndicator) {
            self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[self sd_getIndicatorStyle]];
            self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        
            [self addSubview:self.activityIndicator];
            
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.0]];
        }
        [self.activityIndicator startAnimating];
    });
#endif
}

// 停止菊花
- (void)sd_removeActivityIndicator {
#if SD_UIKIT
    dispatch_main_async_safe(^{
        if (self.activityIndicator) {
            [self.activityIndicator removeFromSuperview];
            self.activityIndicator = nil;
        }
    });
#endif
}

@end

#endif
