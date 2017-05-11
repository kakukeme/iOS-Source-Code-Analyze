/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCacheOperation.h"

#if SD_UIKIT || SD_MAC

#import "objc/runtime.h"

static char loadOperationKey;

typedef NSMutableDictionary<NSString *, id> SDOperationsDictionary;

@implementation UIView (WebCacheOperation)

/**
 框架中的所有操作实际上都是通过一个 operationDictionary 来管理, 而这个字典实际上是动态的添加到 UIView 上的一个属性,
 至于为什么添加到 UIView 上, 主要是因为这个 operationDictionary 需要在 UIButton 和 UIImageView 上重用, 所以需要添加到它们的根类上.
 
 */
- (SDOperationsDictionary *)operationDictionary {
    SDOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
    if (operations) {
        return operations;
    }
    operations = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return operations;
}


/**
 关联Operation对象与key对象
 
 @param operation Operation对象
 @param key key
 */
/**
 
 向operationDictionary中添加operation
 
 key, 默认为类名；
 */
- (void)sd_setImageLoadOperation:(nullable id)operation forKey:(nullable NSString *)key {
    if (key) {
        [self sd_cancelImageLoadOperationWithKey:key];  // 先取消索引为key的operation的操作
        if (operation) {
            
            // 存放的一定是各种operation的序列了（当然也就包括SDWebImageOperation类型的operation），而且这些operation是根据key来索引的
            SDOperationsDictionary *operationDictionary = [self operationDictionary];
            operationDictionary[key] = operation;
        }
    }
}

/**
 先获取到operation的序列，即[self operationDictionary]。然后根据key来索引到对应的operation，如果operation存在的话。就要取消该operation。这里有一个注意的地方，也是我之前没想到的，就是索引到的operation其实一组operation的集合，那么就需要来个遍历一个个取消掉operations序列中的operation了。最后移除key对应的object。
 
 */

/**
 如果该operation存在，就取消掉了，还要删除这个key对应的object（operation）。然后重新设置key对应的operation。
 
 key, 默认为类名；
 */

/**
 取消当前key对应的所有实现了SDWebImageOperation协议的Operation对象
 
 @param key Operation对应的key
 */
- (void)sd_cancelImageLoadOperationWithKey:(nullable NSString *)key {
    // Cancel in progress downloader from queue
    SDOperationsDictionary *operationDictionary = [self operationDictionary];
    id operations = operationDictionary[key];
    if (operations) {
        if ([operations isKindOfClass:[NSArray class]]) {  // 是一组operation的集合，遍历取消；
            for (id <SDWebImageOperation> operation in operations) {
                if (operation) {
                    [operation cancel];
                }
            }
        } else if ([operations conformsToProtocol:@protocol(SDWebImageOperation)]){
            [(id<SDWebImageOperation>) operations cancel];  // 遵守协议对象，调用取消方法；
        }
        [operationDictionary removeObjectForKey:key];   // 取消后，从operationDictionary中移除
    }
}

/**
 只是从operationDictionary中移除，没有取消
 
 */
- (void)sd_removeImageLoadOperationWithKey:(nullable NSString *)key {
    if (key) {
        SDOperationsDictionary *operationDictionary = [self operationDictionary];
        [operationDictionary removeObjectForKey:key];
    }
}

@end

#endif
