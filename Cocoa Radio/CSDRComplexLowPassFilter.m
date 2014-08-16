//
//  CSDRComplexLowPassFilter.m
//  Cocoa Radio
//
//  Created by Christoph Nadig on 02.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRComplexLowPassFilter.h"
#import "CSDRComplexArray.h"
#import "CSDRRealArray.h"

// private declarations
@interface CSDRComplexLowPassFilter ()
@property (readwrite) CSDRComplexArray *buffer;
@end

@implementation CSDRComplexLowPassFilter

- (CSDRComplexArray *)filter:(CSDRComplexArray *)input
{
    // self.taps may change while this method executes, take a local copy
    CSDRRealArray *taps = self.taps;
    if (taps != nil) {
        CSDRComplexArray *output = [CSDRComplexArray arrayWithLength:input.length];
        CSDRComplexArray *temp = [CSDRComplexArray arrayWithLength:input.length + taps.length];

        // Modify the buffer (if necessary) - initially, self.buffer is nil, which works fine here
        if (taps.length > self.buffer.length) {
            // Only change the buffer if the number of taps increases. We want to increase the size of the buffer, but it's
            // important to ensure that the contents are maintained. The additional data (zeros) should go at the head
            CSDRComplexArray *oldBuffer = self.buffer;
            self.buffer = [CSDRComplexArray arrayWithLength:taps.length];
            [self.buffer copyFromArray:oldBuffer length:oldBuffer.length fromIndex:0 toIndex:self.buffer.length - oldBuffer.length];
        }
        
        // Copy the buffer contents into the temp array
        [temp copyFromArray:self.buffer length:self.buffer.length fromIndex:0 toIndex:0];
        
        // Copy the input into the temp array
        [temp copyFromArray:input length:input.length fromIndex:0 toIndex:self.buffer.length];
        
        // FIR filtering
        vDSP_conv(temp.realp, 1, taps.realp, 1, output.realp, 1, input.length, taps.length);
        vDSP_conv(temp.imagp, 1, taps.realp, 1, output.imagp, 1, input.length, taps.length);

        // Refresh the contents of the buffer
        // We need to keep the same number of samples as the number of taps
#warning should be able to copy from input? only if vDSP_conv was done out of place!
        [self.buffer copyFromArray:temp length:self.buffer.length fromIndex:input.length toIndex:0];
        
        // Return the results
        return output;
    }
    NSLog(@"%@: Attempting low-pass filter before configuration", NSStringFromClass([self class]));
    return nil;
}

@end
