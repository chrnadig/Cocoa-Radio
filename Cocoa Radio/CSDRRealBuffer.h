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

@interface CSDRRealBuffer : NSObject

@property (readonly) NSInteger fillLevel;
@property (readonly) NSInteger capacity;

// convencience constructor
+ (instancetype)bufferWithCapacity:(NSUInteger)capacity;

// initializer
- (id)initWithCapacity:(NSInteger)capacity;

// store data in the ring buffer
- (void)storeData:(NSData *)data;

// fetch data into audio buffer
- (void)fetchFrames:(NSUInteger)nFrames into:(AudioBufferList *)ioData;

// fill data from ring buffer
- (void)fillData:(NSMutableData *)data;

// clear buffer
- (void)clear;

@end
