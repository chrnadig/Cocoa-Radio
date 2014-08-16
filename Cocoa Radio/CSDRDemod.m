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
#import "CSDRRealArray.h"
#import "CSDRDemodAM.h"
#import "CSDRDemodWBFM.h"
#import "CSDRDemodNBFM.h"
#import "CSDRComplexLowPassFilter.h"
#import "CSDRRealLowPassFilter.h"

// private declarations
@interface CSDRDemod ()
@property (readwrite) double average;
@property (readwrite) struct dsp_context powerContext;
@end

@implementation CSDRDemod

// factory class method
+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme rfRate:(float)rfRate afRate:(float)afRate
{
    NSLog(@"have rates %f, %f", rfRate, afRate);
#warning replace with public constants, introduce method to query available modulations
    if ([scheme caseInsensitiveCompare:@"WBFM"] == NSOrderedSame) {
        return [[CSDRDemodWBFM alloc] initWithRFRate:rfRate AFRate:afRate];
    } else if ([scheme caseInsensitiveCompare:@"NBFM"] == NSOrderedSame) {
        return [[CSDRDemodNBFM alloc] initWithRFRate:rfRate AFRate:afRate];
    } else if ([scheme caseInsensitiveCompare:@"AM"] == NSOrderedSame) {
        return [[CSDRDemodAM alloc] initWithRFRate:rfRate AFRate:afRate];
    }
    return nil;
}

// designated initializer
- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super init]) {
        // Setup the intermediate frequency filter
        _ifFilter = [CSDRComplexLowPassFilter new];
        _ifFilter.gain = 1.0;
        // Setup the audio frequency filter
        _afFilter = [CSDRRealLowPassFilter new];
        _afFilter.gain = 0.5;
        // Setup the audio frequency rational resampler
        _afResampler = [CSDRResampler new];
        // Set default sample rates (this will set decimation and interpolation)
        _rfSampleRate = rfRate;
        _rfCorrectedRate = rfRate;
        _ifFilter.sampleRate = rfRate;
        _afSampleRate = afRate;
        // AF filter runs with RF sample rate (filter is done before resampling)!
        _afFilter.sampleRate = rfRate;
        _squelch = 0.0;
        _radioPower = [CSDRRealArray new];
        _average = NAN;
        // setup resampler
#warning this needs to go into resampler and should be automatic!
        [self calculateResampleRatio];
    }
    
    return self;
}

// demodulate sampled data
- (CSDRRealArray *)demodulateData:(CSDRComplexArray *)complexInput
{
    NSUInteger samples = complexInput.length;
    
    // Make sure that the temporary arrays are big enough
    if (self.radioPower.length < samples) {
        // allocate new array with larger size and copy contents from old buffer
        CSDRRealArray *oldRadioPower = self.radioPower;
        self.radioPower = [CSDRRealArray arrayWithLength:samples];
        // copy old contents, new space (zeroed) at end
        [self.radioPower copyFromArray:oldRadioPower length:oldRadioPower.length fromIndex:0 toIndex:0];
    }
    
    // Down convert
    CSDRComplexArray *baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    CSDRComplexArray *filtered = [self.ifFilter filter:baseBand];
    
    // Get an array of signal power levels for squelch
    getPower(filtered, self.radioPower, &_powerContext, .0001);
    
    // do modulation specific demodulation (implemented by subclasses)
    CSDRRealArray *demodulated = [self demodulateSpecific:filtered];
    
    // Remove any residual DC in the signal
    removeDC(demodulated, &_average, .001);
    
    // Audio Frequency filter
#warning should we rather do this after resampling in order to save processing power due to the lower sample rate? if so, correct sample rate of af filter in -init
    CSDRRealArray *audioFiltered = [self.afFilter filter:demodulated];
    
    // Iterate through the audio and mute sections that are too low for now, just use a manual squelch threshold
    const float *powerSamples = self.radioPower.realp;
    float *audioSamples = audioFiltered.realp;
    double newAverage = 0;
    
    for (int i = 0; i < samples; i++) {
        double powerSample = powerSamples[i];
        newAverage += powerSample / (double)samples;
        
        bool mute = (powerSample > self.squelch)? NO : YES;
        float audioSample = audioSamples[i];
        audioSamples[i] = (mute)? 0.0 : audioSample;
    }
    
    // Copy average power into the rfPower property
    COCOARADIO_DEMODAVERAGE((int)(self.rfPower * 1000));
    self.rfPower = newAverage * 10.0;
    
    // Rational resampling
    return [self.afResampler resample:audioFiltered];
}

// do modulation specific demodulation - this must be overridden in subclas, raise exception if called in base class
- (CSDRRealArray *)demodulateSpecific:(CSDRComplexArray *)input
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
#warning necessary?
- (void)setRfSampleRate:(float)rfSampleRate
{
    NSLog(@"rfrate = %f", rfSampleRate);
    // Assume corrected rate equals requested until known better
    _rfSampleRate = rfSampleRate;
    self.rfCorrectedRate = self.ifFilter.sampleRate = self.afFilter.sampleRate = rfSampleRate;
    [self calculateResampleRatio];
}

#warning necessary?
- (void)setAfSampleRate:(float)afSampleRate
{
    NSLog(@"afSampleRate = %f", afSampleRate);

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
    return 100.0;
}

@end
