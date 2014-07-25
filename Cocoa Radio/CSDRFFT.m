//
//  CSDRFFT.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRFFT.h"
#import "CSDRRingBuffer.h"
#import "dspprobes.h"

@implementation CSDRFFT

- (id)initWithSize:(int)initSize
{
    if (self = [super init]) {
        // Integer ivars
        _size = initSize;
        _log2n = log2(_size);
        if (exp2(_log2n) != _size) {
            NSLog(@"Non power of 2 input size provided!");
            return nil;
        }

        // Allocate buffers
        _realBuffer = malloc(sizeof(double) * initSize);
        _imagBuffer = malloc(sizeof(double) * initSize);
        
        // Magnitude data
        _magBuffer = [[NSMutableData alloc] initWithLength:sizeof(float) * initSize];
        
        // Processing synchronization and thread
        _lock = [[NSCondition alloc] init];
        [_lock setName:@"FFT Ring buffer condition"];

        _fftThread = [[NSThread alloc] initWithTarget:self selector:@selector(fftLoop) object:nil];
        [_fftThread setName:@"com.us.alternet.cocoaradio.fftthread"];
        [_fftThread start];

        // Ring buffers
        _realRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:initSize * 1000];
        _imagRingBuffer = [[CSDRRingBuffer alloc] initWithCapacity:initSize * 1000];
    }
    
    return self;
}

- (void)dealloc
{
    [_fftThread cancel];
    free(_realBuffer);
    free(_imagBuffer);
}

// This function retreives the current FFT data
// It finalizes the number of FFT operations and divides out the average
- (void)updateMagnitudeData
{
    float *magValues = [self.magBuffer mutableBytes];

    if (self.counter == 0) {
        return;
    }
    
    for (int i = 0; i < self.size; i++) {
        // Compute the average
        double real = self.realBuffer[i] / self.counter;
        double imag = self.imagBuffer[i] / self.counter;
        
        // Compute the magnitude and put it in the mag array
        magValues[i] = sqrt((real * real) + (imag * imag));
        magValues[i] = log10(magValues[i]);
    }

    if (COCOARADIO_FFTCOUNTER_ENABLED()) {
        COCOARADIO_FFTCOUNTER((int)self.counter);
    }

    self.counter = 0;

    bzero(self.realBuffer, self.size * sizeof(double));
    bzero(self.imagBuffer, self.size * sizeof(double));
}

- (void)fftLoop
{
    @autoreleasepool {
        NSMutableData *inputRealData =  [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *inputImagData =  [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *outputRealData = [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        NSMutableData *outputImagData = [[NSMutableData alloc] initWithLength:2048 * sizeof(float)];
        
        // loop until thread is cancelled
        while (![self.fftThread isCancelled]) {
            @autoreleasepool {
                // Get some data from the ring buffer
                [self.lock lock];
                if (self.realRingBuffer.fillLevel < 2048 || self.imagRingBuffer.fillLevel < 2048) {
                    [self updateMagnitudeData];
                    [self.lock wait];
                }
                
                // Fill the imag and real arrays with data
                [self.realRingBuffer fillData:inputRealData];
                [self.imagRingBuffer fillData:inputImagData];
                [self.lock unlock];
                
                // Perform the FFT
                [self complexFFTinputReal:inputRealData
                                inputImag:inputImagData
                               outputReal:outputRealData
                               outputImag:outputImagData];
                
                // Convert the FFT format and accumulate
                [self convertFFTandAccumulateReal:outputRealData
                                             imag:outputImagData];
                
                // Advance the accumulation counter
                self.counter++;
            }
        }
    }
}

- (void)addSamplesReal:(NSData *)real imag:(NSData *)imag
{
    [self.lock lock];
    
    [self.realRingBuffer storeData:real];
    [self.imagRingBuffer storeData:imag];
    
    [self.lock signal];
    [self.lock unlock];
}

- (void)complexFFTinputReal:(NSData *)inReal
                  inputImag:(NSData *)inImag
                 outputReal:(NSMutableData *)outReal
                 outputImag:(NSMutableData *)outImag
{
    // Setup the Accelerate framework FFT engine
    static FFTSetup setup = NULL;
    if (setup == NULL) {
        // Setup the FFT system (accelerate framework)
        setup = vDSP_create_fftsetup(self.log2n, FFT_RADIX2);
        if (setup == NULL)
        {
            printf("\nFFT_Setup failed to allocate enough memory.\n");
            exit(0);
        }
    }
    
    // Check that the inputs are the right size
    NSInteger length = self.size * sizeof(float);
    if ([inReal length]  != length ||
        [inImag length]  != length ||
        [outReal length] != length ||
        [outImag length] != length) {
        NSLog(@"At least one input to the FFT is the wrong size");
        return;
    }
    
    // There aren't (to my knowledge) any const versions of this class
    // therefore, we have to cast with the knowledge that these arrays
    // are really consts.
    COMPLEX_SPLIT input;
    input.realp  = (float *)[inReal bytes];
    input.imagp  = (float *)[inImag bytes];
    
    COMPLEX_SPLIT output;
    output.realp  = (float *)[outReal mutableBytes];
    output.imagp  = (float *)[outImag mutableBytes];
    
    // Make sure that the arrays are accessible
    if (output.realp == NULL || output.imagp == NULL ||
        input.realp  == NULL || input.imagp  == NULL) {
        NSLog(@"Unable to access memory in the FFT function");
        return;
    }
    
    // Perform the FFT
    vDSP_fft_zop(setup, &input, 1, &output, 1, self.log2n, FFT_FORWARD );
}

- (void)convertFFTandAccumulateReal:(NSMutableData *)real
                               imag:(NSMutableData *)imag
{
    float *realData = [real mutableBytes];
    float *imagData = [imag mutableBytes];
    
    // Accumulate this data with what came before it, and re-order the values
    for (NSInteger i = 0; i <= self.size / 2; i++) {
        self.realBuffer[i] += realData[i + self.size / 2];
        self.imagBuffer[i] += imagData[i + self.size / 2];
    }
    
    for (NSInteger i = 0; i <  self.size / 2; i++) {
        self.realBuffer[i + self.size / 2] += realData[i];
        self.imagBuffer[i + self.size / 2] += imagData[i];
    }
}

@end