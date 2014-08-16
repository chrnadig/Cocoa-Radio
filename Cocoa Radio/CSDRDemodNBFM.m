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
#warning have 500.0 here instead - probably only if AF filtering is done after resampling, otherwise CPU usage is too high!
        self.afFilter.skirtWidth =  5000.0;
        self.dmGain = 1.0;
    }
    return self;
}

// do modulation specific demodulation
- (CSDRRealArray *)demodulateSpecific:(CSDRComplexArray *)input
{
    // quadrature demodulation
    float dGain = self.dmGain + (self.rfSampleRate / (2 * M_PI * self.ifFilter.bandwidth));
    return quadratureDemod(input, dGain, 0.0);
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