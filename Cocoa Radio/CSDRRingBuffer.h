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

@property (strong) NSCondition *lock;
@property (strong) NSMutableData *data;
@property (assign) NSInteger head;
@property (assign) NSInteger tail;
@property (readonly) NSInteger fillLevel;
@property (readonly) NSInteger capacity;

- (id)initWithCapacity:(NSInteger)cap;

- (void)storeData:(NSData *)data;
- (void)fetchFrames:(int)nFrames into:(AudioBufferList *)ioData;
- (void)fillData:(NSMutableData *)data;

// Discard the contents
- (void)clear;

@end
