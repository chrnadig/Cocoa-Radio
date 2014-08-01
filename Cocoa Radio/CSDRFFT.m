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
#import "CSDRRealArray.h"
#import "CSDRComplexArray.h"
#import "dspprobes.h"

// private declarations
@interface CSDRFFT ()
@property (readwrite) CSDRComplexArray *buffer;
@end

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

        // allocate buffers
        _buffer = [CSDRComplexArray arraywithLength:initSize];
        _magBuffer = [CSDRRealArray arrayWithLength:initSize];
        
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
}

// this method retrieves the current FFT data, it finalizes the number of FFT operations and divides out the average
- (void)updateMagnitudeData
{
    if (self.counter > 0) {
        static const float B = 1.0;
        static const float C = 10.0;
        float fcounter = self.counter;
        vDSP_vsdiv(self.buffer.realp, 1, &fcounter, self.buffer.realp, 1, self.size);
        vDSP_vsdiv(self.buffer.imagp, 1, &fcounter, self.buffer.imagp, 1, self.size);
        vDSP_zvabs(self.buffer.complexp, 1, self.magBuffer.realp, 1, self.size);
        vDSP_vdbcon(self.magBuffer.realp, 1, &B, self.magBuffer.realp, 1, self.size, 0);
        vDSP_vsdiv(self.magBuffer.realp, 1, &C, self.magBuffer.realp, 1, self.size);

        if (COCOARADIO_FFTCOUNTER_ENABLED()) {
            COCOARADIO_FFTCOUNTER((int)self.counter);
        }

        self.counter = 0;
        [self.buffer clear];
    }
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
                while (self.realRingBuffer.fillLevel < 2048 || self.imagRingBuffer.fillLevel < 2048) {
#warning is this right?
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

- (void)addSamples:(CSDRComplexArray *)samples
{
    [self.lock lock];
    
#warning temporary, will be replaced by an implementation of a complex ring buffer!
    [self.realRingBuffer storeData:[NSData dataWithBytesNoCopy:samples.realp length:samples.length * sizeof(float) freeWhenDone:NO]];
    [self.imagRingBuffer storeData:[NSData dataWithBytesNoCopy:samples.imagp length:samples.length * sizeof(float) freeWhenDone:NO]];
    
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

#warning replace with vDSP_zvadd()
- (void)convertFFTandAccumulateReal:(NSMutableData *)real imag:(NSMutableData *)imag
{
    float *realData = [real mutableBytes];
    float *imagData = [imag mutableBytes];

    // accumulate this data with what came before it, and re-order the values
    NSUInteger halfSize = self.size / 2;
    vDSP_vadd(self.buffer.realp, 1, realData + halfSize, 1, self.buffer.realp, 1, halfSize);
    vDSP_vadd(self.buffer.imagp, 1, imagData + halfSize, 1, self.buffer.imagp, 1, halfSize);
    vDSP_vadd(self.buffer.realp + halfSize, 1, realData, 1, self.buffer.realp + halfSize, 1, halfSize);
    vDSP_vadd(self.buffer.imagp + halfSize, 1, imagData, 1, self.buffer.imagp + halfSize, 1, halfSize);
}

@end