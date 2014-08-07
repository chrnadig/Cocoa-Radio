//
//  CSDRResampler.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#include <Accelerate/Accelerate.h>
#import "CSDRResampler.h"
#import "CSDRRealArray.h"

@implementation CSDRResampler

- (id)init
{
    if (self = [super init]) {
        _lastSample = 0.0;
        _interpolator = 1;
        _decimator = 1;
    }
    
    return self;
}

// The resampler functions by generating a set of virtual samples between the input samples, and selecting a subset of
// those as the output.
//
// The last sample instance variable contains the last sample of the previous block.  This is used for the first
// interpolation.
//
// A variety of interpolation algorithms could be used.  For now, a linear interpolation will be used.
- (CSDRRealArray *)resample:(CSDRRealArray *)input
{
    CSDRRealArray *output = [CSDRRealArray arrayWithLength:(input.length * self.interpolator) / self.decimator];
    const float *inputFloats = input.realp;
    float *outputFloats = output.realp;
    NSInteger inputSize  = input.length;
    NSInteger outputSize = output.length;
    
    // Perform the main loop for the resampler
    for (int i = 0; i < outputSize; i++) {
        NSInteger virtualSampleIndex = i * self.decimator;
        float inputSampleFloat = (float)virtualSampleIndex / (float)(self.interpolator);
        
        // For each output sample, compute its nearest input indices
        int highInputIndex = floorf(inputSampleFloat);
        int lowInputIndex  = highInputIndex - 1;
        
        // Calculate the proportion between the input
        float ratio = inputSampleFloat - highInputIndex;
        
        // Assign the result.  Special case for samples falling
        // the first sample of this block
        if (highInputIndex == 0) {
            outputFloats[i]  = self.lastSample * ratio;
            outputFloats[i] += inputFloats[highInputIndex] * (1.0 - ratio);
        } else {
            outputFloats[i]  = inputFloats[lowInputIndex]  * ratio;
            outputFloats[i] += inputFloats[highInputIndex] * (1.0 - ratio);
        }
    }
    
    // Save the last sample
    self.lastSample = inputFloats[inputSize - 1];
    return output;
}

@end
