/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Laurin Brandner
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"

/**
 对于一张图片是否GIF做判断。
 
 可以根据NSData返回一张GIF的UIImage对象，并且只返回GIF的第一张图片生成的Image
 */
@interface UIImage (GIF)

/**
 *  Compatibility method - creates an animated UIImage from an NSData, it will only contain the 1st frame image
 */
+ (UIImage *)sd_animatedGIFWithData:(NSData *)data;

//
/**
 *  Checks if an UIImage instance is a GIF. Will use the `images` array
 */
- (BOOL)isGIF;

@end
