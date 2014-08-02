//
//  CSDRAudioDevice.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/30/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreAudio/AudioHardware.h>
#import <AudioUnit/AudioUnit.h>

@class CSDRRealBuffer;

@interface CSDRAudioDevice : NSObject

@property (readwrite) int sampleRate;
@property (readwrite) int blockSize;
@property (readonly) BOOL running;
@property (readwrite) int deviceID;
@property (readwrite) BOOL mute;

+ (NSArray *)deviceDict;

- (id)initWithRate:(float)sampleRate;

- (CSDRRealBuffer *)ringBuffer;

- (BOOL)prepare;
- (void)unprepare;

- (BOOL)start;
- (void)stop;

@end

@interface CSDRAudioOutput : CSDRAudioDevice
{
    BOOL discontinuity;
}

- (void)bufferData:(NSData *)data;

// This is used to mark a discontinuity, such as frequency change
// It's purpose is to discard packets in the buffer before the
// frequency change, then, when the buffer re-fills to 1/2 full,
// playing will resume.
- (void)markDiscontinuity;
- (BOOL)discontinuity;


@end