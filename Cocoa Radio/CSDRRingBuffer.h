//
//  CSDRRingBuffer.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/31/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreAudio/AudioHardware.h>
#import <AudioUnit/AudioUnit.h>

@interface CSDRRingBuffer : NSObject

@property (readonly) NSInteger fillLevel;
@property (readonly) NSInteger capacity;

- (id)initWithCapacity:(NSInteger)capacity;

- (void)storeData:(NSData *)data;
- (void)fetchFrames:(NSUInteger)nFrames into:(AudioBufferList *)ioData;
- (void)fillData:(NSMutableData *)data;

- (void)clear;

@end
