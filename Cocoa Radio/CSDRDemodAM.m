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
#import "CSDRComplexLowPassFilter.h"
#import "CSDRRealLowPassFilter.h"

@implementation CSDRDemodAM

- (id)initWithRFRate:(float)rfRate AFRate:(float)afRate
{
    if (self = [super initWithRFRate:rfRate AFRate:afRate]) {
        self.ifFilter.bandwidth  = 90000.0;
        self.ifFilter.skirtWidth = 20000.0;
        self.ifFilter.gain = 1.0;
#warning bandwith should probably be 9000.0 and skirwidth about 500.0
        self.afFilter.bandwidth  = 18000.0;
#warning have 500.0 here instead - probably only if AF filtering is done after resampling, otherwise CPU usage is too high!
        self.afFilter.skirtWidth = 10000.0;
        self.afFilter.gain = 0.5;
    }
    
    return self;
}

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
