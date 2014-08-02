//
//  CSDRComplexBuffer.h
//  Cocoa Radio
//
//  Created by Christoph Nadig on 01.08.14.
//  Copyright (c) 2014 Oregon State University (COAS). All rights reserved.
//

#import <Foundation/Foundation.h>

@class CSDRComplexArray;

@interface CSDRComplexBuffer : NSObject

@property (readonly) NSInteger fillLevel;
@property (readonly) NSInteger capacity;

// convencience constructor
+ (instancetype)bufferWithCapacity:(NSUInteger)capacity;

// initializer
- (id)initWithCapacity:(NSInteger)capacity;

// store data in the ring buffer
- (void)storeData:(CSDRComplexArray *)data;

// fill data from ring buffer
- (void)fillData:(CSDRComplexArray *)data;

// clear buffer
- (void)clear;

@end
