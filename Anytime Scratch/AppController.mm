//
//  AppController.m
//  MyPlaythrough
//
//  Created by kyab on 2017/05/15.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import "AppController.h"
#import "AudioToolbox/AudioToolbox.h"

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
    
    
}

-(void)terminate{
    [_ae stopOutput];

    [_ae stopInput];
    [_ae restoreSystemOutputDevice];
    
}


- (OSStatus) outCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    static BOOL printNumFrames = NO;
    if (!printNumFrames){
        NSLog(@"outCallback NumFrames = %d", inNumberFrames);
        printNumFrames = YES;
    }
    
    if (![_ae isPlaying]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        return noErr;
    }
    
    if (_tableStopped){
        float *leftPtr = [_ring readPtrLeft];
        float *rightPtr = [_ring readPtrRight];
        
        if (!leftPtr || !rightPtr){
            //not enough buffer
            //zero output
            NSLog(@"SUDDEN ZERO");
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
            NSLog(@"SUDDEN ZERO");
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
                if (rightPtr[i] < -1.0 || rightPtr[i] > 1.0){
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
            NSLog(@"SUDDEN ZERO");
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
    

    if ( 0!=ret ){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed AudioUnitRender err=%d(%@)", ret, [err description]);
        return ret;
    }
    
    if ([_ae isRecording]){
        [_ring advanceWritePtrSample:inNumberFrames];
    }
    
    return noErr;
    
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
    if (rate >= 0){
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
        
        _conv_left[targetSample] = y_l;
        _conv_right[targetSample] = y_r;
        *consumed = x1;
    }
    
}

-(void)convertAtRateMinusFromLeft:(float *)leftPtr right:(float *)rightPtr ToSamples:(UInt32)inNumberFrames rate:(double)rate consumedFrames:(SInt32 *)consumed{
    
    *consumed = 0;
    
    for (int targetSample = 0 ; targetSample < inNumberFrames;targetSample++){
        int x0 = ceil(targetSample*rate);
        int x1 = floor(targetSample*rate);
        
        float y0_l = *(leftPtr + x0);
        float y1_l = *(leftPtr + x1);
        float y_l = linearInterporation(x0, y0_l, x1, y1_l, targetSample*rate);

        float y0_r = *(rightPtr + x0);
        float y1_r = *(rightPtr + x1);
        float y_r = linearInterporation(x0, y0_r, x1, y1_r, targetSample*rate);
        
        _conv_left[targetSample] = y_l;
        _conv_right[targetSample] = y_r;
        *consumed = x1;
        
    }
}

double fadeInFactor(UInt32 offset){
    if (offset < 200){
        return 1/200.0*offset;
    }else{
        return 1.0;
    }
}

double fadeOutFactor(UInt32 offset){
    if (offset < 200){
        return 1/200.0 * offset;
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

@end
