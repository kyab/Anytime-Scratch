//
//  DJFilter.m
//  Anytime Scratch
//
//  Created by kyab on 2020/08/11.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "DJFilter.h"
#include <math.h>

@implementation DJFilter

-(id)init;
{
    self = [super init];
    _lpf = [[LPF_IIR alloc] init];
    _hpf = [[HPF_IIR alloc] init];

    [self setFilterValue: 0.0];
    return self;
}

-(void)setFilterValue:(float)v{
    if (v < 0){
        //LPF On
        [_hpf setCutOffFrequency:50.0];
        
        v = 1.0+v;
        float c = log10(22050);
        float fc = pow(10, v*c) + 50;
        NSLog(@"fc = %f", fc);
        [_lpf setCutOffFrequency:fc];
    }else{
        [_lpf setCutOffFrequency:22000.0];
        
        float c = log10(11025);
        float fc = pow(10,v*c);
        NSLog(@"fc = %f", fc);
        [_hpf setCutOffFrequency:fc];
    }
}

-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum{
    [_lpf processFromLeft:left right:right samples:sampleNum];
    [_hpf processFromLeft:left right:right samples:sampleNum];
}

@end
