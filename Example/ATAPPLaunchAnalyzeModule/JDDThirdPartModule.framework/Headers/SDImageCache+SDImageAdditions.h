//
//  SDImageCache+Additions.h
//  SDWebImage
//
//  Created by dajie on 14-10-9.
//  Copyright (c) 2014年 Dailymotion. All rights reserved.
//

#import "SDImageCache.h"

void report_memory(void);

@interface SDImageCache (Additions)
/**
 * Query the memory cache for an image at a given key and fallback to disk cache
 * synchronousely if not found in memory.
 *
 * @warning This method may perform some synchronous IO operations
 *
 * @param key The unique key used to store the wanted image
 */
- (UIImage *)imageFromKey:(NSString *)key;

/**
 * Query the memory cache for an image at a given key and optionnaly fallback to disk cache
 * synchronousely if not found in memory.
 *
 * @warning This method may perform some synchronous IO operations if fromDisk is YES
 *
 * @param key The unique key used to store the wanted image
 * @param fromDisk Try to retrive the image from disk if not found in memory if YES
 */
- (UIImage *)imageFromKey:(NSString *)key fromDisk:(BOOL)fromDisk;


@end
