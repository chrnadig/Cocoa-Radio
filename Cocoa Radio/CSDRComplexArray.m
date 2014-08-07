//
//  CSDRComplexArray.m
//  Cocoa Radio
//
//  Created by Christoph Nadig on 31.07.14.
//  Copyright (c) 2014 Lobotomo Software. All rights reserved.
//

#import "CSDRComplexArray.h"

// private declaration
@interface CSDRComplexArray ()
@property (readwrite) DSPSplitComplex complex;
@end

@implementation CSDRComplexArray

// convenience constructor
+ (instancetype)arrayWithLength:(NSUInteger)length
{
    return [[self alloc] initWithLength:length];
}

// initializer
- (instancetype)initWithLength:(NSUInteger)length
{
    if (self = [super init]) {
        _complex.realp = calloc(length * 2, sizeof(float));
        if (_complex.realp != NULL) {
            _complex.imagp = _complex.realp + length;
            _length = length;
            return self;
        }
    }
    // something went wrong
    return nil;
}

- (void)dealloc
{
    free(_complex.realp);
}

// copy complex floats to another array - not thread safe
- (void)copyToArray:(CSDRComplexArray *)other numElements:(NSUInteger)numElements fromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    // some sanity checks first
    if (fromIndex + numElements <= self.length && toIndex + numElements <= other.length) {
        memcpy(other.realp + toIndex, self.realp + fromIndex, numElements * sizeof(float));
        memcpy(other.imagp + toIndex, self.imagp + fromIndex, numElements * sizeof(float));
    } else {
        NSLog(@"-copyToArray called with invalid arguments: numElements = %lu, fromIndex = %lu, toIndex = %lu, fromLength = %lu, toLength = %lu",
              numElements, fromIndex, toIndex, self.length, other.length);
    }
}

// clear array (set all values to 0.0)
- (void)clear
{
    memset(self.realp, 0, 2 * self.length * sizeof(float));
}

// accessors
- (float *)realp
{
    return _complex.realp;
}

- (float *)imagp
{
    return _complex.imagp;
}

- (DSPSplitComplex *)complexp
{
    return &_complex;
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@(%lu) = {", NSStringFromClass([self class]), self.length];
    for (NSUInteger i = 0; i < self.length; i++) {
        [string appendFormat:@" %f+%fi", self.realp[i], self.imagp[i]];
    }
    [string appendString:@" }"];
    return string;
}

#warning for backward compatibility only - remove when done!
+ (instancetype)arrayWithDict:(NSDictionary *)dict
{
    CSDRComplexArray *array = [self arrayWithLength:[dict[@"real"] length] / sizeof(float)];
    memcpy(array.realp, [dict[@"real"] bytes], [dict[@"real"] length]);
    memcpy(array.imagp, [dict[@"imag"] bytes], [dict[@"real"] length]);
    return array;
}

#warning for backward compatibility only - remove when done!
- (NSMutableDictionary *)dict
{
    return [@{ @"real" : [NSData dataWithBytes:self.realp length:self.length * sizeof(float)],
               @"imag" : [NSData dataWithBytes:self.imagp length:self.length * sizeof(float)] } mutableCopy ];
}

@end
