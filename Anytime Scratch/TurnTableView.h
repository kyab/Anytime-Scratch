//
//  TurnTableView.h
//  Fluent Scratch
//
//  Created by kyab on 2017/05/08.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol TurnTableDelegate <NSObject>
@optional
-(void)turnTableSpeedRateChanged;
@end


@interface TurnTableView : NSView{
    BOOL _pressing;
    double _currentRad;
    
    CGFloat _startOffsetRad;
    
    NSTimer *_timer;
    NSTimer *_timer2;   //scratch monitor
    
    NSTimeInterval _prevSec;
    double _prevRad;
    BOOL _prevRadValid;
    
    CGFloat _prevX;
    CGFloat _prevY;
    
    double _speedRate;
    
    BOOL _reverse;
    
    id<TurnTableDelegate> _delegate;
}

-(void)setDelegate:(id<TurnTableDelegate>)delegate;
-(void)start;
-(void)stop;
-(double)speedRate;
-(void)setReverse:(BOOL)reverse;
@end
