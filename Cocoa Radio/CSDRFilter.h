//
//  CSDRFilter.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSDRfilter : NSObject

@property (readwrite, nonatomic) float bandwidth;
@property (readwrite, nonatomic) float skirtWidth;
@property (readwrite, nonatomic) float gain;
@property (readwrite, nonatomic) NSInteger sampleRate;

@end

@interface CSDRlowPassComplex : CSDRfilter

- (NSDictionary *)filterDict:(NSDictionary *)input;

@end

@interface CSDRlowPassFloat : CSDRfilter

- (NSData *)filterData:(NSData *)input;

@end
