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

- (id)initWithCapacity:(NSInteger)cap
{
    if (self = [super init]) {
        _lock = [[NSCondition alloc] init];
        _data = [[NSMutableData alloc] initWithLength:cap * sizeof(float)];
        _tail = _head = 0;
    }
    return self;
}

- (NSInteger)fillLevel
{
    NSInteger capacityFrames = [self.data length] / sizeof(float);
    return (self.head - self.tail + capacityFrames) % capacityFrames;
}

- (NSInteger)capacity
{
    return [self.data length] / sizeof(float);
}

- (void)clear
{
    self.head = self.tail = 0;
}

- (void)storeData:(NSData *)newData
{
    NSInteger overflowAmount;
    NSInteger capacityFrames;
    NSInteger newDataFrames;
    NSInteger usedBuffer;
    const float *inFloats;
    float *outFloats;

    [self.lock lock];
    // Determine whether we'll overflow the buffer.
    capacityFrames = [self.data length] / sizeof(float);
    newDataFrames  = [newData length] / sizeof(float);
    usedBuffer = self.head - self.tail;
    if (usedBuffer < 0) {
        usedBuffer += capacityFrames;
    }

    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFERFILL_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFERFILL((int)newDataFrames, (int)self.head, (int)self.tail);
    }

    overflowAmount = newDataFrames - (capacityFrames - usedBuffer);
    if (overflowAmount > 0) {
        NSLog(@"Ring buffer overflow");
    }
    
    // Do it the easy way
    outFloats = [self.data mutableBytes];
    inFloats = [newData bytes];
    for (NSInteger i = 0; i < newDataFrames; i++) {
        outFloats[self.head] = inFloats[i];
        self.head = (self.head + 1) % capacityFrames;
        // Detect overflow
        if (self.head == self.tail) {
            self.tail = (self.head + 1) % capacityFrames;
        }
    }
    
    [self.lock unlock];
    return;
}

- (void)fetchFrames:(int)nFrames into:(AudioBufferList *)ioData
{
    NSInteger capacityFrames;
    NSInteger filledFrames;
    NSInteger underrunFrames;
    NSInteger framesToEndOfBuffer;
    NSInteger toRead;
    NSInteger remainder;
    float *outFloats;
    float *bufferFloats;
    
    // Basic sanity checking
    if (ioData->mBuffers[0].mDataByteSize < nFrames * sizeof(float)) {
        NSLog(@"Not enough memory provided for requested frames.");
        return;
    }
    
    [self.lock lock];

    // If we're dealing with a buffer underrun zero-out all the missing data and make it fit within the buffer.
    capacityFrames = [self.data length] / sizeof(float);
    filledFrames = (self.head - self.tail + capacityFrames) % capacityFrames;
    outFloats = ioData->mBuffers[0].mData;
    bufferFloats = [self.data mutableBytes];

    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFEREMPTY_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFEREMPTY(nFrames, (int)self.head, (int)self.tail);
    }
    
    underrunFrames = nFrames - filledFrames;
    if (underrunFrames > 0) {
        NSLog(@"Buffer underrun!");
        nFrames -= underrunFrames;
    }
    
    // Was this a 0-byte read or a complete underrun?
    if (nFrames == 0) {
        [self.lock unlock];
        return;
    }
        
    // Now, we know that nFrames worth of data can be provided.
    // If the head has a greater index than the tail then the whole
    // buffer is linear in memory.  Therefore, the frames to the end
    // are simply head minus tail.
    framesToEndOfBuffer = self.head - self.tail;

    // If the tail is greater, then it wraps around in memory.  We
    // can only read until the end of the ring buffer, then start
    // again at the beginning
    if (framesToEndOfBuffer < 0) {
        framesToEndOfBuffer = capacityFrames - self.tail;
    }

    // Even if there's lots of data to the end of the buffer, we only
    // want to read the number of requested frames (in indicies)
    toRead = MIN(framesToEndOfBuffer, nFrames);

    // Perform the read
    // this is to sanitize the buffer in case of underrun
    bzero(outFloats, nFrames * sizeof(float));
    memcpy(outFloats, &bufferFloats[self.tail], toRead * sizeof(float));
    
    // If we didn't complete the read because we wrapped around,
    // continue at the beginning
    remainder = nFrames - toRead;
    if (remainder > 0) {
        memcpy(&outFloats[toRead], bufferFloats, remainder * sizeof(float));
    }
    
    // Update the tail index
    self.tail = (self.tail + nFrames) % capacityFrames;
    
    [self.lock unlock];
}

// For now, a dumb copy.  Should call another function in the future
- (void)fillData:(NSMutableData *)inputData
{
    NSInteger capacityFrames;
    NSInteger filledFrames;
    NSInteger underrunFrames;
    NSInteger framesToEndOfBuffer;
    NSInteger toRead;
    NSInteger remainder;
    float *outFloats;
    float *bufferFloats;
    
    // Basic sanity checking
    int nFrames = (int)[inputData length] / sizeof(float);
    
    [self.lock lock];
    
    // If we're dealing with a buffer underrun zero-out all the missing
    // data and make it fit within the buffer.
    capacityFrames = [self.data length] / sizeof(float);
    filledFrames = (self.head - self.tail + capacityFrames) % capacityFrames;
    outFloats = [inputData mutableBytes];
    bufferFloats = [self.data mutableBytes];
    
    // DTrace it
    if (COCOARADIOAUDIO_RINGBUFFEREMPTY_ENABLED()) {
        COCOARADIOAUDIO_RINGBUFFEREMPTY(nFrames, (int)self.head, (int)self.tail);
    }
    
    underrunFrames = nFrames - filledFrames;
    if (underrunFrames > 0) {
        NSLog(@"Buffer underrun!");
        nFrames -= underrunFrames;
    }
    
    // Was this a 0-byte read or a complete underrun?
    if (nFrames == 0) {
        [self.lock unlock];
        return;
    }
    
    // Now, we know that nFrames worth of data can be provided.
    // If the head has a greater index than the tail then the whole
    // buffer is linear in memory.  Therefore, the frames to the end
    // are simply head minus tail.
    framesToEndOfBuffer = self.head - self.tail;
    
    // If the tail is greater, then it wraps around in memory.  We
    // can only read until the end of the ring buffer, then start
    // again at the beginning
    if (framesToEndOfBuffer < 0) {
        framesToEndOfBuffer = capacityFrames - self.tail;
    }
    
    // Even if there's lots of data to the end of the buffer, we only
    // want to read the number of requested frames (in indicies)
    toRead = MIN(framesToEndOfBuffer, nFrames);
    
    // Perform the read
    // this is to sanitize the buffer in case of underrun
    bzero(outFloats, nFrames * sizeof(float));
    memcpy(outFloats, &bufferFloats[self.tail], toRead * sizeof(float));
    
    // If we didn't complete the read because we wrapped around,
    // continue at the beginning
    remainder = nFrames - toRead;
    if (remainder > 0) {
        memcpy(&outFloats[toRead], bufferFloats, remainder * sizeof(float));
    }
    
    // Update the tail index
    self.tail = (self.tail + nFrames) % capacityFrames;
    
    [self.lock unlock];

}

@end
