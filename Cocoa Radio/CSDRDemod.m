//
//  CSDRDemod.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "dspRoutines.h"
#import "dspprobes.h"
#import "CSDRComplexArray.h"
#import "CSDRDemodAM.h"
#import "CSDRDemodWBFM.h"
#import "CSDRDemodNBFM.h"

@implementation CSDRDemod

// factory class method
+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme
{
    if ([scheme caseInsensitiveCompare:@"WBFM"] == NSOrderedSame) {
        return [CSDRDemodWBFM new];
    } else if ([scheme caseInsensitiveCompare:@"NBFM"] == NSOrderedSame) {
        return [CSDRDemodNBFM new];
    } else if ([scheme caseInsensitiveCompare:@"AM"] == NSOrderedSame) {
        return [CSDRDemodAM new];
    }
    return nil;
}

// designated initializer
- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super init]) {
        // Setup the intermediate frequency filter
        _ifFilter = [CSDRlowPassComplex new];
        _ifFilter.gain = 1.0;
        // Setup the audio frequency filter
        _afFilter = [CSDRlowPassFloat new];
        _afFilter.gain = 0.5;
        // Setup the audio frequency rational resampler
        _afResampler = [CSDRResampler new];
        // Set default sample rates (this will set decimation and interpolation)
        _rfSampleRate = rfRate;
        _rfCorrectedRate = rfRate;
        _ifFilter.sampleRate = rfRate;
        _afSampleRate = afRate;
        _afFilter.sampleRate = afRate;
        // Assume nyquist for the AFFilter
        _afFilter.bandwidth  = afRate / 2.0;
        _afFilter.skirtWidth = 10000.0;
        _squelch = 0.0;
        _radioPower = [NSMutableData new];
    }
    
    return self;
}

// Just do the above initialization with some defaults
- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

// demodulate sampled data
- (NSData *)demodulateData:(CSDRComplexArray *)complexInput
{
    [[NSException exceptionWithName:@"CSDRDemodException" reason:@"Demodulating in the base class!" userInfo:nil] raise];
    return nil;
}

#pragma mark Utility routines
int gcd(int a, int b) {
    if (a == 0) return b;
    if (b == 0) return a;
    
    if (a > b) return gcd(a - b, b);
    else       return gcd(a, b - a);
}

- (void)calculateResampleRatio
{
    // Get the GCD between sample rates (makes ints)
    int GCD = gcd(self.rfCorrectedRate, self.afSampleRate);
#warning replace with input/output rate instead of interpolator and decimator?
    self.afResampler.interpolator = self.afSampleRate / GCD;
    self.afResampler.decimator = self.rfCorrectedRate / GCD;
    if (self.afResampler.decimator == 0) {
        NSLog(@"Setting decimator to 0!");
    }
}

#pragma mark Getters and Setters
- (void)setRfSampleRate:(float)rfSampleRate
{
    // Assume corrected rate equals requested until known better
    _rfSampleRate = rfSampleRate;
    self.rfCorrectedRate = self.ifFilter.sampleRate = self.afFilter.sampleRate = rfSampleRate;
    [self calculateResampleRatio];
}

- (void)setAfSampleRate:(float)afSampleRate
{
    _afSampleRate = afSampleRate;
    [self calculateResampleRatio];
}

- (void)setIfBandwidth:(float)ifBandwidth
{
    self.ifFilter.bandwidth = ifBandwidth;
}

- (float)ifBandwidth
{
    return self.ifFilter.bandwidth;
}

- (void)setIfSkirtWidth:(float)ifSkirtWidth
{
    self.ifFilter.skirtWidth = ifSkirtWidth;
}

- (float)ifSkirtWidth
{
    return self.ifFilter.skirtWidth;
}

- (void)setAfBandwidth:(float)afBandwidth
{
    self.afFilter.bandwidth = afBandwidth;
}

- (float)afBandwidth
{
    return self.afFilter.bandwidth;
}

- (void)setAfSkirtWidth:(float)afSkirtWidth
{
    self.afFilter.skirtWidth = afSkirtWidth;
}

- (float)afSkirtWidth
{
    return self.afFilter.skirtWidth;
}

- (float)rfGain
{
    return self.ifFilter.gain;
}

- (void)setRfGain:(float)rfGain
{
    self.ifFilter.gain = rfGain;
}

- (float)afGain
{
    return self.afFilter.gain;
}

- (void)setAfGain:(float)afGain
{
    self.afFilter.gain = afGain;
}

- (float)ifMaxBandwidth
{
    return 100000000.0;
}

- (float)ifMinBandwidth
{
    return 1000.0;
}

- (float)afMaxBandwidth
{
    return self.afSampleRate / 2.0;
}

- (float)afMinBandwidth
{
    return 1000.0;
}

@end
