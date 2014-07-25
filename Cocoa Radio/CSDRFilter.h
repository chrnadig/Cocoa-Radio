//
//  CSDRFilter.h
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSDRfilter : NSObject

@property (assign, nonatomic) float bandwidth;
@property (assign, nonatomic) float skirtWidth;
@property (assign, nonatomic) float gain;
@property (assign) NSInteger sampleRate;
@property (strong) NSData *taps;
@property (strong) NSLock *tapsLock;

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
