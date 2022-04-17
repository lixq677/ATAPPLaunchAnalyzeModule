//
//  PGMsgTrace.h
//  pgHook
//
//  Created by lixiaoqing on 2021/11/23.
//

#import <Foundation/Foundation.h>

@class PGMeasureDesc;

NS_ASSUME_NONNULL_BEGIN

@interface PGMsgTrace : NSObject

/**
 开启hook 并记录数据
 */
+ (void)start;

/**
 输出记录数据
 */
+ (void)flush;

/**
 停止记录数据，清空数据，释放内存空间
 */
+ (void)stop;

/*
 * 如果支持orderfile ，调用止函数后，停止记录!
 */
+ (void)stopOrderFile;

/**
 记录函数消耗时长的最低阀值
 */
+ (void)configMinTime:(uint64_t)us;

/**
 记录函数调用深度，默认3级，高于3级的调用不记录数据
 */
+ (void)configMaxDepth:(int)depth;

/**
 是否只监听主线程函数调用
 */
+ (void)configOnlyMonitorMainThread:(BOOL)only;


/*支持输出orderFile*/
+ (void)configSupportOutputOrderFile:(BOOL)support;

/**
 清理记录数据，此数据存在堆区，如果长时间开启记录函数数据，需要不断清理
 如果记录记动时各函数的调用数据，在记录完后，建议停止数据
 */
+ (void)clearData;

/*白名单，只有加入白名单的类函数成员函数统计*/
+(void)addWhiteList:(Class) cls;

+ (void)outputOrderFileBlock:(void(^)(NSArray<NSString *> *orderFile,BOOL finish))block;

+ (void)outputFuncCallBlock:(void(^)(NSArray<PGMeasureDesc *> *measureDescs,BOOL finish))block;


@end

NS_ASSUME_NONNULL_END
