#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "JDTOpenUDIDModule-umbrella.h"
#import "OpenUDID.h"

FOUNDATION_EXPORT double JDTOpenUDIDModuleVersionNumber;
FOUNDATION_EXPORT const unsigned char JDTOpenUDIDModuleVersionString[];

