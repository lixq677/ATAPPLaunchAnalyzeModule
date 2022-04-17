//
//  EXpgViewController.m
//  pgAPPLaunchCheckerModule
//
//  Created by steven on 02/13/2017.
//  Copyright (c) 2017 steven. All rights reserved.
//

#import "EXpgViewController.h"

@interface EXpgViewController ()

@end

@implementation EXpgViewController

+ (void)load {
    for (NSInteger index = 0; index < 1000000; index++) {
        NSDate *date = [NSDate date];
    }
    NSLog(@"EXpgViewController+load");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self test];
    });
    [self test];
    self.view.backgroundColor = UIColor.redColor;
}

- (void)test {
    for (NSInteger index = 0; index < 2000000; index++) {
        NSDate *date = [NSDate date];
    }
    [self test2];
}

- (void)test2 {
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
