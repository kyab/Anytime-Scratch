//
//  AppDelegate.h
//  Anytime Scratch
//
//  Created by kyab on 2017/05/29.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>{

    __weak IBOutlet AppController *_controller;
}

@end

