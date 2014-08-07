//
//  CSDRDemodNBFM.m
//  Cocoa Radio
//
//  Created by William Dillon on 10/16/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemodNBFM.h"
#import "CSDRComplexArray.h"
#import "CSDRComplexLowPassFilter.h"
#import "CSDRRealLowPassFilter.h"
#import "dspRoutines.h"
#import "dspprobes.h"

@implementation CSDRDemodNBFM

- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super initWithRFRate:rfRate AFRate:afRate]) {
        self.ifBandwidth  = 11500.0;
        self.ifSkirtWidth =  5000.0;
        self.ifFilter.gain = 5.0;
        self.afFilter.bandwidth  = 18000.0;
        self.afFilter.skirtWidth =  5000.0;
        self.dmGain = 1.0;
        _average = NAN;
    }
    return self;
}

- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

- (CSDRRealArray *)demodulateData:(CSDRComplexArray *)complexInput
{
#if 0
    // Make sure that the temporary arrays are big enough
    NSUInteger samples = complexInput.length;
    if ([self.radioPower length] < (samples * sizeof(float))) {
        [self.radioPower setLength:samples * sizeof(float)];
    }
    
    // Down convert
    NSDictionary *baseBand;
    baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    NSDictionary *filtered;
    filtered = [self.ifFilter filterDict:baseBand];
    
    // Get an array of signal power levels for squelch
    getPower(filtered, self.radioPower, &_powerContext, .0001);
    
    // Quadrature demodulation
    float dGain = self.dmGain + self.rfSampleRate / (2 * M_PI * self.ifFilter.bandwidth);
    NSMutableData *demodulated;
    demodulated = (NSMutableData *)quadratureDemod(filtered, dGain, 0.);
    
    // Remove any residual DC in the signal
    removeDC(demodulated, &_average, .003);
    
    // Audio Frequency filter
    NSMutableData *audioFiltered;
    audioFiltered = (NSMutableData *)[self.afFilter filterData:demodulated];
    
    // Iterate through the audio and mute sections that are too low
    // for now, just use a manual squelch threshold
    
    const float *powerSamples = [self.radioPower bytes];
    float *audioSamples = [audioFiltered mutableBytes];
    double newAverage = 0;

    for (int i = 0; i < samples; i++) {
        double powerSample = powerSamples[i];
        newAverage += powerSample / (double)samples;
        
        bool mute = (powerSample > self.squelch)? NO : YES;
        float audioSample = audioSamples[i];
        audioSamples[i] = (mute)? 0. : audioSample;
    }

    // Copy average power into the rfPower property
    COCOARADIO_DEMODAVERAGE((int)(self.rfPower * 1000));
    self.rfPower = newAverage * 10.0;
    
    // Rational resampling
    return [self.afResampler resample:audioFiltered];
#else
    return nil;
#endif
}

// accessors for read-only properties
- (float)ifMinBandwidth
{
    return 5000.0;
}

- (float)ifMaxBandwidth
{
    return 50000.0;
}

- (float)afMaxBandwidth
{
    return 18000.0;
}

@end