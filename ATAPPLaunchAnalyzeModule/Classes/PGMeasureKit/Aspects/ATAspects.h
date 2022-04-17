//
//  ATAspects.h
//  ATAspects - A delightful, simple library for aspect oriented programming.
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, ATAspectOptions) {
    ATAspectPositionAfter   = 0,            /// Called after the original implementation (default)
    ATAspectPositionInstead = 1,            /// Will replace the original implementation.
    ATAspectPositionBefore  = 2,            /// Called before the original implementation.
    
    ATAspectOptionAutomaticRemoval = 1 << 3 /// Will remove the hook after the first execution.
};

/// Opaque ATAspect Token that allows to deregister the hook.
@protocol ATAspectToken <NSObject>

/// Deregisters an aspect.
/// @return YES if deregistration is successful, otherwise NO.
- (BOOL)remove;

@end

/// The ATAspectInfo protocol is the first parameter of our block syntax.
@protocol ATAspectInfo <NSObject>

/// The instance that is currently hooked.
- (id)instance;

/// The original invocation of the hooked method.
- (NSInvocation *)originalInvocation;

/// All method arguments, boxed. This is lazily evaluated.
- (NSArray *)arguments;

@end

/**
 ATAspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. ATAspects is meant for view/controller code that is not called a 1000 times per second.

 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */
@interface NSObject (ATAspects)

/// Adds a block of code before/instead/after the current `selector` for a specific class.
///
/// @param block ATAspects replicates the type signature of the method being hooked.
/// The first parameter will be `id<ATAspectInfo>`, followed by all parameters of the method.
/// These parameters are optional and will be filled to match the block signature.
/// You can even use an empty block, or one that simple gets `id<ATAspectInfo>`.
///
/// @note Hooking static methods is not supported.
/// @return A token which allows to later deregister the aspect.
+ (id<ATAspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(ATAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

/// Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<ATAspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(ATAspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error;

@end


typedef NS_ENUM(NSUInteger, ATAspectErrorCode) {
    ATAspectErrorSelectorBlacklisted,                   /// Selectors like release, retain, autorelease are blacklisted.
    ATAspectErrorDoesNotRespondToSelector,              /// Selector could not be found.
    ATAspectErrorSelectorDeallocPosition,               /// When hooking dealloc, only ATAspectPositionBefore is allowed.
    ATAspectErrorSelectorAlreadyHookedInClassHierarchy, /// Statically hooking the same method in subclasses is not allowed.
    ATAspectErrorFailedToAllocateClassPair,             /// The runtime failed creating a class pair.
    ATAspectErrorMissingBlockSignature,                 /// The block misses compile time signature info and can't be called.
    ATAspectErrorIncompatibleBlockSignature,            /// The block signature does not match the method or is too large.

    ATAspectErrorRemoveObjectAlreadyDeallocated = 100   /// (for removing) The object hooked is already deallocated.
};

