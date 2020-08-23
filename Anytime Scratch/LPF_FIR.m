//
//  LPF_FIR.m
//  Anytime Scratch
//
//  Created by kyab on 2020/08/07.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "LPF_FIR.h"
#import "RingBuffer.h"
#include "soundutil.h"

@implementation LPF_FIR

- (id)init
{
    self = [super init];
    _ring = [[RingBuffer alloc] init];
    
    return self;
}

void FIR_LPF(float fe, int J, float *b, float *w){
    int offset = J / 2;
    for(int m = -J/2; m < J/2; m++){
        b[offset + m] = 2.0 * fe * sinc(2.0*M_PI*fe*m);
    }
    
    for(int m = 0; m < J+1; m++){
        b[m] *= w[m];
    }
}

void FIR_HPF(float fe, int J, float *b, float *w){
    int offset = J/2;
    for(int m = -J/2; m < J/2; m++){
        b[offset + m] = sinc(M_PI*m) - 2.0*fe*sinc(2*M_PI*fe*m);
    }
    
    for(int m = 0; m < J+1; m++){
        b[m] *= w[m];
    }
}

void FIR_BPF(float fe1, float fe2, int J, float *b, float *w){
    int offset = J/2;
    for(int m=-J/2; m <= J/2; m++){
        b[offset+m] = 2.0 * fe2 * sinc(2.0*M_PI*fe2*m)
        -2.0 * fe1 * sinc(2.0*M_PI*fe1*m);
    }
    
    for(int m = 0; m < J+1; m++){
        b[m] *= w[m];
    }
}

- (void)processFromLeft:(float *)leftPtr right:(float *)rightPtr samples:(UInt32)sampleNum{
    int fs = 44100;
    
    float fe1 = 1000.0 / fs;
    float fe2 = 5000.0 / fs;
    float delta = 1000.0 / fs;
    
    int J = (int)(3.1/delta + 0.5)-1;
    if (J % 2 == 1){
        J++;
    }
    
    float *b = (float *)calloc(J+1, sizeof(float));
    float *w = (float *)calloc(J+1, sizeof(float));
    
    hanning_window(w, (J+1));
    
    FIR_BPF(fe1, fe2, J, b, w);   //calc parameters
    
    float *left = [_ring writePtrLeft];
    float *right = [_ring writePtrRight];
    memcpy(left, leftPtr, sizeof(float) * sampleNum);
    memcpy(right, rightPtr, sizeof(float) * sampleNum);
    
    [_ring advanceWritePtrSample:sampleNum];
    
    for (int i = 0; i < sampleNum ; i++){
        leftPtr[i] = 0.0;
        rightPtr[i] = 0.0;
        for (int m = 0; m <= J; m++){
            leftPtr[i] += b[m] * left[i - m];
            rightPtr[i] += b[m] * right[i - m];
        }
    }
    
    free(b);
    free(w);
    
    return;
}
@end
