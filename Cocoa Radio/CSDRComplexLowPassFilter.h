//
//  CSDRComplexLowPassFilter.h
//  Cocoa Radio
//
//  Created by Christoph Nadig on 02.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSDRFilter.h"

@class CSDRComplexArray;

@interface CSDRComplexLowPassFilter : CSDRFilter

// filter input data with current settings and return a new array
- (CSDRComplexArray *)filter:(CSDRComplexArray *)input;

@end
