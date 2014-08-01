//
//  CSDRComplexArray.h
//  Test3
//
//  Created by Christoph Nadig on 31.07.14.
//  Copyright (c) 2014 Lobotomo Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@interface CSDRComplexArray : NSObject

@property (readonly) float *realp;
@property (readonly) float *imagp;
@property (readonly) DSPSplitComplex *complexp;
@property (readonly) NSUInteger length;

// convenience constructor
+ (instancetype)arraywithLength:(NSUInteger)length;

// initializer
- (instancetype)initWithLength:(NSUInteger)length;

// clear array (set all values to 0.0)
- (void)clear;

@end
