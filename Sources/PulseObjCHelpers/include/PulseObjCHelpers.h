// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PulseObjCExceptionCatcher : NSObject

/// Executes the given block, catching any Objective-C exceptions and
/// converting them to NSError.
+ (BOOL)performAndReturnError:(NSError *_Nullable *_Nullable)error block:(void (NS_NOESCAPE ^)(void))block;

@end

NS_ASSUME_NONNULL_END
