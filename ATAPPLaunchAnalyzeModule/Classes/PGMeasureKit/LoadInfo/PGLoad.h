//
//  PGLoad.h
//  pgHook
//
//  Created by lixiaoqing on 2021/11/8.
//

#import <Foundation/Foundation.h>

@class PGMeasureDesc;

NS_ASSUME_NONNULL_BEGIN

@interface PGLoadInfo : NSObject
@property (copy, nonatomic, readonly) NSString *clsname;
@property (copy, nonatomic, readonly) NSString *catname;
@property (assign, nonatomic, readonly) uint64_t start;//us
@property (assign, nonatomic, readonly) uint64_t end;
@property (assign, nonatomic, readonly) uint64_t duration;
@property (assign, nonatomic, readonly) mach_port_t tid;

@end

@interface PGLoadInfoWrapper : NSObject
@property (assign, nonatomic, readonly) Class cls;
@property (copy, nonatomic, readonly) NSArray <PGLoadInfo *> *infos;
@end

@interface PGLoadManager : NSObject

+ (instancetype)defaultManager;

- (NSArray<PGMeasureDesc *> *)getLoadInfo;

- (void)measureLoad;

@property (assign, nonatomic) uint64_t beginTime;

@property (assign, nonatomic) uint64_t endTime;

@end


NS_ASSUME_NONNULL_END
