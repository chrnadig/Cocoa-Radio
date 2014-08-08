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
+ (instancetype)arrayWithLength:(NSUInteger)length;

// initializer
- (instancetype)initWithLength:(NSUInteger)length;

// copy complex floats to another array
- (void)copyFromArray:(CSDRComplexArray *)other length:(NSUInteger)length fromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

// clear array (set all values to 0.0+0.0i)
- (void)clear;


#warning for backward compatibility only - remove when done!
+ (instancetype)arrayWithDict:(NSDictionary *)dict;
#warning for backward compatibility only - remove when done!
- (NSMutableDictionary *)dict;

@end
