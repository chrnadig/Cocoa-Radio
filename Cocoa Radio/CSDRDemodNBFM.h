//
//  CSDRDemodNBFM.h
//  Cocoa Radio
//
//  Created by William Dillon on 10/16/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemod.h"

@interface CSDRDemodNBFM : CSDRDemod

@property (readwrite) double average;
@property (readwrite) struct dsp_context powerContext;

@end
