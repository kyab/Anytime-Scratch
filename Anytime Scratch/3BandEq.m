//
//  3BandEq.m
//  Anytime Scratch
//
//  Created by kyab on 2020/08/08.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "3BandEq.h"
#include <math.h>

void IIR_low_shelving(float fc, float Q, float g, float *a, float *b){
    fc = tan(M_PI*fc)/(2.0*M_PI);
    
    a[0] = 1.0 + 2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc;
    a[1] = (8.0 * M_PI*M_PI*fc*fc-2.0)/a[0];
    a[2] = (1.0 - 2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc)/a[0];
    b[0] = (1.0 + sqrt(1.0+g)*2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc*(1.0+g))/a[0];
    b[1] = (8.0*M_PI*M_PI*fc*fc*(1.0+g) - 2.0) / a[0];
    b[2] = (1.0 -sqrt(1.0+g)*2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc*(1.0+g))/a[0];
    
    a[0] = 1.0;
    
}

void IIR_high_shelving(float fc, float Q, float g, float *a, float *b){
    fc = tan(M_PI*fc)/(2.0*M_PI);
    
    a[0] = 1.0 + 2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc;
    a[1] = (8.0*M_PI*M_PI*fc*fc-2.0)/a[0];
    a[2] = (1.0 - 2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc)/a[0];
    b[0] = ((1.0+g) + sqrt(1.0+g)*2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc)/a[0];
    b[1] = (8.0*M_PI*M_PI*fc*fc - 2.0*(1.0+g))/a[0];
    b[2] = ((1.0+g) - sqrt(1.0+g)*2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc)/a[0];
    
    a[0] = 1.0;
}

void IIR_peaking(float fc, float Q, float g, float *a, float *b){
    fc = tan(M_PI*fc)/(2.0*M_PI);
    
    a[0] = 1.0 + 2.0 * M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc;
    a[1] = (8.0*M_PI*M_PI*fc*fc-2.0)/a[0];
    a[2] = (1.0 - 2.0*M_PI*fc/Q + 4.0*M_PI*M_PI*fc*fc)/a[0];
    b[0] = (1.0 + 2.0*M_PI*fc/Q*(1.0+g) + 4.0*M_PI*M_PI*fc*fc)/a[0];
    b[1] = (8.0*M_PI*M_PI*fc*fc - 2.0)/a[0];
    b[2] = (1.0 - 2.0*M_PI*fc/Q*(1.0+g) + 4.0*M_PI*M_PI*fc*fc)/a[0];
    
    a[0] = 1.0;
}

@implementation LowShelvingFilter

-(id)init;
{
    self = [super init];
    _ringPre = [[RingBuffer alloc] init];
    _ringPost = [[RingBuffer alloc] init];
    
    _g = 0.0;
    return self;
}

-(void)setGain:(float)g{
    _g = g;
}

- (void)processFromLeft:(float *)leftPtr right:(float *)rightPtr samples:(UInt32)sampleNum{

    int fs = 44100;

    float fc = 500.0 / fs;
    float Q = 1.0/sqrt(2.0);
    float g = _g;
    int I = 2;
    int J = 2;

    float a[3];
    float b[3];

    float *leftPre = [_ringPre writePtrLeft];
    float *rightPre = [_ringPre writePtrRight];
    memcpy(leftPre, leftPtr, sizeof(float) * sampleNum);
    memcpy(rightPre, rightPtr, sizeof(float) * sampleNum);

    [_ringPre advanceWritePtrSample:sampleNum];

    float *leftPost = [_ringPost writePtrLeft];
    float *rightPost = [_ringPost writePtrRight];

    IIR_low_shelving(fc, Q, g, a, b);

    for (int n = 0; n < sampleNum; n++){
        leftPtr[n] = 0.0;
        rightPtr[n] = 0.0;
        for (int m = 0; m <=J; m++){
            leftPtr[n] += b[m]*leftPre[n-m];
            rightPtr[n] += b[m]*rightPre[n-m];
        }
        
        for (int m=1;m <= I; m++){
            leftPtr[n] += -a[m]*leftPost[n-m];
            rightPtr[n] += -a[m]*rightPost[n-m];
        }
        
        leftPost[n] = leftPtr[n];
        rightPost[n] = rightPtr[n];
    }
    [_ringPost advanceWritePtrSample:sampleNum];
}

@end

@implementation PeakingFilter

-(id)init;
{
    self = [super init];
    _ringPre = [[RingBuffer alloc] init];
    _ringPost = [[RingBuffer alloc] init];
    
    _g = 0.0;
    
    return self;
}

-(void)setGain:(float)g{
    _g = g;
}

- (void)processFromLeft:(float *)leftPtr right:(float *)rightPtr samples:(UInt32)sampleNum{

    int fs = 44100;

    float fc = 1000.0 / fs;
    float Q = 1.0/sqrt(2.0);
    float g = _g;
    int I = 2;
    int J = 2;

    float a[3];
    float b[3];

    float *leftPre = [_ringPre writePtrLeft];
    float *rightPre = [_ringPre writePtrRight];
    memcpy(leftPre, leftPtr, sizeof(float) * sampleNum);
    memcpy(rightPre, rightPtr, sizeof(float) * sampleNum);

    [_ringPre advanceWritePtrSample:sampleNum];

    float *leftPost = [_ringPost writePtrLeft];
    float *rightPost = [_ringPost writePtrRight];

    IIR_peaking(fc, Q, g, a, b);

    for (int n = 0; n < sampleNum; n++){
        leftPtr[n] = 0.0;
        rightPtr[n] = 0.0;
        for (int m = 0; m <=J; m++){
            leftPtr[n] += b[m]*leftPre[n-m];
            rightPtr[n] += b[m]*rightPre[n-m];
        }
        
        for (int m=1;m <= I; m++){
            leftPtr[n] += -a[m]*leftPost[n-m];
            rightPtr[n] += -a[m]*rightPost[n-m];
        }
        
        leftPost[n] = leftPtr[n];
        rightPost[n] = rightPtr[n];
    }
    [_ringPost advanceWritePtrSample:sampleNum];
}

@end

@implementation HighShelvingFilter

-(id)init;
{
    self = [super init];
    _ringPre = [[RingBuffer alloc] init];
    _ringPost = [[RingBuffer alloc] init];
    
    _g = 0.0;
    
    return self;
}

-(void)setGain:(float)g{
    _g = g;
}


- (void)processFromLeft:(float *)leftPtr right:(float *)rightPtr samples:(UInt32)sampleNum{

    int fs = 44100;

    float fc = 2000.0 / fs;
    float Q = 1.0/sqrt(2.0);
    float g = _g;
    int I = 2;
    int J = 2;

    float a[3];
    float b[3];

    float *leftPre = [_ringPre writePtrLeft];
    float *rightPre = [_ringPre writePtrRight];
    memcpy(leftPre, leftPtr, sizeof(float) * sampleNum);
    memcpy(rightPre, rightPtr, sizeof(float) * sampleNum);

    [_ringPre advanceWritePtrSample:sampleNum];

    float *leftPost = [_ringPost writePtrLeft];
    float *rightPost = [_ringPost writePtrRight];

    IIR_peaking(fc, Q, g, a, b);

    for (int n = 0; n < sampleNum; n++){
        leftPtr[n] = 0.0;
        rightPtr[n] = 0.0;
        for (int m = 0; m <=J; m++){
            leftPtr[n] += b[m]*leftPre[n-m];
            rightPtr[n] += b[m]*rightPre[n-m];
        }
        
        for (int m=1;m <= I; m++){
            leftPtr[n] += -a[m]*leftPost[n-m];
            rightPtr[n] += -a[m]*rightPost[n-m];
        }
        
        leftPost[n] = leftPtr[n];
        rightPost[n] = rightPtr[n];
    }
    [_ringPost advanceWritePtrSample:sampleNum];
}

@end


@implementation ThreeBandEq
-(id)init{
    
    self = [super init];
    
    _lowShelving = [[LowShelvingFilter alloc] init];
    _peakShelving = [[PeakingFilter alloc] init];
    _highShelving = [[HighShelvingFilter alloc] init];
    
    return self;
}

-(void)setGainLow:(float)g{
    [_lowShelving setGain:g];
}

-(void)setGainMid:(float)g{
    [_peakShelving setGain:g];
}

-(void)setGainHigh:(float)g{
    [_highShelving setGain:g];
}


-(void)processFromLeft:(float *)left right:(float *)right samples:(UInt32)sampleNum{
    [_lowShelving processFromLeft:left right:right samples:sampleNum];
    [_peakShelving processFromLeft:left right:right samples:sampleNum];
    [_highShelving processFromLeft:left right:right samples:sampleNum];
}


@end
