//
//  CSDRFFT.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/29/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import "CSDRFFT.h"
#import "CSDRRealBuffer.h"
#import "CSDRRealArray.h"
#import "CSDRComplexArray.h"
#import "CSDRComplexBuffer.h"
#import "dspprobes.h"

// private declarations
@interface CSDRFFT ()
@property (readwrite) CSDRComplexArray *buffer;
@property (readwrite) FFTSetup fftSetup;
@property (readwrite) NSCondition *lock;
@property (readwrite) NSThread *fftThread;
@property (readwrite) CSDRComplexBuffer *ringBuffer;
@property (readwrite) CSDRRealArray *magBuffer;
@property (readwrite) NSInteger counter;
@property (readwrite) NSInteger log2n;
@end

@implementation CSDRFFT

// initializer - size must be a power of 2
- (id)initWithSize:(NSUInteger)initSize
{
    if (self = [super init]) {
        // Integer ivars
        _size = initSize;
        _log2n = log2(_size);
        if (exp2(_log2n) == _size) {
            _fftSetup = vDSP_create_fftsetup(_log2n, FFT_RADIX2);
            if (_fftSetup != NULL) {
                // allocate buffers
                _buffer = [CSDRComplexArray arrayWithLength:_size];
                _magBuffer = [CSDRRealArray arrayWithLength:_size];
                _ringBuffer = [CSDRComplexBuffer bufferWithCapacity:_size * 1024];
                // processing synchronization
                _lock = [NSCondition new];
                [_lock setName:@"com.us.alternet.cocoaradio.condition"];
                // worker thread
                _fftThread = [[NSThread alloc] initWithTarget:self selector:@selector(fftLoop) object:nil];
                [_fftThread setName:@"com.us.alternet.cocoaradio.fftthread"];
                [_fftThread start];
                // all good
                return self;
            }
        }
    }
    // something went wrong
    return nil;
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
        
        // allocate a new buffer to avoid race conditions with FFT display (accessors are atomic)
#warning is there maybe a better solution using locks?
        CSDRRealArray *newMagBuffer = [CSDRRealArray arrayWithLength:self.size];
        
        // calculate mag buffer values
        vDSP_vsdiv(self.buffer.realp, 1, &fcounter, self.buffer.realp, 1, self.size);
        vDSP_vsdiv(self.buffer.imagp, 1, &fcounter, self.buffer.imagp, 1, self.size);
        vDSP_zvabs(self.buffer.complexp, 1, newMagBuffer.realp, 1, self.size);
        vDSP_vdbcon(newMagBuffer.realp, 1, &B, newMagBuffer.realp, 1, self.size, 0);
        vDSP_vsdiv(newMagBuffer.realp, 1, &C, newMagBuffer.realp, 1, self.size);

        if (COCOARADIO_FFTCOUNTER_ENABLED()) {
            COCOARADIO_FFTCOUNTER((int)self.counter);
        }

        [self.buffer clear];
        self.magBuffer = newMagBuffer;
        self.counter = 0;
    }
}

- (void)fftLoop
{
    @autoreleasepool {
        
        CSDRComplexArray *input = [CSDRComplexArray arrayWithLength:self.size];
        CSDRComplexArray *output = [CSDRComplexArray arrayWithLength:self.size];
        NSUInteger halfSize = self.size / 2;

        // loop until thread is cancelled
        while (![self.fftThread isCancelled]) {
            
            @autoreleasepool {
                // Get some data from the ring buffer
                [self.lock lock];
                while (self.ringBuffer.fillLevel < self.size) {
#warning is this right?
                    [self updateMagnitudeData];
                    [self.lock wait];
                }
                
                // fill local buffer with data
                [self.ringBuffer fillData:input];
                [self.lock unlock];
                
                // Perform the FFT
                vDSP_fft_zop(self.fftSetup, input.complexp, 1, output.complexp, 1, self.log2n, FFT_FORWARD);

                // Convert the FFT format and accumulate
                vDSP_vadd(self.buffer.realp, 1, output.realp + halfSize, 1, self.buffer.realp, 1, halfSize);
                vDSP_vadd(self.buffer.imagp, 1, output.imagp + halfSize, 1, self.buffer.imagp, 1, halfSize);
                vDSP_vadd(self.buffer.realp + halfSize, 1, output.realp, 1, self.buffer.realp + halfSize, 1, halfSize);
                vDSP_vadd(self.buffer.imagp + halfSize, 1, output.imagp, 1, self.buffer.imagp + halfSize, 1, halfSize);

                // Advance the accumulation counter
                self.counter++;
            }
        }
    }
}

// add signal samples
- (void)addSamples:(CSDRComplexArray *)samples
{
    [self.lock lock];
    // store incoming data into ring buffer
    [self.ringBuffer storeData:samples];
    // notify reader thread about new data
    [self.lock signal];
    [self.lock unlock];
}

@end