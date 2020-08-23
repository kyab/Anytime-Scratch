//
//  LPF_FIR.h
//  Anytime Scratch
//
//  Created by kyab on 2020/08/07.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RingBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface LPF_FIR : NSObject{
    RingBuffer *_ring;
}

-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;

@end

NS_ASSUME_NONNULL_END
