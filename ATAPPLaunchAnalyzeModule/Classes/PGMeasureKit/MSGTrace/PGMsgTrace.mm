//
//  PGMsgTrace.m
//  pgHook
//
//  Created by lixiaoqing on 2021/11/23.
//

#import "PGMsgTrace.h"
#import "PGMsgTraceCore.hpp"
#include <pthread.h>
#import "PGMeasureDesc.h"


static void (^_orderFileBlock)(NSArray<NSString *> *orderFile,BOOL finish);

static void (^_funcCallBlock)(NSArray<PGMeasureDesc *> *orderFile,BOOL finish);

static void _funcInfo(vector<PGCallInfo> *callInfos,bool finish){
    if (_funcCallBlock == NULL || callInfos == nullptr || callInfos->size() == 0) {
        return;
    }
    NSMutableArray<PGMeasureDesc *> *result = [NSMutableArray array];
    for(int i = 0;i < callInfos->size();i++) {
        PGCallInfo info = callInfos->at(i);
        PGMeasureDesc *desc = [[PGMeasureDesc alloc] initWithCallInfo:&info];
        [result addObject:desc];
    }
    _funcCallBlock(result,finish);
}

static void _orderInfo(vector<PGOrderInfo> *orderInfo,bool finish){
    if (_orderFileBlock == NULL || orderInfo == nullptr || orderInfo->size() == 0) {
        return;
    }
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for(int i = 0;i < orderInfo->size();i++) {
        PGOrderInfo info = orderInfo->at(i);
        if (info.is_class_method) {
            NSString *ord = [NSString stringWithFormat:@"+[%@ %@]",NSStringFromClass(info.cls),info.isload ? @"load" : NSStringFromSelector(info.sel)];
            if(![result containsObject:ord]){
                [result addObject:ord];
            }
        }else{
            NSString *ord = [NSString stringWithFormat:@"-[%@ %@]",NSStringFromClass(info.cls),NSStringFromSelector(info.sel)];
            if(![result containsObject:ord]){
                [result addObject:ord];
            }
        }
    }
    _orderFileBlock(result,finish);
}

@implementation PGMsgTrace

+ (void)start{
    PGMSGTrace::register_callback_funcInfo(_funcInfo);
    PGMSGTrace::register_callback_orderInfo(_orderInfo);
    PGMSGTrace::start();
}

+ (void)stop{
    PGMSGTrace::stop();
}

+ (void)stopOrderFile{
    PGMSGTrace::stopOrderFile();
}



+ (void)flush{
    PGMSGTrace::flush();
}


+ (void)configMinTime:(uint64_t)us{
    PGMSGTrace::configMinTime(us);
}

+ (void)configMaxDepth:(int)depth{
    PGMSGTrace::configMaxDepth(depth);
}

+ (void)configOnlyMonitorMainThread:(BOOL)only{
    PGMSGTrace::configOnlyMainThread(only);
}

+ (void)configSupportOutputOrderFile:(BOOL)support{
    PGMSGTrace::configSupportOutputOrderFile(support);
}

+ (void)clearData{
    PGMSGTrace::clearData();
}


+ (void)outputOrderFileBlock:(void(^)(NSArray<NSString *> *orderFile,BOOL finish))block{
    _orderFileBlock = block;
}

+ (void)outputFuncCallBlock:(void(^)(NSArray<PGMeasureDesc *> *measureDescs,BOOL finish))block{
    _funcCallBlock = block;
}

+(void)addWhiteList:(Class) cls{
    PGMSGTrace::addWhiteList(cls);
}


@end

