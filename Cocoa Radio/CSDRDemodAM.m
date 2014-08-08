//
//  CSDRDemodAM.m
//  Cocoa Radio
//
//  Created by William Dillon on 10/15/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemodAM.h"
#import "CSDRComplexArray.h"
#import "CSDRRealArray.h"
#warning remove non needed imports!
#import "CSDRComplexLowPassFilter.h"
#import "CSDRRealLowPassFilter.h"
#import "dspRoutines.h"
#import "dspprobes.h"

@implementation CSDRDemodAM

- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super initWithRFRate:rfRate AFRate:afRate]) {
        self.ifFilter.bandwidth  = 90000.0;
        self.ifFilter.skirtWidth = 20000.0;
        self.ifFilter.gain = 1.0;
        self.afFilter.bandwidth  = 18000.0;
        self.afFilter.skirtWidth = 10000.0;
        self.afFilter.gain = 0.5;
        _average = NAN;
    }
    
    return self;
}

#warning remove!
- (id)init
{
    return [self initWithRFRate:2048000 AFRate:48000];
}

#if 0
- (CSDRRealArray *)demodulateData:(CSDRComplexArray *)complexInput
{
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
    
    // Get an array of signal power levels
    getPower(filtered, self.radioPower, &_powerContext, .0001);
    
    // Make a copy of the power for AM
    NSMutableData *demodulated = [self.radioPower mutableCopy];
    
    // Remove residual DC likely contributed from modulation depth
    removeDC(demodulated, &_average, .001);
    
    // Audio Frequency filter
    NSMutableData *audioFiltered;
    audioFiltered = (NSMutableData *)[self.afFilter filterData:demodulated];
    
    // Iterate through the audio and mute sections that are too low
    // for now, just use a manual squelch threshold
    
    const float *powerSamples = [self.radioPower bytes];
//    float *audioSamples = [audioFiltered mutableBytes];
    double newAverage = 0;
    
    for (int i = 0; i < samples; i++) {
        double powerSample = powerSamples[i];
        newAverage += powerSample / (double)samples;

//        bool mute = (powerSample > self.squelch)? NO : YES;
//        float audioSample = audioSamples[i];
//        audioSamples[i] = (mute)? 0. : (audioSample - 1.);
//        audioSamples[i] = audioSamples[i] / 30.;
    }

    // Copy average power into the rfPower property
    COCOARADIO_DEMODAVERAGE((int)(self.rfPower * 1000));
    self.rfPower = newAverage * 10.0;
    
    // Rational resampling
    return [self.afResampler resample:audioFiltered];
}
#endif

// do modulation specific demodulation
- (CSDRRealArray *)demodulateSpecific:(CSDRComplexArray *)input
{
    // AM demodulation - make a copy of RF power array
    CSDRRealArray *demodulated = [CSDRRealArray arrayWithLength:self.radioPower.length];
    [demodulated copyFromArray:self.radioPower length:demodulated.length fromIndex:0 toIndex:0];
    return demodulated;
}

// accessors for read-only properties
- (float)ifMinBandwidth
{
    return 15000.0;
}

- (float)ifMaxBandwidth
{
    return 100000.0;
}

- (float)afMaxBandwidth
{
    return 18000.0;
}

@end
