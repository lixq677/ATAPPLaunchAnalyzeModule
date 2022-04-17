//
//  PGMeasureDesc.m
//  PGMeasureKit
//
//  Created by lixiaoqing on 2021/11/29.
//

#import "PGMeasureDesc.h"
#import "YYModel.h"
#import "PGMsgTraceCore.hpp"
#import "PGLoad.h"

@interface PGMeasureDesc () <YYModel>


@end

@implementation PGMeasureDesc
@synthesize depth = _depth;

- (instancetype)init{
    if (self = [super init]) {
        _ph = @"X";
        _pid = getpid();
    }
    return self;
}

- (instancetype)initWithCallInfo:(void *)info{
    if (self = [self init]){
        PGCallInfo *callInfo = (PGCallInfo *)info;
        _ts = callInfo->ts;
        _depth = callInfo->depth;
        if (callInfo->is_main_thread) {
            _tid = 0;
        }else{
            _tid = callInfo->tid;
        }
        NSString *clsName = NSStringFromClass(callInfo->cls);
        _className = clsName;
        if (callInfo->isload) {
            _name = [NSString stringWithFormat:@"%@+load",clsName];
            _selName = @"load";
        }else{
            if (callInfo->is_class_method) {
                NSString *selName = NSStringFromSelector(callInfo->sel);
                _name = [NSString stringWithFormat:@"%@+%@",clsName,selName];
                _selName = selName;
            }else{
                NSString *sel = NSStringFromSelector(callInfo->sel);
                if ([sel isEqualToString:@"aspects__viewDidLoad"]) {
                    sel = @"viewDidLoad";
                }else if ([sel isEqualToString:@"aspects__viewWillAppear:"]){
                    sel = @"viewWillAppear:";
                }else if ([sel isEqualToString:@"aspects__viewDidAppear:"]){
                    sel = @"viewDidAppear:";
                }
                _name = [NSString stringWithFormat:@"%@-%@",clsName,sel];
                _selName = sel;
            }
        }
        _dur = callInfo->duration;
    }
    return self;
}


- (NSString *)description{
    NSString *json = [self yy_modelToJSONString];
    return json;
}

+ (nullable NSArray<NSString *> *)modelPropertyBlacklist{
    return @[@"className",@"selName"];
}

@end
