//
//  PGMeasure.h
//  PGMeasureKit
//
//  Created by lixiaoqing on 2021/11/26.
//
#import <Foundation/Foundation.h>
#import "PGMeasureDesc.h"

NS_ASSUME_NONNULL_BEGIN

@interface PGMeasure : NSObject//单位us

/*启动时长*/
@property(nonatomic,assign,readonly)uint64_t startDuration;

/*load mach-o 时长*/
@property(nonatomic,assign,readonly)uint64_t loadDuration;

/*pre-main 时长*/
@property(nonatomic,assign,readonly)uint64_t premainDuration;

/*application:didFinishLaunchingWithOptions: 调用时长*/
@property(nonatomic,assign,readonly)uint64_t launchDuration;

/*首屏渲染时长*/
@property(nonatomic,assign,readonly)uint64_t renderDuration;

/*监控初始化花费时长*/
@property(nonatomic,assign)uint64_t monitorDuration;

@property (nonatomic,assign)BOOL generateOrderFile;

@property (nonatomic,assign)BOOL monitor;

+(id)shareInstance;

@end


NS_ASSUME_NONNULL_END
