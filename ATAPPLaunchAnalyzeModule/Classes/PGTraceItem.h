//
//  TestModel.h
//  APPLuanchChecker
//
//  Created by hexiao on 2021/11/24.
//  Copyright © 2021 常焕丽. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PGTraceItem : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *ph;
@property (nonatomic, copy) NSString *pid;
@property (nonatomic, copy) NSString *tid;
@property (nonatomic, assign) NSInteger ts;
@property (nonatomic, assign) NSInteger dur;
@property (nonatomic, strong) NSDate *date;

@end

NS_ASSUME_NONNULL_END
