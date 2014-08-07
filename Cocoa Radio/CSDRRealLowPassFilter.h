//
//  CSDRRealLowPassFilter.h
//  Cocoa Radio
//
//  Created by Christoph Nadig on 02.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSDRFilter.h"

@interface CSDRRealLowPassFilter : CSDRFilter

// filter input data with current settings and return a new array
- (CSDRRealArray *)filter:(CSDRRealArray *)input;

@end
