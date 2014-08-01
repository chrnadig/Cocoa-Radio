//
//  CSDRFFT.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRingBuffer, CSDRRealArray, CSDRComplexArray;

@interface CSDRFFT : NSObject

#warning move them to .m file
@property (readwrite) NSInteger counter;
@property (readwrite) NSInteger size;
@property (readwrite) NSInteger log2n;
@property (readwrite) CSDRRealArray *magBuffer;
@property (readwrite) NSCondition *lock;
@property (readwrite) NSThread *fftThread;
@property (readwrite) CSDRRingBuffer *realRingBuffer;
@property (readwrite) CSDRRingBuffer *imagRingBuffer;


- (id)initWithSize:(int)size;
- (void)addSamples:(CSDRComplexArray *)samples;
- (void)updateMagnitudeData;

@end
