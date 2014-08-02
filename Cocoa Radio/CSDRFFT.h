//
//  CSDRFFT.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRealBuffer, CSDRRealArray, CSDRComplexArray, CSDRComplexBuffer;

@interface CSDRFFT : NSObject

@property (readonly) NSUInteger size;
@property (readonly) CSDRRealArray *magBuffer;

// initializer - size must be a power of 2
- (id)initWithSize:(NSUInteger)size;

// add signal samples
- (void)addSamples:(CSDRComplexArray *)samples;

@end
