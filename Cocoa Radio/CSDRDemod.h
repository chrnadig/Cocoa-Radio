//
//  CSDRDemod.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRlowPassComplex;
@class CSDRlowPassFloat;
@class CSDRResampler;

@interface CSDRDemod : NSObject

@property (strong) CSDRlowPassComplex *ifFilter;
@property (strong) CSDRlowPassFloat *afFilter;
@property (strong) CSDRResampler *afResampler;
@property (strong) NSMutableData *radioPower;
@property (assign, nonatomic) float rfSampleRate;
@property (assign, nonatomic) float afSampleRate;
@property (assign, nonatomic) float rfCorrectedRate;
@property (assign, readonly) float ifMinBandwidth;
@property (assign, readonly) float ifMaxBandwidth;
@property (assign, readonly) float afMinBandwidth;
@property (assign, readonly) float afMaxBandwidth;
@property (assign) float rfPower;
@property (assign) float centerFreq;
@property (assign) float ifBandwidth;
@property (assign) float ifSkirtWidth;
@property (assign) float afBandwidth;
@property (assign) float afSkirtWidth;
@property (assign) float afGain;
@property (assign) float rfGain;
@property (assign) float dmGain;
@property (assign) float squelch;

// factory class method
+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme;

// designated initializer
- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate;

// demodulate sampled data
- (NSData *)demodulateData:(NSDictionary *)complexInput;

@end
