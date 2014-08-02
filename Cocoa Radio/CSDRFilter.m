//
//  CSDRFilter.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRFilter.h"
#import "dspRoutines.h"

#define ACCELERATE

// private declarations
@interface CSDRFilter ()
@property (readwrite) NSData *taps;
@end

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
    // Make sure we have everything we need
    if (self.sampleRate <= 0.0 || self.skirtWidth <= 0.0 || self.bandwidth  <= 0.0 || self.gain == 0.0 || self.skirtWidth >= self.sampleRate / 2.0) {
        return;
    }
    
    // Determine the number of taps required.
    // Assume the Hamming window for now, which has a width factor of 3.3
    // Do all calculation at double precision
    
    // This block appears correct
    double widthFactor = 3.3;
    double deltaF = (self.skirtWidth / self.sampleRate);
    int numTaps = (int)(widthFactor / deltaF + .5);
    numTaps += (numTaps % 2 == 0)? 1 : 0; // Enfoce odd number of taps
    
    // Create an NSData object to hold the taps (store only single-precision)
    NSMutableData *tempTaps = [[NSMutableData alloc] initWithLength:numTaps * sizeof(float)];
    float *tapsData = [tempTaps mutableBytes];
    
    // Compute the window coefficients
    int filterOrder = numTaps - 1;
    double *window = malloc(numTaps * sizeof(double));
    for (int i = 0; i < numTaps; i++) {
        window[i] = 0.54 - 0.46 * cos((2 * M_PI * i) / filterOrder);
    }
    // I think the window looks right
    
    // Not sure what this really is, incorperated from GNURadio
    int M = filterOrder / 2;
    double fwT0 = 2 * M_PI * self.bandwidth / self.sampleRate;
    
    // Calculate the filter taps treat the center as '0'
    for (int i = -M; i <= M; i++) {
        if (i == 0) {
            tapsData[M] = fwT0 / M_PI * window[M];
        } else {
            tapsData[i + M] = sin(i * fwT0) / (i * M_PI) * window[i + M];
        }
    }
    
    double fMax = tapsData[M];
    for (int i = 0; i <= M; i++) {
        fMax += 2 * tapsData[i + M];
    }
    
    // Normalization
    double gain = self.gain / fMax;
    for (int i = 0; i < numTaps; i++) {
        tapsData[i] *= gain;
    }
    
    // Update the taps
    self.taps = tempTaps;
    
    free(window);
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
    NSData *taps = self.taps;
    NSUInteger num_taps = [taps length] / sizeof(float);
    const float *tapsData = [taps bytes];
    for (NSUInteger i = 0; i < num_taps; i++) {
        [outputString appendFormat:i != num_taps - 1 ? @"%f, " : @"%f", tapsData[i]];
    }
    return outputString;
}

@end


// private declarations
@interface CSDRComplexLowPassFilter ()
@property (readwrite) NSInteger bufferSize;
@property (readwrite) NSMutableData *realBuffer;
@property (readwrite) NSMutableData *imagBuffer;
@end

@implementation CSDRComplexLowPassFilter

- (instancetype)init
{
    if (self = [super init]) {
        _realBuffer = [NSMutableData new];
        _imagBuffer = [NSMutableData new];
    }
    return self;
}

- (NSDictionary *)filterDict:(NSDictionary *)inputDict

{
    if (self.taps == nil) {
        NSLog(@"Attempting low-pass filter before configuration");
    }
    
    NSData *realIn = inputDict[@"real"];
    NSData *imagIn = inputDict[@"imag"];
    
    if (realIn == nil || imagIn == nil) {
        NSLog(@"One or more input to freq xlate was nil");
        return nil;
    }
    
    if ([realIn length] != [imagIn length]) {
        NSLog(@"Size of real and imaginary data arrays don't match.");
    }
    
    // Modify the buffer (if necessary)
    // get self.taps to local variable in order to avoid a lock (accessor is atomic)
    NSData *taps = self.taps;
    NSUInteger newBufferSize = [taps length];
    if (newBufferSize > [self.realBuffer length]) {
        // Only change the buffer if the number of taps increases. We want to increase the size of the buffer, but it's
        // important to ensure that the contents are maintained. The additional data (zeros) should go at the head
        NSUInteger growth = newBufferSize - [self.realBuffer length];
        NSData *oldData = self.realBuffer;
        self.realBuffer = [NSMutableData dataWithLength:growth];
        [self.realBuffer appendData:oldData];
        
        oldData = self.imagBuffer;
        self.imagBuffer = [NSMutableData dataWithLength:growth];
        [self.imagBuffer appendData:oldData];
        
        self.bufferSize = newBufferSize;
    }
    
    int count    = (int)[realIn length]   / sizeof(float);
    int numTaps  = (int)[taps length]   / sizeof(float);
    int capacity = (count + numTaps) * sizeof(float);
    
    NSMutableData *realData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    NSMutableData *imagData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    
    COMPLEX_SPLIT result;
    result.realp  = (float *)[realData mutableBytes];
    result.imagp  = (float *)[imagData mutableBytes];
    
    if(result.realp == NULL || result.imagp == NULL ) {
        printf( "\nmalloc failed to allocate memory for the FIR.\n");
        return nil;
    }
    
    // Create temporary arrays for FIR processing
    float *real = malloc(capacity);
    float *imag = malloc(capacity);
    bzero(real, capacity);
    bzero(imag, capacity);
    
    // Copy the buffer contents into the temp array
    memcpy(real, [self.realBuffer bytes], [self.realBuffer length]);
    memcpy(imag, [self.imagBuffer bytes], [self.imagBuffer length]);
    
    // Copy the input into the temp array
    memcpy(&real[numTaps], [realIn bytes], [realIn length]);
    memcpy(&imag[numTaps], [imagIn bytes], [imagIn length]);
    
    // Real and imaginary FIR filtering
    const float *tapsData = [taps bytes];
    vDSP_conv(real, 1, tapsData, 1, result.realp, 1, count, numTaps);
    vDSP_conv(imag, 1, tapsData, 1, result.imagp, 1, count, numTaps);

    // Refresh the contents of the buffer
    // We need to keep the same number of samples as the number of taps
    memcpy([self.realBuffer mutableBytes], &real[count], numTaps * sizeof(float));
    memcpy([self.imagBuffer mutableBytes], &imag[count], numTaps * sizeof(float));
    
    free(real);
    free(imag);
    
    // Return the results
    return @{ @"real" : realData, @"imag" : imagData };
}

@end

// private declarations
@interface CSDRRealLowPassFilter ()
@property (readwrite) NSMutableData *buffer;
@end

@implementation CSDRRealLowPassFilter

- (NSData *)filterData:(NSData *)inputData
{
    if (self.taps == nil) {
        NSLog(@"Attempting low-pass filter before configuration");
    }
    
    if (inputData == nil) {
        NSLog(@"Input data was nil");
        return nil;
    }

    // Modify the buffer (if necessary)
    NSData *taps = self.taps;
    NSUInteger newBufferSize = [taps length];
    if (newBufferSize > [self.buffer length]) {
        // Only change the buffer if the number of taps increases. We want to increase the size of the buffer, but it's
        // important to ensure that the contents are maintained. The additional data (zeros) should go at the head
        NSData *oldData = self.buffer;
        self.buffer = [NSMutableData dataWithLength:newBufferSize - [oldData length]];
        [self.buffer appendData:oldData];
    }
    
    int count    = (int)[inputData length] / sizeof(float);
    int numTaps  = (int)[taps length] / sizeof(float);
    int capacity = (count + numTaps)  * sizeof(float);
    
    NSMutableData *outputData = [[NSMutableData alloc] initWithLength:sizeof(float) * count];
    float *outFloats  = (float *)[outputData mutableBytes];
    
    if (outFloats == NULL) {
        printf( "\nmalloc failed to allocate memory for the FIR.\n");
        return nil;
    }
    
    // Create temporary arrays for FIR processing
    float *temp = malloc(capacity);
    bzero(temp, capacity);
    
    // Copy the buffer contents into the temp array
    memcpy(temp, [self.buffer bytes], [self.buffer length]);
    
    // Copy the input into the temp array
    memcpy(&temp[numTaps], [inputData bytes], [inputData length]);
    
    // FIR filtering
    const float *tapsData = [taps bytes];
    vDSP_conv(temp, 1, tapsData, 1, outFloats, 1, count, numTaps);

    // Refresh the contents of the buffer
    // We need to keep the same number of samples as the number of taps
    memcpy([self.buffer mutableBytes], &temp[count], numTaps * sizeof(float));
    
    free(temp);
    
    // Return the results
    return outputData;
}

@end