/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) james <https://github.com/mystcolor>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

/**
 根据图片的情况，做图片的解压缩处理。
 
 通过这个类实现图片的解压缩操作。对于太大的图片，先按照一定比例缩小图片然后再解压缩。
 
 */
@interface UIImage (ForceDecode)

// 图片数据解码操作
+ (nullable UIImage *)decodedImageWithImage:(nullable UIImage *)image;

// 解码、解压缩、缩放
+ (nullable UIImage *)decodedAndScaledDownImageWithImage:(nullable UIImage *)image;

@end
