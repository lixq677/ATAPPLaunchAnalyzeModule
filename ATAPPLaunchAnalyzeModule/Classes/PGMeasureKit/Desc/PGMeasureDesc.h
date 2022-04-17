//
//  PGMeasureDesc.h
//  PGMeasureKit
//
//  Created by lixiaoqing on 2021/11/29.
//

#import <Foundation/Foundation.h>
#import "LKDBHelper.h"

NS_ASSUME_NONNULL_BEGIN

@class PGLoadInfo;

@interface PGMeasureDesc : NSObject

@property (nonatomic,strong)NSString *ph;

@property (nonatomic,assign)uint64_t ts;

@property (nonatomic,assign)int tid;

@property (nonatomic,assign)uint64_t dur;

@property (nonatomic,strong)NSString *name;

@property (nonatomic,assign)int pid;

@property (nonatomic,assign)int depth;

@property (nonatomic,strong)NSString *className;

@property (nonatomic,strong)NSString *selName;

- (instancetype)initWithCallInfo:(void *)callInfo;

@end

NS_ASSUME_NONNULL_END
