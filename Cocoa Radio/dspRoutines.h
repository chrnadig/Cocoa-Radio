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
#warning replace with CSDRRealArray?
struct dsp_context {
    float floats[4];
};

CSDRComplexArray *freqXlate(CSDRComplexArray *inputData, float localOscillator, int sampleRate);
CSDRRealArray *quadratureDemod(CSDRComplexArray *input, float gain, float offset);

// Bootstrap the process by setting average = NAN
void removeDC(CSDRRealArray *input, double *average, double alpha);

// Calculate power level from the given signal (log 10)
void getPower(CSDRComplexArray *input, CSDRRealArray *output, struct dsp_context *context, double alpha);
