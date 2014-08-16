//
//  CSDRDemodWBFM.m
//  Cocoa Radio
//
//  Created by William Dillon on 10/16/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemodWBFM.h"
#import "CSDRComplexArray.h"
#import "CSDRRealArray.h"
#import "CSDRComplexLowPassFilter.h"
#import "CSDRRealLowPassFilter.h"
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
#warning have 1000.0 here instead - probably only if AF filtering is done after resampling, otherwise CPU usage is too high!
        self.afFilter.skirtWidth = 10000.0;
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

