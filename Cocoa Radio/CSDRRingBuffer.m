//
//  CSDRRingBuffer.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/31/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRRingBuffer.h"
#include "audioprobes.h"

// private declarations
@interface CSDRRingBuffer ()
@property (readwrite) NSCondition *lock;
@property (readwrite) float *space;
@property (readwrite) NSUInteger rp;
@property (readwrite) NSUInteger wp;
@property (readwrite) NSInteger fillLevel;
@end

@implementation CSDRRingBuffer

- (id)init
{
    return [self initWithCapacity:1024 * 1024];
}

- (id)initWithCapacity:(NSInteger)capacity
{
    if (self = [super init]) {
        _lock = [NSCondition new];
        _space = malloc(capacity * sizeof(float));
        if (_space != NULL) {
            _capacity = capacity;
            return self;
        }
    }
    // something went wrong
    return nil;
}

- (void)dealloc
{
    free(_space);
}

- (void)clear
{
    [self.lock lock];
    self.rp = self.wp = 0;
    [self.lock unlock];
}

- (void)storeData:(NSData *)newData
{
    float *src = (float *)[newData bytes];
    NSUInteger n = [newData length] / sizeof(float);
    
    [self.lock lock];
    // DTrace it
#warning needed?
    if (COCOARADIOAUDIO_RINGBUFFERFILL_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFERFILL((int)n, (int)self.wp, (int)self.rp);
    }
    
    while (n > 0) {
        // determine maximum size we can write - it's either all or up to the end of the buffer
        NSUInteger m = MIN(self.capacity - (self.wp % self.capacity), n);
        memcpy(&self.space[self.wp % self.capacity], src, m * sizeof(float));
        self.wp += m;
        src += m;
        n -= m;
    }
    // detect overflow
    if (self.wp > self.rp + self.capacity) {
        NSLog(@"Buffer overrun!");
        self.rp = self.wp - self.capacity;
    }
    // keep rp and wp in the range of 0 to 2 * size - 1
    if (self.rp >= self.capacity) {
        NSUInteger offset = self.rp - (self.rp % self.capacity);
        self.rp -= offset;
        self.wp -= offset;
    }
    // update fillLevel
    self.fillLevel = self.wp - self.rp;
    [self.lock unlock];
}

// auxiliary method for public read methods
- (void)moveFrames:(NSUInteger)n to:(float *)dst
{
    [self.lock lock];
    // DTrace it
#warning needed?
    if (COCOARADIOAUDIO_RINGBUFFEREMPTY_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFEREMPTY((int)n, (int)self.wp, (int)self.rp);
    }

    while (n > 0) {
        // determine maximum size we can read - it's either all or up to the end of the buffer
        NSUInteger m = MIN(self.capacity - (self.rp % self.capacity), n);
        memcpy(dst, &self.space[self.rp % self.capacity], m * sizeof(float));
        self.rp += m;
        dst += m;
        n -= m;
    }
    // detect underrun
    if (self.rp > self.wp) {
        NSLog(@"Buffer underrun!");
        // zero out underrun values
        memset(dst + self.fillLevel, 0, n - self.fillLevel);
        self.wp = self.rp;
    }
    // keep rp and wp in the range of 0 to 2 * size - 1
    if (self.rp >= self.capacity) {
        NSUInteger offset = self.rp - (self.rp % self.capacity);
        self.rp -= offset;
        self.wp -= offset;
    }
    // update fillLevel
    self.fillLevel = self.wp - self.rp;
    [self.lock unlock];
}

#warning needed? or leave translations into audio buffers up to caller?
- (void)fetchFrames:(NSUInteger)n into:(AudioBufferList *)ioData
{
    // basic sanity checking
    if (ioData->mBuffers[0].mDataByteSize < n * sizeof(float)) {
        NSLog(@"Not enough memory provided for requested frames.");
        return;
    }
    [self moveFrames:n to:ioData->mBuffers[0].mData];
}

// fill inputData with data from ring buffer
- (void)fillData:(NSMutableData *)inputData
{
    [self moveFrames:[inputData length] / sizeof(float) to:[inputData mutableBytes]];
}

@end
