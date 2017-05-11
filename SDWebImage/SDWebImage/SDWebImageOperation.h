/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>

// 图片下载操作的基础协议

// SDWebImageOperation只有一个cancel接口
@protocol SDWebImageOperation <NSObject>

- (void)cancel;

@end
