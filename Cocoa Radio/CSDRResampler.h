//
//  CSDRResampler.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRealArray;

@interface CSDRResampler : NSObject

@property (readwrite) NSInteger interpolator;
@property (readwrite) NSInteger decimator;
@property (readwrite) float lastSample;

- (CSDRRealArray *)resample:(CSDRRealArray *)input;

@end
