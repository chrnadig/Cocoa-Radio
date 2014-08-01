//
//  dspRoutines.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/25/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>
#import "CSDRFilter.h"
#import "CSDRResampler.h"
#import "CSDRDemod.h"

@class AudioSink, CSDRComplexArray;

// data structure for DSP context
struct dsp_context {
    float floats[4];
};

double subtractTimes( uint64_t endTime, uint64_t startTime );

NSDictionary *freqXlate(CSDRComplexArray *inputData, float localOscillator, int sampleRate);
NSData *quadratureDemod(NSDictionary *inputDict, float gain, float offset);
NSDictionary *createComplexTone(int samples, float sampleRate, float frequency, float *lastPhase);

// Bootstrap the process by setting average = NAN
void removeDC(NSMutableData *data, double *average, double alpha);

// Calculate power level from the given signal (log 10)
void getPower(NSDictionary *input, NSMutableData *output, struct dsp_context *context, double alpha);
