//
//  CSDRComplexBuffer.m
//  Cocoa Radio
//
//  Created by Christoph Nadig on 01.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import "CSDRComplexBuffer.h"
#import "CSDRComplexArray.h"

// private declarations
@interface CSDRComplexBuffer ()
@property (readwrite) NSCondition *lock;
@property (readwrite) float *space;
@property (readwrite) NSUInteger rp;
@property (readwrite) NSUInteger wp;
@property (readwrite) NSInteger fillLevel;
@end


@implementation CSDRComplexBuffer

// convencience constructor
+ (instancetype)bufferWithCapacity:(NSUInteger)capacity
{
    return [[self alloc] initWithCapacity:capacity];
}

// initializer
- (id)initWithCapacity:(NSInteger)capacity
{
    if (self = [super init]) {
        _lock = [NSCondition new];
        // array of reals first, the array of imags
        _space = malloc(2 * capacity * sizeof(float));
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

// clear buffer
- (void)clear
{
    [self.lock lock];
    self.rp = self.wp = 0;
    [self.lock unlock];
}

// store data in the ring buffer
- (void)storeData:(CSDRComplexArray *)data
{
    float *rsrc = data.realp;
    float *isrc = data.imagp;
    NSUInteger n = data.length;
    
    [self.lock lock];
    while (n > 0) {
        // determine maximum size we can write - it's either all or up to the end of the buffer
        NSUInteger m = MIN(self.capacity - (self.wp % self.capacity), n);
        memcpy(&self.space[self.wp % self.capacity], rsrc, m * sizeof(float));
        memcpy(&self.space[(self.wp % self.capacity) + self.capacity], isrc, m * sizeof(float));
        self.wp += m;
        rsrc += m;
        isrc += m;
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

// fill inputData with data from ring buffer
- (void)fillData:(CSDRComplexArray *)data
{
    float *rdst = data.realp;
    float *idst = data.imagp;
    NSUInteger n = data.length;
    
    [self.lock lock];
    while (n > 0) {
        // determine maximum size we can read - it's either all or up to the end of the buffer
        NSUInteger m = MIN(self.capacity - (self.rp % self.capacity), n);
        memcpy(rdst, &self.space[self.rp % self.capacity], m * sizeof(float));
        memcpy(idst, &self.space[(self.rp % self.capacity) + self.capacity], m * sizeof(float));
        self.rp += m;
        rdst += m;
        idst += m;
        n -= m;
    }
    // detect underrun
    if (self.rp > self.wp) {
        NSLog(@"Buffer underrun!");
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

@end
