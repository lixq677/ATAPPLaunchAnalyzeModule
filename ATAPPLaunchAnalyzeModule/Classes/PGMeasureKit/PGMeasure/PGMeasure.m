//
//  PGMeasure.m
//  PGMeasureKit
//
//  Created by lixiaoqing on 2021/11/26.
//



#import "PGMeasure.h"
#import "PGLoad.h"
#import "PGMsgTrace.h"
#import "ATAspects.h"
#import "fishhook.h"

#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/ldsyms.h>
#import <objc/message.h>

#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

#import <UIKit/UIKit.h>
#import "YYModel.h"
#import "PGMeasureDesc.h"
#import "LKDBHelper.h"

//static CFTimeInterval to_ms(struct timeval time){
//    return time.tv_sec * 1000 + (NSTimeInterval)time.tv_usec / 1000;
//}

static NSString *const kOrderFileSupport = @"com.ATAPPLaunchAnalyzeModule.OrderFileSupport";

static NSString *const kLaunchAnalyzeEnable = @"com.ATAPPLaunchAnalyzeModule.LaunchAnalyze";

typedef NS_ENUM(NSInteger,ATAPPStatus) {
    ATAPPStatusNone,
    ATAPPStatusStart,
    ATAPPStatusAll
};


/*进程启动时间*/
uint64_t process_start_time(){
    static uint64_t time = 0;
    if (time == 0) {
        struct kinfo_proc kProcInfo;
        int pid = getpid();
        int cmd[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
        size_t size = sizeof(kProcInfo);
        if(sysctl(cmd, sizeof(cmd)/sizeof(int), &kProcInfo, &size, NULL, 0) == 0){
            uint64_t us = kProcInfo.kp_proc.p_un.__p_starttime.tv_sec * 1000 * 1000 + kProcInfo.kp_proc.p_un.__p_starttime.tv_usec;
            time = us;
        } 
    }
    return time;
}

uint64_t cur_us(){
    struct timeval time;
    gettimeofday(&time, NULL);
    return time.tv_sec * 1000 * 1000 + time.tv_usec - process_start_time();
}



@interface PGMeasure ()

@property (nonatomic,assign,readonly)uint64_t loadBeginTime;

@property (nonatomic,assign,readonly)uint64_t loadEndTime;

@property (nonatomic,assign)uint64_t renderEndTime;

@property (nonatomic,assign)uint64_t renderbeginTime;

@property (nonatomic,assign)uint64_t enterMainTime;

@property (nonatomic,strong)NSFileHandle *orderFileHandle;

@end

@implementation PGMeasure

+(id)shareInstance{
    static id instance= nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (uint64_t)startDuration{
    return _renderEndTime;
}

- (uint64_t)loadDuration{
    return self.loadEndTime - self.loadBeginTime;
}

- (uint64_t)premainDuration{
    return _enterMainTime;
}


- (uint64_t)renderDuration{
    if (_renderEndTime == 0) {
        return 0;
    }
    return _renderEndTime - _renderbeginTime;
}

- (uint64_t)launchDuration{
    return _renderEndTime - _enterMainTime;
}


- (uint64_t)loadBeginTime{
    return [[PGLoadManager defaultManager] beginTime];
}

- (uint64_t)loadEndTime{
    return [[PGLoadManager defaultManager] endTime];
}


#if 0
/*生成耗时函数文件*/
- (void)generateFuncTimeCostFile:(NSString *)filePath dataSource:(NSArray<PGMeasureDesc *> *)sources{
    /*过滤数据*/
    NSMutableArray<PGMeasureDesc *> *sourceDescs = [NSMutableArray array];
    [sources enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:@"NSInvocation-invoke"]) {
            return;
        }
        if ([obj.name containsString:@"RTCallSelectorWithArgArray:arg:error:"]) {
            return;
        }
        if ([obj.name isEqualToString:@"JDRouter+openURL:arg:error:completion:"]) {
            return;
        }
        [sourceDescs addObject:obj];
    }];
    
    /*添加 load 方法总耗时*/
    PGMeasureDesc *desc1 = [[PGMeasureDesc alloc] init];
    desc1.name = @"load total duration cost";
    desc1.ts = self.loadBeginTime;
    desc1.dur = self.loadDuration;
    [sourceDescs addObject:desc1];
    
    /*添加premain 总耗时*/
    PGMeasureDesc *desc2 = [[PGMeasureDesc alloc] init];
    desc2.name = @"premain-duration cost";
    desc2.ts =  0;
    desc2.dur = self.premainDuration;
    [sourceDescs addObject:desc2];
        
    /*添加render 总耗时*/
    PGMeasureDesc *desc3 = [[PGMeasureDesc alloc] init];
    desc3.name = @"fisrst page render cost";
    desc3.ts = self.renderbeginTime;
    desc3.dur = self.renderDuration;
    [sourceDescs addObject:desc3];
    
    /*添加render 总耗时*/
    PGMeasureDesc *desc4 = [[PGMeasureDesc alloc] init];
    desc4.name = @"launch cost time";
    desc4.ts = self.enterMainTime;
    desc4.dur = self.launchDuration;
    [sourceDescs addObject:desc4];
    
    
    /*添加render 总耗时*/
    PGMeasureDesc *desc5 = [[PGMeasureDesc alloc] init];
    desc5.name = @"start cost time";
    desc5.ts = 0;
    desc5.dur = self.startDuration;
    [sourceDescs addObject:desc5];
    
    NSString *json = [sourceDescs yy_modelToJSONString];
    if (json) {
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:[json dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
}


/*生成耗时前10的*/
- (void)generateFuncTimeCostMuchTimeFile:(NSString *)filePath dataSource:(NSArray<PGMeasureDesc *> *)sources{
    
    /*获取排在前10的数据及它调用的函数*/
    NSUInteger total = 10;
    NSMutableArray<PGMeasureDesc *> *sourceDescs = [NSMutableArray array];
    [sources enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.depth == 0) {
            [sourceDescs addObject:obj];
        }
    }];
    [sourceDescs sortUsingComparator:^NSComparisonResult(PGMeasureDesc   * _Nonnull obj1, PGMeasureDesc   * _Nonnull obj2) {
        return obj1.dur < obj2.dur;
    }];
    if (sourceDescs.count > total) {
        [sourceDescs removeObjectsInRange:NSMakeRange(total, sourceDescs.count-total)];
    }
    
    NSArray<PGMeasureDesc *> *tmpAry = [sourceDescs copy];
    [tmpAry enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull refobj, NSUInteger idx, BOOL * _Nonnull stop) {
        [sources enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (refobj.tid == obj.tid && refobj.ts <=  obj.ts && obj.ts <= refobj.ts + refobj.dur && obj.depth > 0) {
                [sourceDescs addObject:obj];
            }
        }];
    }];
    
    /*过滤数据*/
    NSMutableArray<PGMeasureDesc *> *xsourceDescs = [NSMutableArray array];
    [sourceDescs enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:@"NSInvocation-invoke"]) {
            return;
        }
        if ([obj.name containsString:@"RTCallSelectorWithArgArray:arg:error:"]) {
            return;
        }
        if ([obj.name isEqualToString:@"JDRouter+openURL:arg:error:completion:"]) {
            return;
        }
        [xsourceDescs addObject:obj];
    }];
    
    NSString *json = [xsourceDescs yy_modelToJSONString];
    if (json) {
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:[json dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
}


- (void)generateFuncOrderFile:(NSString *)filePath{
    NSMutableString *orderFileStr = [NSMutableString string];
    [[[PGMeasure shareInstance] funcsForOrderFile] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [orderFileStr appendFormat:@"%@\n",obj];
    }];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:[orderFileStr dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}


- (void)generateFile{
    
    time_t t = time(NULL);
    const int strlen1 = 50;
    char tmpBuf[strlen1];
    strftime(tmpBuf, strlen1,"%F", localtime(&t));
    NSString *subdir =  [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
    
    strftime(tmpBuf, strlen1,"%X", localtime(&t));
    NSString *fileName = [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
    
    
    /*获取所有数据*/
    NSMutableArray<PGMeasureDesc *> *infoAry = [NSMutableArray array];
    [[[PGMeasure shareInstance] loadInfos] enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [infoAry addObject:obj];
    }];
    
    [[[PGMeasure shareInstance] funcInfos] enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [infoAry addObject:obj];
    }];
    
    NSString *(^generateFilePathBlock)(NSString *dir,NSString *ext) = ^NSString * (NSString *xdir,NSString *ext){
        
        NSString *rootDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"LaunchAnalyze"];
        NSString *dir = [[rootDir stringByAppendingPathComponent:xdir] stringByAppendingPathComponent:subdir];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *file = nil;
        if (ext) {
            file = [fileName stringByAppendingFormat:@"-%@",ext];
        }else{
            file = fileName;
        }
        NSString *filePath = [[dir stringByAppendingPathComponent:file] stringByAppendingPathExtension:@"txt"];
        return filePath;
    };
    
    [self generateFuncTimeCostFile:generateFilePathBlock(@"CostTime",nil) dataSource:infoAry];
    
    [self generateFuncTimeCostMuchTimeFile:generateFilePathBlock(@"CostTime-Large",@"much") dataSource:infoAry];
    
    [self generateFuncOrderFile:generateFilePathBlock(@"OrderFile",@"orderfile")];
    
    //
//    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https:/www.jd.com"]];
//    NSURLSessionUploadTask *task = [NSURLSession.sharedSession uploadTaskWithRequest:request fromFile:[NSURL URLWithString:order_filePath]];
//    [task resume];
    
}

#endif

- (void)_generateOrderFileWithContent:(NSArray<NSString *> *)contents finish:(BOOL)finish{
    if (!self.orderFileHandle) {
        time_t t = time(NULL);
        const int strlen1 = 50;
        char tmpBuf[strlen1];
        strftime(tmpBuf, strlen1,"%F", localtime(&t));
        NSString *subdir =  [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
        
        strftime(tmpBuf, strlen1,"%X", localtime(&t));
        NSString *fileName = [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
        NSString *rootDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"LaunchAnalyze"];
        NSString *dir = [[rootDir stringByAppendingPathComponent:@"OrderFile"] stringByAppendingPathComponent:subdir];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *file = [fileName stringByAppendingPathExtension:@"txt"];
        NSString *filePath = [dir stringByAppendingPathComponent:file];
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        }
        self.orderFileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    [self.orderFileHandle seekToEndOfFile];
    
    NSMutableString *orderFileStr = [NSMutableString string];
    [contents enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [orderFileStr appendFormat:@"%@\n",obj];
    }];
    NSData *data = [orderFileStr dataUsingEncoding:NSUTF8StringEncoding];
    [self.orderFileHandle writeData:data];
    if (finish) {
        [self.orderFileHandle closeFile];
        self.orderFileHandle = nil;
    }
}

- (NSString *)getFilePath:(NSString *)xfile{
    time_t t = time(NULL);
    const int strlen1 = 50;
    char tmpBuf[strlen1];
    strftime(tmpBuf, strlen1,"%F", localtime(&t));
    NSString *subdir =  [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
    
    strftime(tmpBuf, strlen1,"%X", localtime(&t));
    NSString *fileName = [NSString stringWithCString:tmpBuf encoding:NSUTF8StringEncoding];
    NSString *rootDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"LaunchAnalyze"];
    NSString *dir = [[rootDir stringByAppendingPathComponent:xfile] stringByAppendingPathComponent:subdir];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *file = [fileName stringByAppendingPathExtension:@"txt"];
    NSString *filePath = [dir stringByAppendingPathComponent:file];
    return filePath;
}

- (void)generateFile{
    [self generateFile1];
    [self generateFile2];
}

- (void)generateFile1{
    NSArray<PGMeasureDesc *> *sources = [PGMeasureDesc searchWithWhere:nil];
    /*过滤数据*/
    NSMutableArray<PGMeasureDesc *> *sourceDescs = [NSMutableArray arrayWithCapacity:sources.count];
    [sources enumerateObjectsUsingBlock:^(PGMeasureDesc * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:@"NSInvocation-invoke"]) {
            return;
        }
        if ([obj.name containsString:@"RTCallSelectorWithArgArray:arg:error:"]) {
            return;
        }
        if ([obj.name isEqualToString:@"JDRouter+openURL:arg:error:completion:"]) {
            return;
        }
        [sourceDescs addObject:obj];
    }];
    
    /*添加 load 方法总耗时*/
    PGMeasureDesc *desc1 = [[PGMeasureDesc alloc] init];
    desc1.name = @"load total duration cost";
    desc1.ts = self.loadBeginTime;
    desc1.dur = self.loadDuration;
    [sourceDescs addObject:desc1];
    
    /*添加premain 总耗时*/
    PGMeasureDesc *desc2 = [[PGMeasureDesc alloc] init];
    desc2.name = @"premain-duration cost";
    desc2.ts =  0;
    desc2.dur = self.premainDuration;
    [sourceDescs addObject:desc2];
        
    /*添加render 总耗时*/
    PGMeasureDesc *desc3 = [[PGMeasureDesc alloc] init];
    desc3.name = @"fisrst page render cost";
    desc3.ts = self.renderbeginTime;
    desc3.dur = self.renderDuration;
    [sourceDescs addObject:desc3];
    
    /*添加render 总耗时*/
    PGMeasureDesc *desc4 = [[PGMeasureDesc alloc] init];
    desc4.name = @"launch cost time";
    desc4.ts = self.enterMainTime;
    desc4.dur = self.launchDuration;
    [sourceDescs addObject:desc4];
    
    
    /*添加render 总耗时*/
    PGMeasureDesc *desc5 = [[PGMeasureDesc alloc] init];
    desc5.name = @"start cost time";
    desc5.ts = 0;
    desc5.dur = self.startDuration;
    [sourceDescs addObject:desc5];
    
    NSString *json = [sourceDescs yy_modelToJSONString];
    if (json) {
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSString *filePath = [self getFilePath:@"all"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
        }
    }
}

- (void)generateFile2{
    NSArray<PGMeasureDesc *> *sources = [PGMeasureDesc searchWithWhere:@{@"depth":@(0)} orderBy:@"dur desc" offset:0 count:20];
    NSString *json = [sources yy_modelToJSONString];
    if (json) {
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSString *filePath = [self getFilePath:@"largeCost"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
        }
    }
}

@end


static bool isSelfDefinedImage(const char *imageName){
    return
    !strstr(imageName, "/Xcode.app/") &&
    !strstr(imageName, "/Library/PrivateFrameworks/") &&
    !strstr(imageName, "/System/Library/") &&
    !strstr(imageName, "/usr/lib/") &&
    !strstr(imageName, "pgDevToolsModule");
}

typedef NS_ENUM(NSUInteger, HookPosition) {
    HookPositionAfter   = 0,
    HookPositionBefore  = 1,
};



void func(const struct mach_header* mh, intptr_t vmaddr_slide){
    if ([[PGMeasure shareInstance] monitor]) {
        Dl_info  info;
        dladdr(mh, &info);
        if (!isSelfDefinedImage(info.dli_fname)) {//过滤系统类
            return;
        }
        
        Dl_info selfInfo;
        ///_mh_execute_header : mach-o头部的地址
        ///dladdr: 获取app的路径
        dladdr(&_MH_EXECUTE_SYM, &selfInfo);
        if (0 == strcmp(info.dli_fname, selfInfo.dli_fname)) {//过滤当前动态库的类
            return;
        }
        
        unsigned int classCount = 0;
        ///拷贝动态库类列表
        const char  **classes = objc_copyClassNamesForImage(info.dli_fname, &classCount);
        for (int i = 0; i < classCount; i++) {
            Class cls = objc_getClass(classes[i]);
            [PGMsgTrace addWhiteList:cls];
        }
        free(classes);
    }
}


static void hook(void);

static void hookViewController(ATAPPStatus status){
    Class class = objc_getClass([@"PGHomePageViewController" UTF8String]);
    
    [class aspect_hookSelector:@selector(initWithNibName:bundle:) withOptions:ATAspectPositionBefore usingBlock:^(id<ATAspectInfo> aspectInfo) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[PGMeasure shareInstance] setRenderbeginTime:cur_us()];
        });
    }error:nil];
    
    [class aspect_hookSelector:@selector(viewDidAppear:) withOptions:ATAspectPositionBefore usingBlock:^(id<ATAspectInfo> aspectInfo) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[PGMeasure shareInstance] setRenderEndTime:cur_us()];
            [[PGMeasure shareInstance] setMonitor:NO];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [PGMsgTrace stopOrderFile];
                if (status == ATAPPStatusStart) {
                    [PGMsgTrace stop];
                }else{
                    [PGMsgTrace flush];
                }
            });
        });
    }error:nil];
    
    [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ATAspectPositionBefore usingBlock:^(id<ATAspectInfo> aspectInfo) {
       
    }error:nil];
    
    [UIViewController aspect_hookSelector:@selector(viewWillAppear:) withOptions:ATAspectPositionBefore usingBlock:^(id<ATAspectInfo> aspectInfo) {
       
    }error:nil];
    
    [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ATAspectPositionBefore usingBlock:^(id<ATAspectInfo> aspectInfo) {
       
    }error:nil];
}


__attribute__((constructor)) static void PGLoadMeasure_Initializer(void) {
    /*测量初始化开始*/
    ATAPPStatus status = ATAPPStatusStart;//[[NSUserDefaults standardUserDefaults] integerForKey:kLaunchAnalyzeEnable];
    if (status == ATAPPStatusNone) {
        return;
    }
    
    uint64_t begin = cur_us();
    [[PGMeasure shareInstance] setMonitor:YES];
    hook();
    hookViewController(status);
    
    BOOL orderFileSupport = YES;//[[NSUserDefaults standardUserDefaults] boolForKey:kOrderFileSupport];
    
    [[PGLoadManager defaultManager] measureLoad];
    [PGMsgTrace configOnlyMonitorMainThread:NO];
    [PGMsgTrace configMinTime:1000];
    [PGMsgTrace configMaxDepth:20];
    /*支持输出orderFile*/
    [PGMsgTrace configSupportOutputOrderFile:orderFileSupport];
    if (orderFileSupport) {
        _dyld_register_func_for_add_image(func);
        [PGMsgTrace outputOrderFileBlock:^(NSArray<NSString *> * _Nonnull orderFile, BOOL finish) {
            [[PGMeasure shareInstance] _generateOrderFileWithContent:orderFile finish:finish];
        }];
    }
    /*清空当次数据库*/
    [PGMeasureDesc deleteWithWhere:nil];
    [PGMsgTrace outputFuncCallBlock:^(NSArray<PGMeasureDesc *> * _Nonnull measureDescs, BOOL finish) {
        [PGMeasureDesc insertToDBWithArray:measureDescs filter:nil];
        if (finish) {
            [[PGMeasure shareInstance] generateFile];
        }
    }];
    
    [PGMsgTrace start];
    /*测量初始化结束*/
    uint64_t end = cur_us();
    [[PGMeasure shareInstance] setMonitorDuration:end-begin];
}



__unused static int (*orign_UIApplicationMain)(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);

static  int hook_UIApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName){
   [[PGMeasure shareInstance] setEnterMainTime:cur_us()];
    return orign_UIApplicationMain(argc,argv,principalClassName,delegateClassName);
}



static void hook(){
    struct rebinding rebind;
    rebind.name = "UIApplicationMain";
    rebind.replacement = (void *)hook_UIApplicationMain;
    rebind.replaced = (void **)&orign_UIApplicationMain;
    struct rebinding rebs[1] = {rebind};
    rebind_symbols(rebs, 1);
}


