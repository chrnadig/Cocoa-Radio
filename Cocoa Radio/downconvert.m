//
//  downconvert.c
//  Cocoa Radio
//
//  Created by William Dillon on 6/25/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <mach/mach_time.h>
#import "CSDRComplexArray.h"
#import "CSDRRealArray.h"
#import "dspRoutines.h"

//#define ACCELERATE_POWER

// This function first "mixes" the input frequency with a local oscillator .The effect of this is that the desired frequency is moved to 0 Hz.
// Then, the band is low-pass filtered to eliminate unwanted signals. No decimation is performed at this point.
CSDRComplexArray *freqXlate(CSDRComplexArray *inputData, float localOscillator, int sampleRate)
{
    static float lastPhase = 0.0;
    float delta_phase = localOscillator / sampleRate;
    int length = (int)inputData.length;
    CSDRComplexArray *result = [CSDRComplexArray arrayWithLength:length];
    CSDRComplexArray *coeff = [CSDRComplexArray arrayWithLength:length];;
    
    // caculate the coefficents array
#warning maybe use lookup table?
    float *phase = malloc(length * sizeof(float));
    coeff = [CSDRComplexArray arrayWithLength:length];
    if (phase != NULL) {
        for (int i = 0; i < length; i++) {
            phase[i] = delta_phase * i + lastPhase;
            phase[i] = fmod(phase[i], 1.0) * 2.0 * M_PI;
        }
        // vectorized cosine and sines
        vvsinf(coeff.realp, phase, &length);
        vvcosf(coeff.imagp, phase, &length);
        free(phase);;
    }
    lastPhase = fmod(length * delta_phase + lastPhase, 1.0);
    
    // vectorized complex multiplication
#warning use coeff or inputData for result instead of new allocation!
    vDSP_zvmul(inputData.complexp, 1, coeff.complexp, 1, result.complexp, 1, length, 1);
    return result;
}

CSDRRealArray *quadratureDemod(CSDRComplexArray *input, float gain, float offset)
{
    static float lastReal = 0.0;
    static float lastImag = 0.0;
    
    int count = (int)input.length;
    
    CSDRRealArray *output = [CSDRRealArray arrayWithLength:input.length];
    CSDRComplexArray *result = [CSDRComplexArray arrayWithLength:input.length];

    // we'll copy the normalized input into another array, shifted to the right one element.  Then, we'll put the "lastsample"
    // into the head element.
    CSDRComplexArray *temp = [CSDRComplexArray arrayWithLength:input.length];
    temp.realp[0] = lastReal;
    temp.imagp[0] = lastImag;
    [temp copyFromArray:input length:input.length - 1 fromIndex:0 toIndex:1];
    
    // Vectorized complex multiplication
#warning can this be done in place?
    vDSP_zvmul(input.complexp, 1, temp.complexp, 1, result.complexp, 1, count, -1);
    
    // Vectorized angle computation
    vvatan2f(output.realp, result.realp, result.imagp, &count);
    
    // Vectorized gain multiplication
    vDSP_vsmsa(output.realp, 1, &gain, &offset, output.realp, 1, count);
    
    // save last value for next time
    lastReal = input.realp[count - 1];
    lastImag = input.imagp[count - 1];
    
    // Return the results
    return output;
}

void removeDC(CSDRRealArray *input, double *average, double alpha)
{
#if 0
    int length = (int)input.length;
    float *realSamples = [data mutableBytes];
    
    // Bootstrap DC offset correction and handle bad floats
    if (!isfinite(*average)) {
        *average = realSamples[0];
    }
    
    // Do the filter
    //TODO:  I should be able to use accelerate framework to speed this up
    for (int i = 0; i < length; i++) {
        *average = (*average * (1. - alpha)) + (realSamples[i] * alpha);
        realSamples[i] = realSamples[i] - *average;
    }
#else
    float m;
    vDSP_meanv(input.realp, 1, &m, input.length);
    *average = m;
    m = -m;
    vDSP_vsadd(input.realp, 1, &m, input.realp, 1, input.length);
    NSLog(@"average = %f", *average);
#endif
}

// requires a 4-element float context array
void getPower(CSDRComplexArray *input, CSDRRealArray *output, struct dsp_context *context, double alpha)
    {
        CSDRRealArray *tempInput = [CSDRRealArray arrayWithLength:input.length + 2];
        CSDRRealArray *tempOutput = [CSDRRealArray arrayWithLength:input.length + 2];
        
#warning fix accelerated version and use this one
#ifdef ACCELERATE_POWER
        float coeff[5] = {1.0 - alpha, 0.0, 0.0, -alpha, 0.0};
        // Calcluate the magnitudes from the input array (starting at index 2)
        vDSP_zvmags(input.complexp, 1, tempInput.realp + 2, 1, input.length);
        // Copy the context into the first two spots
        memcpy(tempInput.realp, &context->floats[0], 2 * sizeof(float));
        // Copy the context into the start of the output
        memcpy(tempOutput.realp, &context->floats[2], 2 * sizeof(float));
        
        // Setup the IIR as a 2 pole, 2 zero differential equation
        vDSP_deq22(tempInput.realp, 1, coeff, tempOutput.realp, 1, input.length);
        
        // Copy the context info out
        memcpy(&context->floats[0], tempInput.realp + input.length, 2 * sizeof(float));
        memcpy(&context->floats[2], tempOutput.realp + input.length, 2 * sizeof(float));
        
        // Calculate the dbs of the resuling value
        float zeroRef = 1.;
        vDSP_vdbcon(tempSamples, 1, &zeroRef, outSamples, 1, length, 0);
        
        // Copy the results into the output array
#warning this does nothing!
        memcpy(tempOutput, tempOutput, length * sizeof(float));
#else
        static const float zeroRef = 1.0;
        NSUInteger length = input.length;
        // Calcluate the magnitudes from the input array (starting at index 2)
#warning index 2?
        vDSP_zvmags(input.complexp, 1, tempInput.realp, 1, length);
        
        // Pre-multiply the magnitudes by alpha using accelerate
        float falpha = alpha;
        vDSP_vsmul(tempInput.realp, 1, &falpha, tempInput.realp, 1, length);
        
        // Compute the power average
        float average = context->floats[0];
        for (int i = 0; i < length; i++) {
            // Magnitude using sum of squares
            float magnitude = tempInput.realp[i];
            
            // Cheezy single-pole IIR low-pass filter
            average = average * (1.0 - alpha) + magnitude;
            tempOutput.realp[i] = average;
        }
        
        // compute the log-10 db
        vDSP_vdbcon(tempOutput.realp, 1, &zeroRef, output.realp, 1, length, 0);
        
        // book-keeping
        context->floats[0] = average;
#endif
}

