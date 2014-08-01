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

// clear array (set all values to 0.0)
- (void)clear;

- (void)setLengthGrowingAtHead:(NSUInteger)newLength;
- (void)setLengthGrowingAtTail:(NSUInteger)newLength;

@end
