//
//  3BandEq.h
//  Anytime Scratch
//
//  Created by kyab on 2020/08/08.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RingBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface LowShelvingFilter : NSObject{
    RingBuffer *_ringPre;
    RingBuffer *_ringPost;
    
    float _g;
}
-(void)setGain:(float)g;
-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;
@end


@interface PeakingFilter : NSObject{
    RingBuffer *_ringPre;
    RingBuffer *_ringPost;
    
    float _g;
}
-(void)setGain:(float)g;
-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;
@end

@interface HighShelvingFilter : NSObject{
    RingBuffer *_ringPre;
    RingBuffer *_ringPost;
    
    float _g;
}
-(void)setGain:(float)g;
-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;
@end


@interface ThreeBandEq : NSObject{
    LowShelvingFilter *_lowShelving;
    PeakingFilter *_peakShelving;
    HighShelvingFilter *_highShelving;
}

-(void)setGainLow:(float)g;
-(void)setGainMid:(float)g;
-(void)setGainHigh:(float)g;


-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum;

@end

NS_ASSUME_NONNULL_END
