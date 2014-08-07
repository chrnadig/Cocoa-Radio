//
//  CSDRFilter.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRRealArray;

@interface CSDRFilter : NSObject

@property (readwrite, nonatomic) float bandwidth;
@property (readwrite, nonatomic) float skirtWidth;
@property (readwrite, nonatomic) float gain;
@property (readwrite, nonatomic) NSInteger sampleRate;
@property (readwrite) CSDRRealArray *taps;

@end
