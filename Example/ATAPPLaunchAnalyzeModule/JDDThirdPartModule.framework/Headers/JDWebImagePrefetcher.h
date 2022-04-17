//
//  JDWebImagePrefetcher.h
//  JDBSDWebImageModule
//
//  Created by 李梦珂 on 2019/2/14.
//

#import <Foundation/Foundation.h>

@interface JDWebImagePrefetcher : NSObject

/**
 * Allows you to instantiate a prefetcher with any image path.
 */
- (id)initWithImagePath:(NSString *)path;

/**
 * Clear image cache.
 */
- (void)clearDisk;

/**
 * Assign list of URLs to let SDWebImagePrefetcher to queue the prefetching,
 * currently one image is downloaded at a time,
 * and skips images for failed downloads and proceed to the next image in the list
 *
 * @param urls list of URLs to prefetch
 */
- (void)prefetchURLs:(NSArray *)urls;

/**
 * Remove and cancel queued list
 */
- (void)cancelPrefetching;


@end
