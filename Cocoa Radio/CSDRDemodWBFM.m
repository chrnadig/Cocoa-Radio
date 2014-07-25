//
//  CSDRDemodWBFM.m
//  Cocoa Radio
//
//  Created by William Dillon on 10/16/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemodWBFM.h"
#import "dspRoutines.h"
#import "dspprobes.h"

@implementation CSDRDemodWBFM

- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super initWithRFRate:rfRate AFRate:afRate]) {
        self.ifFilter.bandwidth  = 90000.0;
        self.ifFilter.skirtWidth = 20000.0;
        self.ifFilter.gain = 5.0;
        // Stereo WBFM Radio has a pilot tone at 19KHz.  It's better to
        // filter this signal out.  Therefore, we'll set the maximum af
        // frequency to 18 KHz + a 1KHz skirt width.
        self.afFilter.bandwidth  = 18000.0;
#warning shouldn't this be 1000.0 instead?
        self.afFilter.skirtWidth = 10000.0;
        self.dmGain = 1.0;
        _average = NAN;
    }
    
    return self;
}

- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    // Make sure that the temporary arrays are big enough
    int samples = (int)[complexInput[@"real"] length] / sizeof(float);
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
    getPower(filtered, self.radioPower, powerContext, .0001);
    
    // Quadrature demodulation
    float dGain = self.dmGain + (self.rfSampleRate / (2 * M_PI * self.ifFilter.bandwidth));
    NSMutableData *demodulated;
    demodulated = (NSMutableData *)quadratureDemod(filtered, dGain, 0.);
    
    // Remove any residual DC in the signal
    removeDC(demodulated, &_average, .001);
    
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
    
//    float duration = [complexInput[@"real"] length] / self.rfSampleRate;
//    return [[NSMutableData alloc] initWithLength:(self.afSampleRate * duration)];
    
    // Rational resampling
    return [self.afResampler resample:audioFiltered];
}

// accessors for read-only properties
- (float)ifMinBandwidth
{
    return   15000.0;
}

- (float)ifMaxBandwidth
{
    return  100000.0;
}

- (float)afMaxBandwidth
{
    return 18000.0;
}

@end

