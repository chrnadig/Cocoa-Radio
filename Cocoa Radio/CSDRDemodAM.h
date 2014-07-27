//
//  CSDRDemodAM.h
//  Cocoa Radio
//
//  Created by William Dillon on 10/15/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "CSDRDemod.h"

@interface CSDRDemodAM : CSDRDemod

@property (assign) double average;
@property (assign) struct dsp_context powerContext;

@end
