//
//  EXpgTest.m
//  pgAPPLaunchCheckerModule_Example
//
//  Created by hexiao on 2021/11/26.
//  Copyright © 2021 何骁. All rights reserved.
//

#import "EXpgTest.h"

@implementation EXpgTest

+ (void)load {
    NSLog(@"EXpgTest+load");
    [self test];
}

+ (void)test {
    for (NSInteger index = 0; index < 3000000; index++) {
        NSDate *date = [NSDate date];
    }
}

@end
