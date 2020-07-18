//
//  AppController.h
//  MyPlaythrough
//
//  Created by kyab on 2017/05/15.
//  Copyright © 2017年 kyab. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AudioEngine.h"
#import "RingBuffer.h"
#import "RingView.h"
#import "TurnTableView.h"


@interface AppController : NSObject{
    AudioEngine *_ae;
    RingBuffer *_ring;
    __weak IBOutlet RingView *_ringView;
    __weak IBOutlet TurnTableView *_turnTable;
    

    __weak IBOutlet NSPopUpButton *_popupInputDevice;
    __weak IBOutlet NSPopUpButton *_popupOutputDevice;
    
    __weak IBOutlet NSButton *_chkSlip;
    __weak IBOutlet NSButton *_btnReverse;
    __weak IBOutlet NSButton *_btnTableStop;
    
    BOOL _reversePressing;
    
    __weak IBOutlet NSSlider *_sliderPitch;
    
    
    __weak IBOutlet NSButton *_btnTAP;
    __weak IBOutlet NSTextField *_lblBPM;
    NSMutableArray *_bpmHistory;
    double _bpm;
    NSTimeInterval _prevTAPTime;
    
    
    __weak IBOutlet NSButton *_btnLoop;
    BOOL _loopPressing;
    BOOL _loop;
    UInt32 _loopStartFrame;
    UInt32 _loopLength;
    UInt32 _writtenInLoop;
    
    
    float _conv_left[1024];
    float _conv_right[1024];
    
    BOOL _fadeRequired;
    BOOL _slip;
    
    NSTimer *_tableStopTimer;
    BOOL _tableStopped;
    
    
    Boolean _speedChanging;
    double _speedRate;

}

-(void)terminate;   //from AppDelegate

@end
