//
//  SDWebImagePrefetcher+Additions.h
//  JDiOSFramework
//
//  Created by wangjianping on 16/9/19.
//  Copyright © 2016年 steven sun. All rights reserved.
//

//#import <JDThirdParty/JDThirdParty.h>
#import "SDWebImagePrefetcher.h"

@interface SDWebImagePrefetcher (Additions)


//add by jd 王建平 修改迁移过来
- (void)prefetchURLs:(NSArray *)urls options:(SDWebImageOptions)op;

@end
