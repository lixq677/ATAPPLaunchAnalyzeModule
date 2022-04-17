//
//  PGMsgTraceCore.c
//  pgHook
//
//  Created by lixiaoqing on 2021/11/24.
//

#include "PGMsgTraceCore.hpp"
#import "fishhook.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <sys/sysctl.h>
#include <sstream>

#ifdef __cplusplus
extern "C"
{
#endif

uint64_t cur_us();

#ifdef __cplusplus
}
#endif


typedef struct {
    id self; //通过 object_getClass 能够得到 Class 再通过 NSStringFromClass 能够得到类名
    Class cls;
    SEL cmd; //通过 NSStringFromSelector 方法能够得到方法名
    uint64_t time; //us
    uintptr_t lr; // link register
    bool check = false;
    bool isload = false;//是否load方法
    bool isInload = false;//是否load调用的方法
} PGCallRecord;


#ifdef __aarch64__

//#ifdef __cplusplus
//extern "C"
//{
//#endif
//
//    __unused static id (*orig_objc_msgSend)(id, SEL, ...);
//
//    static void hook_Objc_msgSend();
//
//    //replacement objc_msgSend (arm64)
//    // https://blog.nelhage.com/2010/10/amd64-and-va_arg/
//    // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0055b/IHI0055B_aapcs64.pdf
//    // https://developer.apple.com/library/ios/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
//    #define call(b, value) \
//    __asm volatile ("stp x8, x9, [sp, #-16]!\n"); \
//    __asm volatile ("mov x12, %0\n" :: "r"(value)); \
//    __asm volatile ("ldp x8, x9, [sp], #16\n"); \
//    __asm volatile (#b " x12\n");
//
//    #define save() \
//    __asm volatile ( \
//    "stp x8, x9, [sp, #-16]!\n" \
//    "stp x6, x7, [sp, #-16]!\n" \
//    "stp x4, x5, [sp, #-16]!\n" \
//    "stp x2, x3, [sp, #-16]!\n" \
//    "stp x0, x1, [sp, #-16]!\n");
//
//    #define load() \
//    __asm volatile ( \
//    "ldp x0, x1, [sp], #16\n" \
//    "ldp x2, x3, [sp], #16\n" \
//    "ldp x4, x5, [sp], #16\n" \
//    "ldp x6, x7, [sp], #16\n" \
//    "ldp x8, x9, [sp], #16\n" );
//
//    #define link(b, value) \
//    __asm volatile ("stp x8, lr, [sp, #-16]!\n"); \
//    __asm volatile ("sub sp, sp, #16\n"); \
//    call(b, value); \
//    __asm volatile ("add sp, sp, #16\n"); \
//    __asm volatile ("ldp x8, lr, [sp], #16\n");
//
//    #define ret() __asm volatile ("ret\n");
//
//    __attribute__((__naked__))
//    static void hook_Objc_msgSend() {
//        // Save parameters.
//        save()
//
//        __asm volatile ("mov x2, lr\n");
//        __asm volatile ("mov x3, x4\n");
//
//        // Call our before_objc_msgSend.
//        call(blr, &before_objc_msgSend)
//
//        // Load parameters.
//        load()
//
//        // Call through to the original objc_msgSend.
//        call(blr, orig_objc_msgSend)
//
//        // Save original objc_msgSend return value.
//        save()
//
//        // Call our after_objc_msgSend.
//        call(blr, &after_objc_msgSend)
//
//        // restore lr
//        __asm volatile ("mov lr, x0\n");
//
//        // Load original objc_msgSend return value.
//        load()
//
//        // return
//        ret()
//    }
//
//#ifdef __cplusplus
//}
//#endif

#ifdef __cplusplus
extern "C"
{
#endif
extern void hook_msgSend(void);
extern void hook_msgSendSuper2(void);

void (*orgin_objc_msgSend)(void);
void (*orgin_objc_msgSendSuper2)(void);

#ifdef __cplusplus
}
#endif


static pthread_key_t thread_key;

class PGMSGTraceImpl{
public:
    bool _call_record_enabled = true;
private:
    int max_call_depth = 3;
    uint64_t min_time_cost = 1000;
    bool only_main_thread = true;
    bool collection_orderfile = false;
    /*回调，当callInfos 满了后或主动要求输出时，进行回调*/
    static void (*func_callback)(vector<PGCallInfo> *callInfos,bool finish);
    static void (*orderfile_callback)(vector<PGOrderInfo> *orderFiles,bool finish);
    
    vector<PGCallInfo> *callInfos = nullptr;
    
    vector<PGOrderInfo> *orderFileInfos = nullptr;
    
    set<Class> *whitelist = new set<Class>();
    
    friend PGMSGTrace;
    
    friend  inline void cpp_hook_objc_msgSend_before(id self, SEL _cmd, uintptr_t lr);
    friend  inline uintptr_t cpp_hook_objc_msgSend_after(BOOL is_objc_msgSendSuper);
    
    static void release_thread_call_stack(void *ptr) {
        vector<PGCallRecord> *vec = (vector<PGCallRecord> *)ptr;
        if (!vec) return;
        vec->clear();
        delete vec;
    }
    
    static inline vector<PGCallRecord> *get_thread_call_stack() {
        vector<PGCallRecord> *vec = (vector<PGCallRecord> *)pthread_getspecific(thread_key);
        if (vec == nullptr) {
            vec = new vector<PGCallRecord>();
            pthread_setspecific(thread_key, vec);
        }
        return vec;
    }
    
    ~PGMSGTraceImpl(){
        delete callInfos;
        delete orderFileInfos;
        delete whitelist;
    }
    
    vector<PGCallInfo> *getCallInfosVector(){
        if (callInfos == nullptr) {
            callInfos =  new vector<PGCallInfo>();
            callInfos->reserve(400000);
        }else{
            if(callInfos->size() > 390000){
                flush();
            }
        }
        return  callInfos;
    }
    
    struct Args{
        void *data;
        bool finish;
    };
    
    
    vector<PGOrderInfo> *getOrderInfosVector(){
        if (orderFileInfos == nullptr) {
            orderFileInfos =  new vector<PGOrderInfo>();
            orderFileInfos->reserve(400000);
        }else{
            if(orderFileInfos->size() > 390000){
                vector<PGOrderInfo> *t = orderFileInfos;
                this->orderFileInfos =  new vector<PGOrderInfo>();
                this->orderFileInfos->reserve(400000);
                
                struct Args *args = new struct Args();
                args->data = t;
                args->finish = false;
                pthread_t ntid;
                pthread_create(&ntid, NULL, x_orderfile_callback, (void *)args);
            }
        }
        return  orderFileInfos;
    }
    
    static void *x_func_callback(void *obj){
        struct Args *args = (struct Args *)obj;
        if (func_callback) {
            func_callback((vector<PGCallInfo> *)args->data,args->finish);
        }
        delete (vector<PGCallInfo> *)args->data;
        delete args;
        return NULL;
    }
    
    static void *x_orderfile_callback(void *obj){
        struct Args *args = (struct Args *)obj;
        if (orderfile_callback) {
            orderfile_callback((vector<PGOrderInfo> *)args->data,args->finish);
        }
        delete (vector<PGOrderInfo> *)args->data;
        delete args;
        return NULL;
    }
    
    void start(){
        _call_record_enabled = true;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            pthread_key_create(&thread_key, &release_thread_call_stack);
            struct rebinding rebindObjc_msgSend;
            rebindObjc_msgSend.name = "objc_msgSend";
            rebindObjc_msgSend.replacement = (void *)hook_msgSend;
            rebindObjc_msgSend.replaced = (void **)&orgin_objc_msgSend;
            
//            struct rebinding rebindObjc_msgSendSuper2;
//            rebindObjc_msgSendSuper2.name = "objc_msgSendSuper2";
//            rebindObjc_msgSendSuper2.replacement = (void *)hook_msgSendSuper2;
//            rebindObjc_msgSendSuper2.replaced = (void **)&orgin_objc_msgSendSuper2;
//            struct rebinding rebs[2] = {rebindObjc_msgSend, rebindObjc_msgSendSuper2};
            struct rebinding rebs[1] = {rebindObjc_msgSend};
            rebind_symbols(rebs, 1);
        });
    }
    
    
    void stop(){
        _call_record_enabled = false;
        if (this->callInfos != nullptr){
            vector<PGCallInfo> *t = callInfos;
            callInfos = nullptr;
            
            struct Args *args = new struct Args();
            args->data = t;
            args->finish = true;
            pthread_t ntid;
            pthread_create(&ntid, NULL, x_func_callback, (void *)args);
        }
        
        if (this->orderFileInfos != nullptr) {
            stopOrderFile();
        }
    }
    
    void flush(){
        if (callInfos != nullptr){
            vector<PGCallInfo> *t = callInfos;
            this->callInfos =  new vector<PGCallInfo>();
            this->callInfos->reserve(400000);
            struct Args *args = new struct Args();
            args->data = t;
            args->finish = false;
            pthread_t ntid;
            pthread_create(&ntid, NULL, x_func_callback, (void *)args);
        }
    }
    
    
    void stopOrderFile(){
        if(collection_orderfile){
            collection_orderfile = false;
            vector<PGOrderInfo> *t = orderFileInfos;
            orderFileInfos = nullptr;
            
            struct Args *args = new struct Args();
            args->data = t;
            args->finish = true;
            pthread_t ntid;
            pthread_create(&ntid, NULL, x_orderfile_callback, (void *)args);
        }
    }
    
    
    void clearData(){
        if (this->callInfos != nullptr){
            this->callInfos->clear();
        }
        
        if (this->orderFileInfos != nullptr) {
            this->orderFileInfos->clear();
        }
    }
    
    inline void push_call_record(id _self, Class _cls, SEL _cmd, uintptr_t lr) {
        vector<PGCallRecord> *records = get_thread_call_stack();
        PGCallRecord record;
        record.lr = lr;
        if (_call_record_enabled && (!only_main_thread || (pthread_main_np()  && only_main_thread))){
            record.self = _self;
            record.cls = _cls;
            record.cmd = _cmd;
            record.check = true;//whitelist->count(_cls);
            const char *name = sel_getName(record.cmd);
            if (records->size() == 0 && !strncmp(name, "_lh_hooking_load", strlen("_lh_hooking_load"))) {
                record.isload = true;
            }
            if(records->size()){
                PGCallRecord lastRecord = records->back();
//                if (false == lastRecord.check) {//未加入白名单的类调用了加入白名单的类或对象方法仍过滤
//                    record.check = false;//
//                }
                record.isInload = lastRecord.isInload || lastRecord.isload;//标记load 调用的方法
            }
            record.time = cur_us();
        }
        records->push_back(record);
    }

    inline uintptr_t pop_call_record(bool is_objc_msgSendSuper) {
        vector<PGCallRecord> *records = get_thread_call_stack();
        PGCallRecord record = records->back();
        if(_call_record_enabled){
            bool is_class_method = class_isMetaClass(record.cls);
            Class cls;
            if (is_class_method) {
                if(is_objc_msgSendSuper){
                    cls = class_getSuperclass((Class)record.self);
                }else{
                    cls = (Class)record.self;
                }
            }else{
                if(is_objc_msgSendSuper){
                    cls = class_getSuperclass(record.cls);
                }else{
                    cls = record.cls;
                }
            }
            if (record.check && (!only_main_thread || (pthread_main_np()  && only_main_thread))){
                uint64_t cost = cur_us() - record.time;
                if (cost > min_time_cost && records->size() <= max_call_depth){
                    struct PGCallInfo info;
                    info.is_class_method = is_class_method;
                    info.cls = cls;
                    info.depth = (int)records->size() - 1;
                    info.duration = cost;
                    info.is_main_thread = pthread_main_np();
                    info.sel = record.cmd;
                    info.ts = record.time;
                    info.tid = pthread_mach_thread_np(pthread_self());
                    info.isload = record.isload;
                    vector<PGCallInfo> *xcallInfos = getCallInfosVector();
                    xcallInfos->push_back(info);
                }
            }
            if (collection_orderfile) {
                if(whitelist->count(cls)){
                    struct PGOrderInfo orderInfo;
                    orderInfo.isload = record.isload;
                    orderInfo.cls = cls;
                    orderInfo.sel = record.cmd;
                    orderInfo.is_class_method = is_class_method;
                    vector<PGOrderInfo> *xorderInos = getOrderInfosVector();
                    xorderInos->push_back(orderInfo);
                }
            }
        }
        records->pop_back();
        return  record.lr;
    }
};

/*类成员变量进行初始化*/
void (*PGMSGTraceImpl::func_callback)(vector<PGCallInfo> *callInfos,bool finish) = NULL;

void (*PGMSGTraceImpl::orderfile_callback)(vector<PGOrderInfo> *orderFiles,bool finish);

 inline void cpp_hook_objc_msgSend_before(id self, SEL _cmd, uintptr_t lr) {
    PGMSGTrace::share()->push_call_record(self, object_getClass(self), _cmd, lr);
}

inline uintptr_t cpp_hook_objc_msgSend_after(BOOL is_objc_msgSendSuper) {
    return PGMSGTrace::share()->pop_call_record(is_objc_msgSendSuper);
}

#ifdef __cplusplus
extern "C"
{
#endif

void hook_objc_msgSend_before(id self, SEL _cmd, uintptr_t lr) {
    cpp_hook_objc_msgSend_before(self, _cmd, lr);
}

uintptr_t hook_objc_msgSend_after(BOOL is_objc_msgSendSuper) {
    return cpp_hook_objc_msgSend_after(is_objc_msgSendSuper);
}

#ifdef __cplusplus
}
#endif

void PGMSGTrace::start(){
    share()->start();
}

void PGMSGTrace::flush(){
    share()->flush();
}

void PGMSGTrace::stop(){
    share()->stop();
}

void PGMSGTrace::stopOrderFile(){
    share()->stopOrderFile();
}

void PGMSGTrace::clearData(){
    share()->clearData();
    
}

void PGMSGTrace::configMinTime(uint64_t us){
    share()->min_time_cost = us;
}

void PGMSGTrace::configMaxDepth(int depth){
    share()->max_call_depth = depth;
}

void PGMSGTrace::configOnlyMainThread(bool only){
    share()->only_main_thread = only;
}

void PGMSGTrace::configSupportOutputOrderFile(bool support){
    share()->collection_orderfile = support;
}


void PGMSGTrace::register_callback_funcInfo(void (*callback)(vector<PGCallInfo> *callInfos,bool finish)){
    
    share()->func_callback = callback;
}

void PGMSGTrace::register_callback_orderInfo(void (*callback)(vector<PGOrderInfo> *callInfos,bool finish)){
    share()->orderfile_callback = callback;
}

PGMSGTraceImpl *PGMSGTrace::share(){
    static PGMSGTraceImpl *impl = nullptr;
    if (impl == nullptr) {
        impl = new PGMSGTraceImpl();
    }
    return impl;
}

void PGMSGTrace::addWhiteList(Class cls){
    share()->whitelist->insert(cls);
}

#else

void PGMSGTrace::start(){
}

void PGMSGTrace::flush(){
}

void PGMSGTrace::stop(){
}

void PGMSGTrace::stopOrderFile(){
    
}

void PGMSGTrace::clearData(){
    
}

void PGMSGTrace::configMinTime(uint64_t us){
    
}

void PGMSGTrace::configMaxDepth(int depth){

}

void PGMSGTrace::configOnlyMainThread(bool only){
    
}

void PGMSGTrace::configSupportOutputOrderFile(bool support){
    
}


PGMSGTraceImpl *PGMSGTrace::share(){
    return  nullptr;
}

void PGMSGTrace::addWhiteList(Class cls){
    
}

void PGMSGTrace::register_callback_funcInfo(void (*callback)(vector<PGCallInfo> *callInfos,bool finish)){
    
}
void PGMSGTrace::register_callback_orderInfo(void (*callback)(vector<PGOrderInfo> *callInfos,bool finish)){
    
}

#endif








