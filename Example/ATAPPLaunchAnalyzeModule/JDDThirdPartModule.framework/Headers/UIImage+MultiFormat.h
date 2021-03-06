//
//  UIImage+MultiFormat.h
//  SDWebImage
//
//  Created by Olivier Poitrey on 07/06/13.
//  Copyright (c) 2013 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSData+ImageContentType.h"

@interface UIImage (MultiFormat)

/**
* UIKit:
* For static image format, this value is always 0.
* For animated image format, 0 means infinite looping.
* @note Note that because of the limitations of categories this property can get out of sync if you create another instance with CGImage or other methods.
* AppKit:
* NSImage currently only support animated via GIF imageRep unlike UIImage.
* The getter of this property will get the loop count from GIF imageRep
* The setter of this property will set the loop count from GIF imageRep
*/
@property (nonatomic, assign) NSUInteger sd_imageLoopCount;

/**
 * The image format represent the original compressed image data format.
 * If you don't manually specify a format, this information is retrieve from CGImage using `CGImageGetUTType`, which may return nil for non-CG based image. At this time it will return `SDImageFormatUndefined` as default value.
 * @note Note that because of the limitations of categories this property can get out of sync if you create another instance with CGImage or other methods.
 */
@property (nonatomic, assign) SDImageFormat sd_imageFormat;

+ (UIImage *)sd_imageWithData:(NSData *)data;

+ (UIImage *)sd_imageWithData:(NSData *)data error:(NSError **)error;

@end
