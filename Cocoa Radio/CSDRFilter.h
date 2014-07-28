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
@property (readwrite) NSInteger sampleRate;
@property (readwrite) NSData *taps;
@property (readwrite) NSLock *tapsLock;

@end

@interface CSDRlowPassComplex : CSDRfilter

@property (assign) NSInteger bufferSize;
@property (strong) NSMutableData *realBuffer;
@property (strong) NSMutableData *imagBuffer;

- (NSDictionary *)filterDict:(NSDictionary *)input;

@end

@interface CSDRlowPassFloat : CSDRfilter

@property (assign) NSInteger bufferSize;
@property (strong) NSMutableData *buffer;

- (NSData *)filterData:(NSData *)input;

@end
