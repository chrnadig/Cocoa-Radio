//
//  CSDRResampler.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSDRResampler : NSObject

@property (assign) NSInteger interpolator;
@property (assign) NSInteger decimator;
@property (assign) float lastSample;

- (void)resampleFrom:(NSData *)input to:(NSMutableData *)output;
- (NSData *)resample:(NSData *)input;

@end
