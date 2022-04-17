//
//  PGMsgTraceCore.h
//  pgHook
//
//  Created by lixiaoqing on 2021/11/24.
//

#ifndef PGMsgTraceCore_h
#define PGMsgTraceCore_h

#include <stdio.h>
#include <objc/objc.h>
#include <vector>
#include <set>
#include <pthread.h>

using namespace::std;

struct PGCallInfo{
    __unsafe_unretained Class cls;
    SEL sel;
    uint64_t duration; // us (1/1000 ms)
    uint64_t ts;
    int depth;
    mach_port_t tid;
    bool is_class_method;//是否类方法
    bool is_main_thread;//是否主线程调用
    bool isload;//是否是load 方法
    PGCallInfo(){}
    PGCallInfo(const PGCallInfo &info){
        this->cls = info.cls;
        this->sel = info.sel;
        this->duration = info.duration;
        this->ts = info.ts;
        this->depth = info.depth;
        this->tid = info.tid;
        this->is_class_method = info.is_class_method;
        this->is_main_thread = info.is_main_thread;
        this->isload = info.isload;
    }
    
};

struct PGOrderInfo{
    __unsafe_unretained Class cls;
    bool isload;
    SEL sel;
    bool is_class_method;//是否类方法
    PGOrderInfo(){}
    PGOrderInfo(const PGOrderInfo &info){
        this->cls = info.cls;
        this->sel = info.sel;
        this->is_class_method = info.is_class_method;
        this->isload = info.isload;
    }
};


class PGMSGTraceImpl;

class PGMSGTrace{
public:
    /*开始统计*/
    static void start();
    
    /*结束统计,销毁数据，释放内存*/
    static void stop();
    
    /*停止统计orderFile 数据*/
    static void stopOrderFile();
    
    /*输出统计数据*/
    static void flush();
    
    /*清除统计数据*/
    static void clearData();
    
    /*设置统计最小时长，函数耗时低于此时长统计，默认1ms*/
    static void configMinTime(uint64_t us);
    
    /*函数最大深度，默认是三级调用，高于三级不统计*/
    static void configMaxDepth(int depth);

    /*是否只统计主线程函数*/
    static void configOnlyMainThread(bool only);
    
    static void configSupportOutputOrderFile(bool support);
    
    /*白名单，只有加入白名单的类函数成员函数统计*/
    static void addWhiteList(Class cls);
    
    static void register_callback_funcInfo(void (*callback)(vector<PGCallInfo> *callInfos,bool finish));
    static void register_callback_orderInfo(void (*callback)(vector<PGOrderInfo> *orderInfo,bool finish));
    
    PGMSGTrace();
    ~PGMSGTrace();
    
    friend inline void cpp_hook_objc_msgSend_before(id self, SEL _cmd, uintptr_t lr);
    
    friend  inline uintptr_t cpp_hook_objc_msgSend_after(BOOL is_objc_msgSendSuper);
    
private:
    static PGMSGTraceImpl *share();
};


#endif /* PGMsgTraceCore_h */
