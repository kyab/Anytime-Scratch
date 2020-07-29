//
//  AppController.m
//  MyPlaythrough
//
//  Created by kyab on 2017/05/15.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import "AppController.h"
#import "AudioToolbox/AudioToolbox.h"

#include <cmath>

@implementation AppController

-(void)awakeFromNib{
    
    _ae = [[AudioEngine alloc] init];
    if ([_ae initialize]){
        NSLog(@"AudioEngine all OK");
    }
    [_ae setRenderDelegate:(id<AudioEngineDelegate>)self];
    
//    [_ae testAirPlay];
    
    _ring = [[RingBuffer alloc] init];
    [_ringView setRingBuffer:_ring];
    
    [_popupInputDevice removeAllItems];
    NSArray *inputs = [_ae listDevices:NO];
    if (inputs && inputs.count > 0){
        for (int i = 0 ; i < inputs.count ; i++){
            [_popupInputDevice addItemWithTitle:[inputs objectAtIndex:i]];
        }
    }
    [_popupInputDevice selectItemWithTitle:@"Background Music"];
    
    
    [_popupOutputDevice removeAllItems];
    NSArray *outputs = [_ae listDevices:YES];
    if (outputs && outputs.count > 0){
        for (int i = 0 ; i < outputs.count ; i++){
            [_popupOutputDevice addItemWithTitle:[outputs objectAtIndex:i]];
        }
    }
    [_popupOutputDevice selectItemWithTitle:@"Built-in Output"];

    
    [_turnTable setDelegate:(id<TurnTableDelegate>)self];
    [_turnTable setRingBuffer:_ring];
    [_turnTable start];
    
    [_chkSlip setState:NSOnState];
    _slip = YES;
    
    [_btnReverse sendActionOn:NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp];
    [_btnReverse setButtonType:NSButtonTypeOnOff];
    
    [_btnLoop sendActionOn:NSEventMaskLeftMouseDown |
     NSEventMaskLeftMouseUp];
    [_btnLoop setButtonType:NSButtonTypeOnOff];
    
    
    [_btnTAP setKeyEquivalent:@"\t"];
    _bpmHistory = [[NSMutableArray alloc] init];
    _bpm = 120.0;
    
    _speedRate = 1.0;
    _speedChanging = NO;
    
    [_ae changeSystemOutputDeviceToBGM];
    [_ae startInput];
    _fadeRequired = YES;
    
    _tableStopped = NO;
    
    [_ae startOutput];
    
    [self testMIDI];
    
    
}

-(void)terminate{
    [_ae stopOutput];

    [_ae stopInput];
    [_ae restoreSystemOutputDevice];
    
}

float sinFadeWindow(float fadeStartRate, float x, float val){
    float y = 0;
    if (x < 0 || x > 1) {
        return 0;
    }
    if (x < fadeStartRate){
        y = 1.0/2.0*sin(M_PI / fadeStartRate * x + 3.0 /2 * M_PI) + 1.0/2;
    }else if (x < 1.0 - fadeStartRate) {
        y = 1.0;
    }else{
        y = 1.0/2.0*sin(M_PI / fadeStartRate * x + 3.0 / 2.0 * M_PI
                          -1.0/fadeStartRate * M_PI) + 1.0 / 2.0;
    }
    return val * y;

}

float crossfadeWindow(float fadeStartRate, float x, float val){
    if (x < 0 || x > 1) { return 0; }

    if (x < fadeStartRate) {
        return val * (1.0 / fadeStartRate * x);
    } else if (x < 1.0 - fadeStartRate) {
        return val * 1.0;
    } else {
        return val * ((-1.0 / fadeStartRate * x + 1 / fadeStartRate));
    }
}

static double linearInterporation(int x0, double y0, int x1, double y1, double x);


const UInt32 GRAIN_SIZE = 6000;

typedef struct _calcState{
    SInt32 current_x;
    SInt32 current_grain_start;
    SInt32 current_x2;
    SInt32 current_grain_start2;
    
    SInt32 start_x;
} calcState;

calcState g_calcState;
calcState g_calcState_bk;

double ratio = 1.0;
double g_ratio = 1.0;
double faderValue = 1.0;

const int FADE_STATE_NONE = 0;
const int FADE_STATE_OUT = 1;
const int FADE_STATE_IN = 2;

int fadeState = FADE_STATE_NONE;

//-(void)consume_backyard:(SInt32)offset{
//    if (offset >= 0){
//        for (UInt32 c = 0; c < offset; c++){
//            if (g_calcState_bk.current_x > GRAIN_SIZE){
//                g_calcState_bk.current_grain_start += GRAIN_SIZE;
//                g_calcState_bk.current_x = 0;
//            }
//            if (g_calcState_bk.current_x2 > (SInt32)GRAIN_SIZE){
//                g_calcState_bk.current_grain_start2 += GRAIN_SIZE;
//                g_calcState_bk.current_x2 = 0;
//            }
//            g_calcState_bk.current_x++;
//            g_calcState_bk.current_x2++;
//
//
//            if (g_calcState_bk.current_grain_start + g_calcState_bk.current_x > RING_SIZE_SAMPLE){
//                g_calcState_bk.current_grain_start = 0 - 6000;
//                g_calcState_bk.current_x = 0;
//                g_calcState_bk.current_grain_start2 = GRAIN_SIZE/2 - 6000;
//                g_calcState_bk.current_x2 = -1 * round(GRAIN_SIZE/2 * ratio);
//            }
//
//        }
//    }else{
//        for (SInt32 c = 0 ; c < -offset; c++){
//
//            g_calcState_bk.current_x--;
//            g_calcState_bk.current_x2--;
//
//            if (g_calcState_bk.current_x < GRAIN_SIZE){
//                g_calcState_bk.current_grain_start -= GRAIN_SIZE;
//                g_calcState_bk.current_x = GRAIN_SIZE;
//            }
//            if (g_calcState_bk.current_x2< GRAIN_SIZE) {
//                g_calcState_bk.current_grain_start2 -= GRAIN_SIZE;
//                g_calcState_bk.current_x2 = GRAIN_SIZE;
//            }
//        }
//    }
//}

-(void)consume:(SInt32)offset{
    
    if (offset >= 0){
        for (UInt32 c = 0; c < offset; c++){
            g_calcState.start_x++;

            int overCount = 0;
            if( g_calcState.current_x > GRAIN_SIZE * (1+(ratio-1)/2) ){
                g_calcState.current_grain_start += GRAIN_SIZE;
                g_calcState.current_x = round( (GRAIN_SIZE*(1+(ratio-1)/2) - GRAIN_SIZE) * (-1) );
                overCount++;
            }
            if( g_calcState.current_x2 > GRAIN_SIZE * (1+(ratio-1)/2) ){
                g_calcState.current_grain_start2 += GRAIN_SIZE;
                g_calcState.current_x2 = round( (GRAIN_SIZE*(1+(ratio-1)/2) - GRAIN_SIZE) * (-1) );
                overCount++;
            }
            
            if (overCount == 2){
                NSLog(@"overCount with consume");
            }
            
            g_calcState.current_x++;
            g_calcState.current_x2++;


            if (g_calcState.current_grain_start + g_calcState.current_x > RING_SIZE_SAMPLE){
                g_calcState.current_grain_start = 0;
                g_calcState.current_x = 0;
                g_calcState.current_grain_start2 = GRAIN_SIZE/2;
                g_calcState.current_x2 = -1 * round(GRAIN_SIZE/2 * ratio);
            }
            
        }
    }else{
        for (SInt32 c = 0 ; c < -offset; c++){

            g_calcState.current_x--;
            g_calcState.current_x2--;

            if (g_calcState.current_x < (GRAIN_SIZE * (1 + (ratio - 1) / 2) - GRAIN_SIZE) * (-1)) {
                g_calcState.current_grain_start -= GRAIN_SIZE;
                g_calcState.current_x = round(GRAIN_SIZE * (1 + (ratio - 1) / 2));
            }
            if (g_calcState.current_x2< (GRAIN_SIZE * (1 + (ratio - 1) / 2) - GRAIN_SIZE) * (-1)) {
                g_calcState.current_grain_start2 -= GRAIN_SIZE;
                g_calcState.current_x2 = round(GRAIN_SIZE * (1 + (ratio - 1) / 2));
            }
        }
    }
    
    
}

-(void)getAt: (SInt32) offset outLeft:(float *)retValL outRight:(float *)retValR{
    
    const float fadeStartRate = -1/2.0 * ratio + 1;
    
    SInt32 current_x = g_calcState.current_x;
    SInt32 current_grain_start = g_calcState.current_grain_start;
    SInt32 current_x2 = g_calcState.current_x2;
    SInt32 current_grain_start2 = g_calcState.current_grain_start2;
    
    *retValL = 0;
    *retValR = 0;
    
    if (offset >= 0){
        for (UInt32 c = 0; c < offset; c++){
        
            int overCount = 0;
            if( current_x > GRAIN_SIZE * (1+(ratio-1)/2) ){
                current_grain_start += GRAIN_SIZE;
                current_x = round( (GRAIN_SIZE*(1+(ratio-1)/2) - GRAIN_SIZE) * (-1) );
                overCount++;
            }
            if( current_x2 > GRAIN_SIZE * (1+(ratio-1)/2) ){
                current_grain_start2 += GRAIN_SIZE;
                current_x2 = round( (GRAIN_SIZE*(1+(ratio-1)/2) - GRAIN_SIZE) * (-1) );
                overCount++;
            }
            if (overCount == 2){
                NSLog(@"overCount");
            }
            
            current_x++;
            current_x2++;
        }
    }else{
        for (SInt32 c = 0; c < -offset; c++){
            current_x--;
            current_x2--;
            
            if (current_x < (GRAIN_SIZE * (1 + (ratio - 1) / 2) - GRAIN_SIZE) * (-1)) {
                current_grain_start -= GRAIN_SIZE;
                current_x = round(GRAIN_SIZE * (1 + (ratio - 1) / 2));
            }
            if (current_x2 < (GRAIN_SIZE * (1 + (ratio - 1) / 2) - GRAIN_SIZE) * (-1)) {
                current_grain_start2 -= GRAIN_SIZE;
                current_x2 = round(GRAIN_SIZE * (1 + (ratio - 1) / 2));
            }
        }
    }
    
    {
        const SInt32 x = current_grain_start + current_x;
        float valL = 0;
        float valR = 0;
        
        if ( 0 <= x ){
            float *leftPtr = [_ring startPtrLeft];
            float *rightPtr = [_ring startPtrRight];
            
            valL = *(leftPtr + x);
            valR = *(rightPtr + x);
            
            if (current_x2 < 0){
                
            }else{
                valL = sinFadeWindow(fadeStartRate , 1.0*current_x / GRAIN_SIZE, valL);
                valR = sinFadeWindow(fadeStartRate , 1.0*current_x / GRAIN_SIZE, valR);
            }
            *retValL = valL;
            *retValR = valR;
        }
    }
    {
        const SInt32 x2 = current_grain_start2 + current_x2;
        float valL2 = 0;
        float valR2 = 0;
        
        if (0 <= x2){
            float *leftPtr = [_ring startPtrLeft];
            float *rightPtr = [_ring startPtrRight];
            
            valL2 = *(leftPtr + x2);
            valR2 = *(rightPtr + x2);
            
            valL2 = sinFadeWindow(fadeStartRate , 1.0*current_x2 / GRAIN_SIZE, valL2);
            valR2 = sinFadeWindow(fadeStartRate , 1.0*current_x2 / GRAIN_SIZE, valR2);
            
            *retValL += valL2;
            *retValR += valR2;
        }
    }
        
}


- (OSStatus) outCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    //first time treatment
    static BOOL printNumFrames = NO;
    if (!printNumFrames){
        NSLog(@"outCallback NumFrames = %d", inNumberFrames);
        printNumFrames = YES;
        
        g_calcState.current_grain_start = 0 - 6000;
        g_calcState.current_x = 0;
        g_calcState.current_grain_start2 = GRAIN_SIZE/2 - 6000;
        g_calcState.current_x2 = -1 * round(GRAIN_SIZE/2 * ratio);

        g_calcState.current_grain_start = 0;
        g_calcState.current_x = 0;
        g_calcState.current_grain_start2 = GRAIN_SIZE/2;
        g_calcState.current_x2 = -1 * round(GRAIN_SIZE/2 * ratio);
    }
    
    if (![_ae isPlaying]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        return noErr;
    }
    
    if ([_ring isShortage]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        NSLog(@"shortage in out thread");
        return noErr;
    }
    
    if(0){
        //experiment time stretch

        for (UInt32 i = 0 ; i < inNumberFrames ; i++){
            float left = 0.0;
            float right = 0.0;
            
            [self getAt:i outLeft:&left outRight:&right];
        
            ((float *)ioData->mBuffers[0].mData)[i] = left;
            ((float *)ioData->mBuffers[1].mData)[i] = right;
        }
        [self consume:inNumberFrames];

        return noErr;
        
    }
    
    if(1){
        //experiment pitch shift with scratch support

        if(_tableStopped && !_speedChanging){
            UInt32 sampleNum = inNumberFrames;
            float *pLeft = (float *)ioData->mBuffers[0].mData;
            float *pRight = (float *)ioData->mBuffers[1].mData;
            bzero(pLeft,sizeof(float)*sampleNum );
            bzero(pRight,sizeof(float)*sampleNum );
            return noErr;
        }
        
        
        double speedRate = _speedRate;
        if (ratio != g_ratio){
            if (fadeState == FADE_STATE_IN){
                ratio = g_ratio;
                [self followNow:self];
            }
        }
        
        //before ratechange.
        float reqNumberFrames = inNumberFrames * speedRate;
        
        //time stretch
        UInt32 numberStretchedFrames = ceil(abs(reqNumberFrames* ratio)) + 1 + 1;
        float *pTmpLeft = (float *)malloc(numberStretchedFrames * sizeof(float));
        float *pTmpRight = (float *)malloc(numberStretchedFrames * sizeof(float));
        
        for (UInt32 i = 0; i < numberStretchedFrames; i++){
            float left = 0;
            float right = 0;
            
            SInt32 offset = 0;
            if ((reqNumberFrames) > 0){
                offset = i;
            }else{
                offset = -(SInt32)i;
            }
            
            [self getAt:offset outLeft:&left outRight:&right];
        
            pTmpLeft[i] = left;
            pTmpRight[i] = right;
            if (abs(left) > 1.01 || abs(right) > 1.01){
//                NSLog(@"overflow in stretch phase left=%f, right=%f", left, right);
            }
        }

        [self consume:round(reqNumberFrames*ratio)];

        UInt32 resampledNum = ceil(abs(reqNumberFrames))+1;
        
        //resampling to pitch shift
        float *pFinLeft = (float *)malloc(resampledNum * sizeof(float));
        float *pFinRight = (float *)malloc(resampledNum * sizeof(float));
        
        for (UInt32 i = 0 ; i < resampledNum; i++){
            int x0 = floor(i * ratio);
            int x1 = ceil(i * ratio);
            
            float y0_l = pTmpLeft[x0];
            float y0_r = pTmpRight[x0];
            float y1_l = pTmpLeft[x1];
            float y1_r = pTmpRight[x1];
            
            pFinLeft[i] = linearInterporation(x0, y0_l, x1, y1_l , i*ratio);
            pFinRight[i] = linearInterporation(x0, y0_r, x1, y1_r, i*ratio);
            
            if (i < inNumberFrames){
                ((float *)ioData->mBuffers[0].mData)[i] = pFinLeft[i];
                ((float *)ioData->mBuffers[1].mData)[i] = pFinRight[i];
            }
            if (abs(pFinLeft[i]) > 1.01 || abs(pFinRight[i]) > 1.01){
//                NSLog(@"overflow in shift phase left=%f, right=%f", pFinLeft[i] , pFinRight[i]);
            }
            
        }
        free(pTmpLeft);
        free(pTmpRight);
        

        SInt32 consumedFrames = 0;
        [self convertAtRateFromLeft:pFinLeft right:pFinRight ToSamples:inNumberFrames rate:speedRate
                     consumedFrames: &consumedFrames];
        free(pFinLeft);
        free(pFinRight);
        
        if (fadeState == FADE_STATE_OUT){
            [self fadeOutFromLeft:_conv_left right:_conv_right ToSamples:inNumberFrames];
            _fadeRequired = false;
            fadeState = FADE_STATE_IN;
        }else if (fadeState == FADE_STATE_IN){
            [self fadeInFromLeft:_conv_left right:_conv_right ToSamples:inNumberFrames];
            fadeState = FADE_STATE_NONE;
        }
        
        for(int i = 0 ; i < inNumberFrames;i++) {
            _conv_left[i] *= faderValue;
            _conv_right[i] *= faderValue;
        }
                
        memcpy(ioData->mBuffers[0].mData,
               _conv_left, sizeof(float) * inNumberFrames);
        memcpy(ioData->mBuffers[1].mData,
               _conv_right, sizeof(float) * inNumberFrames);
        
        if (speedRate >= 0){
            [_ring advanceReadPtrSample:consumedFrames+1];
        }else{
            [_ring advanceReadPtrSample:consumedFrames-1];
        }

        return noErr;
        
    }
    
    
    if (_tableStopped){
        float *leftPtr = [_ring readPtrLeft];
        float *rightPtr = [_ring readPtrRight];
        
        if (!leftPtr || !rightPtr){
            //not enough buffer
            //zero output
//            NSLog(@"SUDDEN ZERO");
            UInt32 sampleNum = inNumberFrames;
            float *pLeft = (float *)ioData->mBuffers[0].mData;
            float *pRight = (float *)ioData->mBuffers[1].mData;
            bzero(pLeft, sizeof(float)*sampleNum );
            bzero(pRight, sizeof(float)*sampleNum );
            return noErr;
        }
        if (!_speedChanging){
            UInt32 sampleNum = inNumberFrames;
            float *pLeft = (float *)ioData->mBuffers[0].mData;
            float *pRight = (float *)ioData->mBuffers[1].mData;
            bzero(pLeft, sizeof(float)*sampleNum );
            bzero(pRight, sizeof(float)*sampleNum );
            return noErr;
        }else{
            SInt32 consumed = 0;
            [self convertAtRateFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames rate:_speedRate consumedFrames:&consumed];


            memcpy(ioData->mBuffers[0].mData,
                   _conv_left, sizeof(float) * inNumberFrames);
            memcpy(ioData->mBuffers[1].mData,
                   _conv_right, sizeof(float) * inNumberFrames);
            
            [_ring advanceReadPtrSample:consumed];
        }
        return noErr;
    }
    
    
    if (!_speedChanging){

        float *leftPtr = [_ring readPtrLeft];
        float *rightPtr = [_ring readPtrRight];
        
        if (!leftPtr || !rightPtr){
            //not enough buffer
            //zero output
//            NSLog(@"SUDDEN ZERO");
            UInt32 sampleNum = inNumberFrames;
            float *pLeft = (float *)ioData->mBuffers[0].mData;
            float *pRight = (float *)ioData->mBuffers[1].mData;
            bzero(pLeft,sizeof(float)*sampleNum );
            bzero(pRight,sizeof(float)*sampleNum );
            _fadeRequired = YES;
            return noErr;
        }
        
        if (_loop){
            [self fadeInFromLeftLoop:leftPtr right:rightPtr ToSamples:inNumberFrames];
            memcpy(ioData->mBuffers[0].mData,
                   _conv_left, sizeof(float) * inNumberFrames);
            memcpy(ioData->mBuffers[1].mData,
                   _conv_right, sizeof(float) * inNumberFrames);
            return noErr;
        }
        
        
        if (!_fadeRequired){
            memcpy(ioData->mBuffers[0].mData,
                   leftPtr, sizeof(float) * inNumberFrames);
            memcpy(ioData->mBuffers[1].mData,
                   rightPtr, sizeof(float) * inNumberFrames);
            
            for (int i = 0 ; i < inNumberFrames; i++){
                if (rightPtr[i] < -1.1 || rightPtr[i] > 1.1){
                    NSLog(@"over value(%f) at index : %d (normal)", rightPtr[i], i);
                }
            }
            [_ring advanceReadPtrSample:inNumberFrames];
            
        }else{
            [self fadeInFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames];
            memcpy(ioData->mBuffers[0].mData,
                   _conv_left, sizeof(float) * inNumberFrames);
            memcpy(ioData->mBuffers[1].mData,
                   _conv_right, sizeof(float) * inNumberFrames);
            [_ring advanceReadPtrSample:inNumberFrames];
            _fadeRequired = NO;
        }
        
    }else{
        float *leftPtr = [_ring readPtrLeft];
        float *rightPtr = [_ring readPtrRight];
        
        if (!leftPtr || !rightPtr){
            //not enough buffer
            //zero output
            UInt32 sampleNum = inNumberFrames;
            float *pLeft = (float *)ioData->mBuffers[0].mData;
            float *pRight = (float *)ioData->mBuffers[1].mData;
            bzero(pLeft, sizeof(float)*sampleNum );
            bzero(pRight, sizeof(float)*sampleNum );
            return noErr;
        }
        
        SInt32 consumed = 0;
        [self convertAtRateFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames rate:_speedRate consumedFrames:&consumed];
        
        memcpy(ioData->mBuffers[0].mData,
               _conv_left, sizeof(float) * inNumberFrames);
        memcpy(ioData->mBuffers[1].mData,
               _conv_right, sizeof(float) * inNumberFrames);
        
        [_ring advanceReadPtrSample:consumed];
        
    }
    return noErr;
}

- (OSStatus) inCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    

    static BOOL printNumFrames = NO;
    if (!printNumFrames){
        NSLog(@"inCallback NumFrames = %d", inNumberFrames);
        printNumFrames = YES;
    }
    
    
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) +  sizeof(AudioBuffer)); // for 2 buffers for left and right
    
    
    float *leftPrt = [_ring writePtrLeft];
    float *rightPtr = [_ring writePtrRight];
    
    bufferList->mNumberBuffers = 2;
    bufferList->mBuffers[0].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mData = leftPrt;
    bufferList->mBuffers[1].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[1].mNumberChannels = 1;
    bufferList->mBuffers[1].mData = rightPtr;
    
    
    OSStatus ret = [_ae readFromInput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:bufferList];
    
    free(bufferList);
    
    if ([_ae isRecording]){
        [_ring advanceWritePtrSample:inNumberFrames];
    }
    
    return ret;
    
}


static double linearInterporation(int x0, double y0, int x1, double y1, double x){
    if (x0 == x1){
        return y0;
    }
    double rate = (x - x0) / (x1 - x0);
    double y = (1.0 - rate)*y0 + rate*y1;
    return y;
}


-(void)convertAtRateFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames rate:(double)rate consumedFrames:(SInt32 *)consumed{
    if (rate == 1.0 || rate==0.0 || rate ==-0.0){
        [self convertAtRatePlusFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames rate:rate consumedFrames:consumed];
    }else if(rate >= 0){
        [self convertAtRatePlusFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames rate:rate consumedFrames:consumed];
    }else{
        [self convertAtRateMinusFromLeft:leftPtr right:rightPtr ToSamples:inNumberFrames rate:rate consumedFrames:consumed];
    }
}

-(void)convertAtRatePlusFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames rate:(double)rate consumedFrames:(SInt32 *)consumed{
    
    *consumed = 0;
    
    for (int targetSample = 0; targetSample < inNumberFrames; targetSample++){
        int x0 = floor(targetSample*rate);
        int x1 = ceil(targetSample*rate);
        
        float y0_l = leftPtr[x0];
        float y1_l = leftPtr[x1];
        float y_l = linearInterporation(x0, y0_l, x1, y1_l, targetSample*rate);
        
        float y0_r = rightPtr[x0];
        float y1_r = rightPtr[x1];
        float y_r = linearInterporation(x0, y0_r, x1, y1_r, targetSample*rate);
        
        if (abs(y_l) > 1.01 || abs(y_r) > 1.01){
//            NSLog(@"overflow at convertAtRatePlusFromLeft %f,%f", y_l, y_r);
            
        }

        _conv_left[targetSample] = y_l;
        _conv_right[targetSample] = y_r;
        *consumed = x1;
    }
    
}

-(void)convertAtRateMinusFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames rate:(double)rate consumedFrames:(SInt32 *)consumed{
    
    *consumed = 0;
    rate = -rate;
    
    for (int targetSample = 0 ; targetSample < inNumberFrames;targetSample++){
        int x0 = abs(floor(targetSample*rate));
        int x1 = abs(ceil(targetSample*rate));
        
        float y0_l = *(leftPtr + x0);
        float y1_l = *(leftPtr + x1);
        float y_l = linearInterporation(x0, y0_l, x1, y1_l, targetSample*rate);

        float y0_r = *(rightPtr + x0);
        float y1_r = *(rightPtr + x1);
        float y_r = linearInterporation(x0, y0_r, x1, y1_r, targetSample*rate);
        
        if (abs(y_l) > 1.01 || abs(y_r) > 1.01){
//            NSLog(@"overflow at convertAtRateMinusFromLeft %f,%f", y_l, y_r);
            
        }
        _conv_left[targetSample] = y_l;
        _conv_right[targetSample] = y_r;
        *consumed = -x1;
        
    }
}


double fadeInFactor(UInt32 offset){
    if (offset < 32){
        return 1/32.0*offset;
    }else{
        return 1.0;
    }
}

double fadeOutFactor(UInt32 offset){
    if (offset < 32){
        return 1/32.0 * offset;
        return 1.0;
    }else{
        return 1.0;
    }
}

-(void)fadeInFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames{
    for (int i = 0 ; i < inNumberFrames; i++){
        double factor = fadeInFactor(i);
        _conv_left[i] = leftPtr[i]*factor;
        _conv_right[i] = rightPtr[i]*factor;
    }
}

-(void)fadeOutFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames{
    for (int i = 0 ; i < inNumberFrames; i++){
        double factor = fadeOutFactor(inNumberFrames - i);
        _conv_left[i] = leftPtr[i]*factor;
        _conv_right[i] = rightPtr[i]*factor;
        
    }
}

//advance in this func.
-(void)fadeInFromLeftLoop:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames{
    
    float *cur_left = leftPtr;
    float *cur_right = rightPtr;
    float *to_left = _conv_left;
    float *to_right = _conv_right;
    
    UInt32 written = 0;
    
    while(true){
        *to_left = *cur_left;
        *to_right = *cur_right;
        
        cur_left++;
        cur_right++;
        [_ring advanceReadPtrSample:1];
        to_left++;
        to_right++;
        
        if (++_writtenInLoop >= _loopLength){
            _writtenInLoop = 0;
            [_ring moveReadPtrToSample:_loopStartFrame];
            leftPtr = [_ring readPtrLeft];
            rightPtr = [_ring writePtrRight];
        }
        if (++written == inNumberFrames){
            break;
        }
        
    }
}

-(void)turnTableSpeedRateChanged{
    
    _speedRate = [_turnTable speedRate];
    if (_speedRate == 1.0){
        if (_tableStopped){
            _speedChanging = NO;
        }else{
            _speedChanging = NO;
            if (_slip){
                [self followNow:self];
            }
        }
        return;
    }
    _speedChanging = YES;
}

- (IBAction)inputDeviceSelected:(id)sender {
    
    NSString *newDevice = [_popupInputDevice titleOfSelectedItem];
    NSLog(@"change input %@", newDevice);
    [_ae changeInputDeviceTo:newDevice];
}


- (IBAction)followNow:(id)sender {

    [_ring follow];
    _fadeRequired = YES;
    
    UInt32 offset = UInt32([_ring readPtrLeft] - [_ring startPtrLeft]);

    g_calcState.current_grain_start = offset- GRAIN_SIZE;
    g_calcState.current_x = 0;
    g_calcState.current_grain_start2 = offset - GRAIN_SIZE/2;
    g_calcState.current_x2 = -round(GRAIN_SIZE/2 * g_ratio);
    
    
//    g_calcState.current_grain_start = offset- 6000;
//    g_calcState.current_x = 0;
//    g_calcState.current_grain_start2 = offset - GRAIN_SIZE/2;
//    g_calcState.current_x2 = -round(GRAIN_SIZE/2 * ratio);
    
   
}

- (IBAction)slipChanged:(id)sender {
    if ([_chkSlip state] == NSOnState){
        _slip = YES;
    }else{
        _slip = NO;
    }
}

- (IBAction)reverseClicked:(id)sender {
    if (_slip){
        if (_reversePressing){
            //up
            _speedChanging = NO;
            _speedRate = 1.0;
            [_ring follow];
            _fadeRequired = YES;
            [_btnReverse setState:NSOffState];
            [_turnTable setReverse:NO];
            _reversePressing = NO;
        }else{
            //down
            _speedChanging = YES;
            _speedRate = -1.0;
            [_btnReverse setState:NSOnState];
            [_turnTable setReverse:YES];
            _reversePressing = YES;
        }
    }else{
        if (_reversePressing){
            _reversePressing = NO;
        }else{
            _reversePressing = YES;
            if ([_btnReverse state] == NSOnState){
                _speedChanging = YES;
                _speedRate = -1.0;
                [_turnTable setReverse:YES];

            }else{
                _speedChanging = NO;
                _speedRate = 1.0;
                [_ring follow];
                _fadeRequired = YES;
                [_turnTable setReverse:NO];
            }
        }
    }  
}

- (IBAction)loopClicked:(id)sender {
    if (_loopPressing){
        _loopPressing = NO;
        if ([_btnLoop state] == NSOnState){
            _speedChanging = NO;
            _speedRate = 0;
            _loop = YES;
            _loopLength = 44100 / (_bpm/60) * 4;
            _loopStartFrame = [_ring advanceReadPtrSample:-1.0*_loopLength];
            
        }else{
            _loop = NO;
            [_ring follow];
            _fadeRequired = YES;
        }
    
    }else{
        _loopPressing = YES;

    }
}

- (IBAction)tableStopClicked:(id)sender {
    if (_btnTableStop.state == NSOnState){
        if (_tableStopTimer){
            [_tableStopTimer invalidate];
        }
        
        _tableStopped = NO;
        _speedChanging = NO;
        _speedRate = 1.0;
        if (_slip){
            [self followNow:self];
        }
        
        [_btnTableStop setTitle:@"Table [S]top"];
        
    }else{
        _tableStopTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(tableStopTimer:) userInfo:nil repeats:YES];
        [_btnTableStop setTitle:@"Table [S]tart"];
    }
}

- (void)tableStopTimer:(NSTimer *)t {
    if (_speedRate < 0.01f){
        _speedRate = 0.0f;
        [_tableStopTimer invalidate];
        _tableStopped = YES;
        _speedChanging = NO;
        return;
    }else{
        _speedChanging = YES;
        _speedRate -= 0.02;
    }
}


- (IBAction)tapClicked:(id)sender {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    double bpm = 0;
    if ((_bpmHistory.count) == 0){
        if (_prevTAPTime == 0.0){
            _prevTAPTime = now;
            return ;
        }
    }
    
    bpm = 60.0 / (now - _prevTAPTime);
    _prevTAPTime = now;
    if (bpm < 40.0){
        [_bpmHistory removeAllObjects];
        return;
    }
    
    //bpm is reasonable value
    
    [_bpmHistory addObject:[NSNumber numberWithDouble:bpm]];
    
    //remove old one.
    if (_bpmHistory.count >= 10){
        NSMutableArray *newArray = [[NSMutableArray alloc] init];
        for (int i = 1 ; i < _bpmHistory.count ; i++){
            double val = [[_bpmHistory objectAtIndex:i] doubleValue];
            [newArray addObject:[NSNumber numberWithDouble:val]];
        }
        _bpmHistory = newArray;
    }
    
    //get mean bpm
    if (_bpmHistory.count >= 2){
        double sum = 0;
        for (int i = 0 ; i < _bpmHistory.count ; i++){
            sum += [[_bpmHistory objectAtIndex:i] doubleValue];
        }
        float meanBPM = sum / _bpmHistory.count;
        _bpm = meanBPM;
        [_lblBPM setStringValue:[NSString stringWithFormat:@"%.02f",_bpm]];
    }
}

- (IBAction)loopX1_2Clicked:(id)sender {
    _loopLength /= 2;
}

- (IBAction)loopx1_4Cliked:(id)sender {
    _loopLength /= 4;
}

- (IBAction)pitchChanged:(id)sender {
    g_ratio = [_sliderPitch doubleValue];
    
    fadeState = FADE_STATE_OUT;
//    [self followNow:self];
}

- (IBAction)faderChanged:(id)sender {
    float val = [_sliderFader doubleValue];
    
    if (val >= 0){
        faderValue = 1.0;
    }else{
        //1 + (-0.4) = 0.6
        //1 + (-1.0) = 0.0;
        faderValue = 1 + val;
    }
    
    
}


void MIDIInputProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)
{
    MIDIPacket *packet = (MIDIPacket *)&(pktList->packet[0]);
    UInt32 packetCount = pktList->numPackets;
 
    AppController *appController = (__bridge AppController *)readProcRefCon;
    
    
    for (NSInteger i = 0; i < packetCount; i++) {
        
        Byte mes = packet->data[0] & 0xF0;
        Byte ch = packet->data[0] & 0x0F;
        
        if ((mes == 0x90) && (packet->data[2] != 0)) {
//            NSLog(@"note on number = %2.2x / velocity = %2.2x / channel = %2.2x",
//                  packet->data[1], packet->data[2], ch);
            [appController onMIDINoteOn:packet->data[1] vel:packet->data[2] chan:ch];
        } else if (mes == 0x80 || mes == 0x90) {
//            NSLog(@"note off number = %2.2x / velocity = %2.2x / channel = %2.2x",
//                  packet->data[1], packet->data[2], ch);
            [appController onMIDINoteOff:packet->data[1] vel:packet->data[2] chan:ch];
        } else if (mes == 0xB0) {
//            NSLog(@"cc number = %2.2x / data = %2.2x / channel = %2.2x",
//                  packet->data[1], packet->data[2], ch);
            [appController onMIDICC:packet->data[1] data:packet->data[2] chan:ch];
             
        } else {
            NSLog(@"etc");
        }
        packet = MIDIPacketNext(packet);
    }
}

-(void)onMIDICC:(int)number data:(int)data chan:(int)chan{
//    NSLog(@"onMIDICC number:%d, data:%d", number, data);
    if (number == 33 || number == 34){
        [_turnTable onMIDIScratch:number value:data chan:chan];
        return;
    }else if(number == 31){
        
        if (data > 64){
            faderValue = (data-64.0)/64.0;
        }else{
            faderValue = (data-64.0)/64.0;
        }
        if (faderValue >= 0){
            faderValue = 1.0;
        }else{
            //1 + (-0.4) = 0.6
            //1 + (-1.0) = 0.0;
            faderValue = 1 + faderValue;
        }
        
        //Control change should be done on Main Thread
        [self performSelectorOnMainThread:@selector(onMIDIFaderChanged:)
                               withObject:[NSNumber numberWithInt:data] waitUntilDone:NO];

        return;
    }else if(number == 0){
        [self onMIDITempoChanged:127-data];
    }else{
        //NSLog(@"onMIDICC number:%d, data:%d", number, data);
    }

}

-(void)onMIDINoteOn:(int)noteNumber vel:(int)vel chan:(int)chan{
    if (noteNumber == 54){
        [_turnTable onMIDITouchStart];
        return;
    }

    if (noteNumber == 11){
        [self performSelectorOnMainThread:@selector(performClickTableStop)
                               withObject:nil waitUntilDone:NO];
        return;
    }

}

-(void)onMIDINoteOff:(int)noteNumber vel:(int)vel chan:(int)chan{
    if (noteNumber == 54){
        [_turnTable onMIDITouchStop];
        return;
    }
}

-(void)performClickTableStop{
    [_btnTableStop performClick:self];
}

-(void)onMIDITempoChanged:(int)value{
    NSLog(@"tempo changed to %d", value);
    g_ratio = 1.0 + 1.0*value/127;
    fadeState = FADE_STATE_OUT;
    [self performSelectorOnMainThread:@selector(syncSliderPitch)
                           withObject:nil waitUntilDone:NO];
}
-(void)syncSliderPitch{
    [_sliderPitch setDoubleValue:g_ratio];
}


-(void)onMIDIFaderChanged:(NSNumber *)numberValue{
    int value = [numberValue intValue];
    if (value > 64){
        [_sliderFader setDoubleValue:(value-64.0)/64.0];
    }else{
        [_sliderFader setDoubleValue:(value-64.0)/64.0];
    }

}

- (void)testMIDI{
    NSLog(@"testMIDI");
    
    OSStatus err;
    CFStringRef strEndPointRef = NULL;
    
    MIDIClientRef clientRef;
    MIDIPortRef inputPortRef;
    
    //MIDIClient creation
    NSString *clientName = @"inputClient";
    err = MIDIClientCreate((__bridge CFStringRef)clientName, NULL, NULL, &clientRef);
    if (err != noErr){
        NSLog(@"MIDIClientCreate err = %d", err);
        return;
    }
    
    //MIDIPort Creation
    NSString *inputPortName = @"inputPort";
    err = MIDIInputPortCreate(clientRef, (__bridge CFStringRef)inputPortName,
                              MIDIInputProc, (__bridge void *)self, &inputPortRef);
    if (err != noErr){
        NSLog(@"MIDInputPortCreate err = %d", err);
        return;
    }
    
    
    ItemCount sourceCount = MIDIGetNumberOfSources();
    
    for(ItemCount i = 0 ; i < sourceCount; i++){
        
        MIDIEndpointRef endPointRef = MIDIGetSource(i);
        
        //get name for this MIDI endpoint.
        err = MIDIObjectGetStringProperty(endPointRef,
                                          kMIDIPropertyName, &strEndPointRef);
        if (err != noErr){
            NSLog(@"err = %d", err);
            return;
        }else{
            NSLog(@"EndPoint =  %@", strEndPointRef);
        }
        
        //connect
        err = MIDIPortConnectSource(inputPortRef, endPointRef, NULL);
        if (err != noErr){
            NSLog(@"MIDIPortConnectSource err = %d", err);
            return;
        }
    }
}

- (IBAction)onFaderMiddle:(id)sender {
    [_sliderFader setDoubleValue:0.0];
    [self faderChanged:self];

}

- (IBAction)onFaderLeft:(id)sender {
    [_sliderFader setDoubleValue:-1.0];
    [self faderChanged:self];
}

@end
