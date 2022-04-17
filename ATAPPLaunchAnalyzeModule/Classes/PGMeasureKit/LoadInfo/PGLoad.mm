//
//  PGLoad.m
//  pgHook
//
//  Created by lixiaoqing on 2021/11/8.
//

#import "PGLoad.h"
#import <string>
#import <vector>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <mach-o/getsect.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <sys/time.h>
#import "PGMeasureDesc.h"
#include <pthread.h>
#import <sys/sysctl.h>

using namespace std;

/*以下结构体皆为私有结构体，来自runtime 源码，给runtime 相应的结构体改个名字而已*/
struct pg_method_t {
    SEL name;
    const char *types;
    IMP imp;
};

struct pg_method_list_t {
    uint32_t entsizeAndFlags;
    uint32_t count;
    struct pg_method_t first;
};

struct pg_category_t {
    const char *name;
    Class cls;
    struct pg_method_list_t *instanceMethods;
    struct pg_method_list_t *classMethods;
};

struct pg_protocol_list {
    struct objc_protocol_list * _Nullable next;
    long count;
    __unsafe_unretained Protocol * _Nullable list[1];
};

/**********
 结构体中获取相应属性方法
 *********/

/*通过分类获取类*/
static Class cat_getClass(Category cat) {
    return ((struct pg_category_t *)cat)->cls;
}

/*获取分类名称*/
static const char *cat_getName(Category cat) {
    return ((struct pg_category_t *)cat)->name;
}


/*获取分类中的load 方法*/
static IMP cat_getLoadMethodImp(Category cat) {
    struct pg_method_list_t *list_info = ((struct pg_category_t *)cat)->classMethods;
    if (!list_info) return NULL;
    
    struct pg_method_t *method_list = &list_info->first;
    uint32_t count = list_info->count;
    for (int i = 0; i < count; i++) {
        struct pg_method_t method =  method_list[i];
        const char *name = sel_getName(method.name);
        if (0 == strcmp(name, "load")) {
            return method.imp;
        }
    }
    return nil;
}


@interface PGLoadInfo (){
    @package
    SEL _nSEL;
    IMP _oIMP;
    uint64_t _start;
    uint64_t _end;
    mach_port_t _tid;
}

- (instancetype)initWithClass:(Class)cls;

- (instancetype)initWithCategory:(Category)cat;

@end

@implementation PGLoadInfo

- (instancetype)initWithClass:(Class)cls {
    if (!cls) return nil;
    if (self = [super init]) {
        _clsname = [NSString stringWithCString:object_getClassName(cls) encoding:NSUTF8StringEncoding];
    }
    return self;
}

- (instancetype)initWithCategory:(Category)cat {
    if (!cat) return nil;
    Class cls = cat_getClass(cat);
    if (self = [self initWithClass:cls]) {
        _catname = [NSString stringWithCString:cat_getName(cat) encoding:NSUTF8StringEncoding];
        _oIMP = cat_getLoadMethodImp(cat);
    }
    return self;
}

- (uint64_t)duration {
    return _end - _start;
}

//- (NSString *)description {
//    if (_catname) {
//        return [NSString stringWithFormat:@"%@(%@) duration: %f milliseconds", _clsname, _catname, (_end - _start) * 1000];
//    }else{
//        return [NSString stringWithFormat:@"%@ duration: %f milliseconds", _clsname, (_end - _start) * 1000];
//    }
//}
@end


@interface PGLoadInfoWrapper (){
    @package
    NSMutableDictionary <NSNumber *, PGLoadInfo *> *_infoMap;
}
- (instancetype)initWithClass:(Class)cls;
- (void)addLoadInfo:(PGLoadInfo *)info;
- (PGLoadInfo *)findLoadInfoByImp:(IMP)imp;
- (PGLoadInfo *)findClassLoadInfo;

@end


@implementation PGLoadInfoWrapper
- (instancetype)initWithClass:(Class)cls {
    if (self = [super init]) {
        _infoMap = [NSMutableDictionary dictionary];
        _cls = cls;
    }
    return self;
}

- (void)addLoadInfo:(PGLoadInfo *)info {
    _infoMap[@((uintptr_t)info->_oIMP)] = info;
}

- (PGLoadInfo *)findLoadInfoByImp:(IMP)imp {
    return _infoMap[@((uintptr_t)imp)];
}

- (PGLoadInfo *)findClassLoadInfo {
    for (PGLoadInfo *info in _infoMap.allValues) {
        if (!info.catname) {
            return info;
        }
    }
    return nil;
}

- (NSArray<PGLoadInfo *> *)infos {
    return _infoMap.allValues;
}

- (NSString *)description {
    NSMutableString *desc = [NSMutableString stringWithFormat:@"类名：%@\n",NSStringFromClass(self.cls)];
    [self.infos enumerateObjectsUsingBlock:^(PGLoadInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [desc appendFormat:@"%@\n",obj.description];
    }];
    
    return desc;
}

@end





#if defined(__LP64__)


typedef struct mach_header_64 mach_header_t;

extern uint8_t *getsectiondata(
    const struct mach_header_64 *mhp,
    const char *segname,
    const char *sectname,
    unsigned long *size);

#else

typedef struct mach_header mach_header_t;
extern uint8_t *getsectiondata(
    const struct mach_header *mhp,
    const char *segname,
    const char *sectname,
    unsigned long *size);

#endif

typedef struct classref * classref_t;

static Class remapClass(classref_t cls){
    NSString *clsName = NSStringFromClass((__bridge Class)cls);
    if ([clsName containsString:@"__ARCLite__"]) {
        return nil;
    }
    return CFBridgingRelease(cls);
}

template <typename T>
T* getDataSection(const mach_header_t *mhdr, const char *sectname,
                  size_t *outBytes, size_t *outCount)
{
    unsigned long byteCount = 0;
    
    uintptr_t* data =
    (uintptr_t *)getsectiondata(mhdr, "__DATA", sectname, &byteCount);
    if (!data) {
        data = (uintptr_t *)getsectiondata(mhdr, "__DATA_CONST", sectname, &byteCount);
    }
    if (!data) {
        data = (uintptr_t *)getsectiondata(mhdr, "__DATA_DIRTY", sectname, &byteCount);
    }
    if (outBytes) *outBytes = byteCount;
    if (outCount) *outCount = byteCount / sizeof(T);
    return (T *)data;
}

static bool shouldRejectClass(NSString *name) {
    if (!name) return true;
    NSArray *rejectClses = @[@"__ARCLite__"];
    return [rejectClses containsObject:name];
}

static NSArray <PGLoadInfo *> *getNoLazyArray(const mach_header_t *mhdr) {
    NSMutableArray *noLazyArray = [NSMutableArray new];
    size_t bytes = 0;
    size_t count = 0;
    Category *cates = getDataSection<Category>(mhdr,  "__objc_nlcatlist", &bytes, &count);
    for (unsigned int i = 0; i < count; i++) {
        PGLoadInfo *info = [[PGLoadInfo alloc] initWithCategory:cates[i]];
        if (!shouldRejectClass(info.clsname)) [noLazyArray addObject:info];
    }
    
    classref_t const *clses = getDataSection<classref_t const>(mhdr, "__objc_nlclslist", &bytes, &count);
    for (unsigned int i = 0; i < count; i++) {
        Class  cls = remapClass(clses[i]);
        if (cls) {
            PGLoadInfo *info = [[PGLoadInfo alloc] initWithClass:cls];
            [noLazyArray addObject:info];
        }
    }
    return noLazyArray;
}




static bool isSelfDefinedImage(const char *imageName){
    return
    !strstr(imageName, "/Xcode.app/") &&
    !strstr(imageName, "/Library/PrivateFrameworks/") &&
    !strstr(imageName, "/System/Library/") &&
    !strstr(imageName, "/usr/lib/");
}

static const mach_header_t **copyAllSelfDefinedImageHeader(uint *outCount){
    unsigned int imageCount = _dyld_image_count();
    unsigned int count = 0;
    const mach_header_t **mhdrList = NULL;
    if (imageCount > 0) {
        mhdrList = (const mach_header_t **)malloc(sizeof(mach_header_t *) * imageCount);
        for (unsigned int i = 0; i < imageCount; i++) {
            const char *imageName = _dyld_get_image_name(i);
            if (isSelfDefinedImage(imageName)) {
                const mach_header_t  *mhdr = (const mach_header_t *)_dyld_get_image_header(i);
                mhdrList[count++] = mhdr;
            }
        }
        mhdrList[count] = NULL;
    }
    if (outCount) *outCount = count;
    return mhdrList;
}


static NSDictionary <NSString *, PGLoadInfoWrapper *> *prepareMeasureForMhdrList(const mach_header_t **mhdrList, unsigned int  count) {
    NSMutableDictionary <NSString *, PGLoadInfoWrapper *> *wrapperMap = [NSMutableDictionary dictionary];
    for (unsigned int i = 0; i < count; i++) {
        const mach_header_t *mhdr = mhdrList[i];
        NSArray <PGLoadInfo *> *infos = getNoLazyArray(mhdr);
        for (PGLoadInfo *info in infos) {
            PGLoadInfoWrapper *infoWrapper = wrapperMap[info.clsname];
            if (!infoWrapper) {
                Class cls = objc_getClass([info.clsname cStringUsingEncoding:NSUTF8StringEncoding]);
                infoWrapper = [[PGLoadInfoWrapper alloc] initWithClass:cls];
                wrapperMap[info.clsname] = infoWrapper;
            }
            [infoWrapper addLoadInfo:info];
        }
    }
    return wrapperMap;
}

static SEL getRandomLoadSelector(void) {
    return NSSelectorFromString([NSString stringWithFormat:@"_lh_hooking_load_%x", arc4random()]);
}


#ifdef __cplusplus
extern "C"
{
#endif

uint64_t cur_us();

#ifdef __cplusplus
}
#endif


static void swizzleLoadMethod(Class cls, Method method, PGLoadInfo *info) {
retry:
    do {
        SEL hookSel = getRandomLoadSelector();
        Class metaCls = object_getClass(cls);
        IMP hookImp = imp_implementationWithBlock(^ {
            info->_start = cur_us();
            if ([[PGLoadManager defaultManager] beginTime] <= 0) {
                [[PGLoadManager defaultManager] setBeginTime:info->_start];
            }
            ((void (*)(Class, SEL))objc_msgSend)(cls, hookSel);
            info->_end = cur_us();
//            info->_tid = pthread_mach_thread_np(pthread_self());
            uint64_t time = MAX([[PGLoadManager defaultManager] endTime], info->_end);
            [[PGLoadManager defaultManager] setEndTime:time];
        });
        
        BOOL didAddMethod = class_addMethod(metaCls, hookSel, hookImp, method_getTypeEncoding(method));
        if (!didAddMethod) goto retry;
        
        info->_nSEL = hookSel;
        Method hookMethod = class_getInstanceMethod(metaCls, hookSel);
        method_exchangeImplementations(method, hookMethod);
    } while(0);
}

static void hookAllLoadMethods(PGLoadInfoWrapper *infoWrapper) {
    unsigned int count = 0;
    Class metaCls = object_getClass(infoWrapper.cls);
    Method *methodList = class_copyMethodList(metaCls, &count);
    for (unsigned int i = 0; i < count; i++) {
        Method method = methodList[i];
        SEL sel = method_getName(method);
        const char *name = sel_getName(sel);
        if (!strcmp(name, "load")) {
            IMP imp = method_getImplementation(method);
            PGLoadInfo *info = [infoWrapper findLoadInfoByImp:imp];
            if (!info) {
                info = [infoWrapper findClassLoadInfo];
                if (!info) continue;
            }
            
            swizzleLoadMethod(infoWrapper.cls, method, info);
        }
    }
    free(methodList);
}


@interface PGLoadManager ()

@property (nonatomic,strong)NSMutableDictionary<NSString *, PGLoadInfoWrapper *> *loadInfoWrappers;

@end


@implementation PGLoadManager

+ (instancetype)defaultManager{
    static dispatch_once_t once;
    static PGLoadManager *instance;
    dispatch_once(&once, ^{
        instance = [[PGLoadManager alloc] init];
        instance.beginTime = 0;
        instance.endTime = 0;
    });
    return instance;
}


- (void)measureLoad{
    unsigned int count = 0;
    const mach_header_t **mhdrList = copyAllSelfDefinedImageHeader(&count);
    NSDictionary <NSString *, PGLoadInfoWrapper *> *groupedWrapperMap = prepareMeasureForMhdrList(mhdrList, count);
    [[[PGLoadManager defaultManager] loadInfoWrappers] removeAllObjects];
    [[[PGLoadManager defaultManager] loadInfoWrappers] addEntriesFromDictionary:groupedWrapperMap];
    for (NSString *clsname in groupedWrapperMap.allKeys) {
        hookAllLoadMethods(groupedWrapperMap[clsname]);
    }
    free(mhdrList);
}

//- (NSArray<PGMeasureDesc *> *)getLoadInfo{
//    NSMutableArray<PGMeasureDesc *> *descs = [NSMutableArray array];
//    [self.loadInfoWrappers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, PGLoadInfoWrapper * _Nonnull obj, BOOL * _Nonnull stop) {
//        [obj.infos enumerateObjectsUsingBlock:^(PGLoadInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//            PGMeasureDesc *desc = [[PGMeasureDesc alloc] initWithLoadInfo:obj];
//            [descs addObject:desc];
//        }];
//    }];
//    PGMeasureDesc *desc = [[PGMeasureDesc alloc] init];
//    desc.ts =  [[PGLoadManager defaultManager] beginTime];
//    
//    desc.dur = [[PGLoadManager defaultManager] endTime] - [[PGLoadManager defaultManager] beginTime];
//    desc.name = @"T:load total duration";
//    [descs addObject:desc];
//    
//    return descs;
//}

- (NSMutableDictionary<NSString *, PGLoadInfoWrapper *> *)loadInfoWrappers{
    if (!_loadInfoWrappers) {
        _loadInfoWrappers = [NSMutableDictionary dictionary];
    }
    return _loadInfoWrappers;
}

@end

