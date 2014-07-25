//
//  CSDRFFT.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRingBuffer;

@interface CSDRFFT : NSObject

@property (assign) double *realBuffer;
@property (assign) double *imagBuffer;
@property (assign) NSInteger counter;
@property (assign) NSInteger size;
@property (assign) NSInteger log2n;
@property (strong) NSMutableData *magBuffer;
@property (strong) NSCondition *lock;
@property (strong) NSThread *fftThread;
@property (strong) CSDRRingBuffer *realRingBuffer;
@property (strong) CSDRRingBuffer *imagRingBuffer;


- (id)initWithSize:(int)size;
- (void)addSamplesReal:(NSData *)real imag:(NSData *)imag;
- (void)updateMagnitudeData;

@end
