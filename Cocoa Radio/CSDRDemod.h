//
//  CSDRDemod.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRComplexLowPassFilter, CSDRRealLowPassFilter, CSDRResampler, CSDRComplexArray, CSDRRealArray;

@interface CSDRDemod : NSObject

@property (readwrite) CSDRComplexLowPassFilter *ifFilter;
@property (readwrite) CSDRRealLowPassFilter *afFilter;
@property (readwrite) CSDRResampler *afResampler;
@property (readwrite) CSDRRealArray *radioPower;
@property (readwrite, nonatomic) float rfSampleRate;
@property (readwrite, nonatomic) float afSampleRate;
@property (readwrite, nonatomic) float rfCorrectedRate;
@property (readwrite) float ifMinBandwidth;
@property (readwrite) float ifMaxBandwidth;
@property (readwrite) float afMinBandwidth;
@property (readwrite) float afMaxBandwidth;
@property (readwrite) float rfPower;
@property (readwrite) float centerFreq;
@property (readwrite) float ifBandwidth;
@property (readwrite) float ifSkirtWidth;
@property (readwrite) float afBandwidth;
@property (readwrite) float afSkirtWidth;
@property (readwrite) float afGain;
@property (readwrite) float rfGain;
@property (readwrite) float dmGain;
@property (readwrite) float squelch;

// factory class method
+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme;

// designated initializer
- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate;

// demodulate sampled data
- (NSData *)demodulateData:(CSDRComplexArray *)complexInput;

@end
