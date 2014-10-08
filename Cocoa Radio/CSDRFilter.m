//
//  CSDRFilter.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRFilter.h"
#import "CSDRRealArray.h"

@implementation CSDRFilter

- (id)init
{
    if (self = [super init]) {
        _sampleRate = _skirtWidth = _bandwidth = _gain = -1;
    }
    return self;
}

// This function is derived from the source for GNURadio available here:
//     http://gnuradio.org/redmine/projects/gnuradio/repository/revisions/master/entry/gr-filter/lib/firdes.cc
// It, like this project, is licensed under the GPL. This implementation is entirely independent and not copied.
// Only the mathematical constructs are the same. See here for more: http://en.wikipedia.org/wiki/Window_function#Hamming_window
- (void)computeTaps
{
#warning use vDSP functions like vDSP_hamm_window here
    // make sure we have everything we need
    if (self.sampleRate > 0.0 && self.skirtWidth > 0.0 && self.bandwidth > 0.0 && self.gain > 0.0 && self.skirtWidth < self.sampleRate / 2.0) {
        // Determine the number of taps required. Assume the Hamming window for now, which has a width factor of 3.3
        CSDRRealArray *newTaps;
        NSInteger M;
        NSInteger numTaps = 3.3 / (self.skirtWidth / self.sampleRate) + 0.5;    // width factor / (skirt width / sample rate) + 0.5
#warning float is probably ok here
        double fwT0 = 2 * M_PI * self.bandwidth / self.sampleRate;              // not sure what this really is, incorporated from GNURadio
        double fMax;
        float gain;
        
        // enfoce odd number of taps
        numTaps = (numTaps / 2) * 2 + 1;
        M = (numTaps - 1) / 2;
        
        // create an CSDRRealArray object to hold the taps (store only single-precision)
        newTaps = [CSDRRealArray arrayWithLength:numTaps];
        
        fMax = newTaps.realp[M] = fwT0 / M_PI;
        for (NSInteger i = 1; i <= M; i++) {
            // taps are symmetric (sin() is mirrored around 0 (sign is compensated by (i * M_PI)), cos() is symmetric arround M_PI
            newTaps.realp[M + i] = newTaps.realp[M - i] = sin(i * fwT0) / (i * M_PI) * (0.54 - 0.46 * cos(M_PI * (M + i) / M));
            fMax += 2 * newTaps.realp[M + i];
        }
        // normalization
        gain = self.gain / fMax;
        vDSP_vsmul(newTaps.realp, 1, &gain, newTaps.realp, 1, newTaps.length);

        // update the taps (no lock needed, synthesized accessors are atomic)
        self.taps = newTaps;
    }
}

- (void)setGain:(float)gain
{
    // Did it really change?
    if (gain != _gain) {
        _gain = gain;
        // re-compute the taps
        [self computeTaps];
    }
}

- (void)setBandwidth:(float)bandwidth
{
    // did it really change?
    if (bandwidth != _bandwidth) {
        if (self.sampleRate < 0.0) {
            _bandwidth = bandwidth;
            return;
        }
        if (bandwidth <= 0.0 || bandwidth  > self.sampleRate / 2.0) {
            NSLog(@"Filter bandwidth must be less than half sample rate and greater than zero.");
            return;
        }
        _bandwidth = bandwidth;
        // re-compute the taps
        [self computeTaps];
    }
}

- (void)setSkirtWidth:(float)skirtWidth
{
    // did it really change?
    if (skirtWidth != _skirtWidth) {
        if (skirtWidth > 0.0) {
            _skirtWidth = skirtWidth;
            // re-compute the taps
            [self computeTaps];
        } else {
            NSLog(@"Filter Skirt Width must be greater than zero!");
        }
    }
}

- (void)setSampleRate:(NSInteger)sampleRate
{
    // did it really change?
    if (sampleRate != _sampleRate) {
        if (sampleRate > 0.0) {
            _sampleRate = sampleRate;
            // re-compute the taps
            [self computeTaps];
        } else {
            NSLog(@"Sample rate must be greater than zero!");
        }
    }
}

// Print the taps
-(NSString *)description
{
    NSMutableString *outputString = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < self.taps.length; i++) {
        [outputString appendFormat:i != self.taps.length - 1 ? @"%f, " : @"%f", self.taps.realp[i]];
    }
    return outputString;
}

@end
