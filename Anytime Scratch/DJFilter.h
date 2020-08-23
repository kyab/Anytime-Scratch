//
//  DJFilter.h
//  Anytime Scratch
//
//  Created by kyab on 2020/08/11.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPF_IIR.h"
#import "HPF_IIR.h"

NS_ASSUME_NONNULL_BEGIN

@interface DJFilter : NSObject{
    LPF_IIR *_lpf;
    HPF_IIR *_hpf;
}

-(void)setFilterValue:(float)v;
-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;


@end

NS_ASSUME_NONNULL_END
