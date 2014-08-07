//
//  CSDRFilter.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRFilter.h"
#import "CSDRRealArray.h"

@implementation CSDRFilter

- (id)init
{
    if (self = [super init]) {
        _sampleRate = -1;
        _skirtWidth = -1;
        _bandwidth = -1;
        _gain = 1;
    }
    return self;
}

// This function is derived from the source for GNURadio available here:
//     http://gnuradio.org/redmine/projects/gnuradio/repository/revisions/master/entry/gr-filter/lib/firdes.cc
// It, like this project, is licensed under the GPL. This implementation is entirely independent and not copied.
// Only the mathematical constructs are the same.
- (void)computeTaps
{
    // make sure we have everything we need
    if (self.sampleRate > 0.0 && self.skirtWidth > 0.0 && self.bandwidth > 0.0 && self.gain > 0.0 && self.skirtWidth < self.sampleRate / 2.0) {
        // Determine the number of taps required.
        // Assume the Hamming window for now, which has a width factor of 3.3
        // Do all calculation at double precision
        CSDRRealArray *newTaps;
        float *tapsData;
        double *window;
        double widthFactor = 3.3;
        double deltaF = (self.skirtWidth / self.sampleRate);
        int numTaps = widthFactor / deltaF + 0.5;
        
        // enfoce odd number of taps
        numTaps = (numTaps / 2) * 2 + 1;
        
        // create an CSDRRealArray object to hold the taps (store only single-precision)
        newTaps = [CSDRRealArray arrayWithLength:numTaps];
        tapsData = newTaps.realp;
        
        // allocate temporary space
        window = malloc(numTaps * sizeof(double));
        if (window != NULL) {
            // compute the window coefficients
            int filterOrder = numTaps - 1;
            int M = filterOrder / 2;
            double fMax;
            double gain;
            double fwT0 = 2 * M_PI * self.bandwidth / self.sampleRate;  // Not sure what this really is, incorporated from GNURadio

            for (int i = 0; i < numTaps; i++) {
                window[i] = 0.54 - 0.46 * cos((2 * M_PI * i) / filterOrder);
            }
        
            // Calculate the filter taps treat the center as '0'
            for (int i = -M; i <= M; i++) {
                if (i == 0) {
                    tapsData[M] = fwT0 / M_PI * window[M];
                } else {
                    tapsData[i + M] = sin(i * fwT0) / (i * M_PI) * window[i + M];
                }
            }

            fMax = tapsData[M];
            for (int i = 0; i <= M; i++) {
                fMax += 2 * tapsData[i + M];
            }
        
            // normalization
            gain = self.gain / fMax;
            for (int i = 0; i < numTaps; i++) {
                tapsData[i] *= gain;
            }
        
            // update the taps (no lock needed, synthesized accessors are atomic)
            self.taps = newTaps;
            free(window);
        }
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
