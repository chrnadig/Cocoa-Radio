//
//  CSDRRealLowPassFilter.m
//  Cocoa Radio
//
//  Created by Christoph Nadig on 02.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRRealLowPassFilter.h"
#import "CSDRRealArray.h"

// private declarations
@interface CSDRRealLowPassFilter ()
@property (readwrite) CSDRRealArray *buffer;
@end

@implementation CSDRRealLowPassFilter

- (instancetype)init
{
    if (self = [super init]) {
        _buffer = [CSDRRealArray arrayWithLength:0];
    }
    return self;
}

- (CSDRRealArray *)filter:(CSDRRealArray *)input
{
    // self.taps may change while this method executes, take a local copy
    CSDRRealArray *taps = self.taps;
    if (taps != nil) {
        // Modify the buffer (if necessary)
        CSDRRealArray *output = [CSDRRealArray arrayWithLength:input.length];
        CSDRRealArray *temp = [CSDRRealArray arrayWithLength:input.length + taps.length];
        if (taps.length > self.buffer.length) {
            // Only change the buffer if the number of taps increases. We want to increase the size of the buffer, but it's
            // important to ensure that the contents are maintained. The additional data (zeros) should go at the head
            [self.buffer setLengthGrowingAtHead:taps.length];
        }
        
        // Copy the buffer contents into the temp array
        [self.buffer copyToArray:temp numElements:self.buffer.length fromIndex:0 toIndex:0];

        // Copy the input into the temp array
        [input copyToArray:temp numElements:input.length fromIndex:0 toIndex:self.buffer.length];
        
        // FIR filtering
        vDSP_conv(temp.realp, 1, taps.realp, 1, output.realp, 1, input.length, taps.length);
        
        // Refresh the contents of the buffer
        // We need to keep the same number of samples as the number of taps
        [temp copyToArray:self.buffer numElements:self.buffer.length fromIndex:input.length toIndex:0];
        
        // Return the results
        return output;
    }
    NSLog(@"%@: Attempting low-pass filter before configuration", NSStringFromClass([self class]));
    return nil;
}

@end