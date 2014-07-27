//
//  CSDRRingBuffer.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/31/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "CSDRRingBuffer.h"
#include "audioprobes.h"

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
            _size = capacity;
            return self;
        }
    }
    // something went wrong
    return nil;
}

- (NSInteger)fillLevel
{
    return self.wp - self.rp;
}

- (NSInteger)capacity
{
    return self.size;
}

- (void)clear
{
    self.rp = self.wp = 0;
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
        NSUInteger m = MIN(self.size - (self.wp % self.size), n);
        memcpy(&self.space[self.wp % self.size], src, m * sizeof(float));
        self.wp += m;
        src += m;
        n -= m;
    }
    // detect overflow
    if (self.wp > self.rp + self.size) {
        NSLog(@"Buffer overrun!");
        self.rp = self.wp - self.size;
    }
    // keep rp and wp in the range of 0 to 2 * size - 1
    if (self.rp >= self.size) {
        NSUInteger offset = self.rp - (self.rp % self.size);
        self.rp -= offset;
        self.wp -= offset;
    }
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
        NSUInteger m = MIN(self.size - (self.rp % self.size), n);
        memcpy(dst, &self.space[self.rp % self.size], m * sizeof(float));
        self.rp += m;
        dst += m;
        n -= m;
    }
    // detect underrun
    if (self.rp > self.wp) {
        NSLog(@"Buffer underrun!");
#warning should we set underrun floats to 0?
        self.wp = self.rp;
    }
    // keep rp and wp in the range of 0 to 2 * size - 1
    if (self.rp >= self.size) {
        NSUInteger offset = self.rp - (self.rp % self.size);
        self.rp -= offset;
        self.wp -= offset;
    }
    
    [self.lock unlock];
}

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
