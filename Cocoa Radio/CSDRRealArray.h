//
//  CSDRRealArray.h
//  Cocoa Radio
//
//  Created by Christoph Nadig on 30.07.14.
//  Copyright (c) 2014 Lobotomo Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSDRRealArray : NSObject

@property (readonly) float *realp;
@property (readonly) NSUInteger length;

// convenience constructor
+ (instancetype)arrayWithLength:(NSUInteger)length;

// initializer
- (instancetype)initWithLength:(NSUInteger)length;

// copy floats to another array
- (void)copyFromArray:(CSDRRealArray *)other length:(NSUInteger)length fromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

// clear array (set all values to 0.0)
- (void)clear;

#warning for backward compatibility only - remove when done!
+ (instancetype)arrayWithData:(NSData *)data;
#warning for backward compatibility only - remove when done!
- (NSMutableData *)data;


@end
