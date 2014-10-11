//
//  CSDRRealArray.m
//  Test3
//
//  Created by Christoph Nadig on 30.07.14.
//  Copyright (c) 2014 Lobotomo Software. All rights reserved.
//

#import "CSDRRealArray.h"

// private declarations
@interface CSDRRealArray ()
@property (readwrite) float *realp;
@property (readwrite) NSUInteger length;
@end

@implementation CSDRRealArray

+ (instancetype)arrayWithLength:(NSUInteger)length
{
    return [[self alloc] initWithLength:length];
}

- (instancetype)initWithLength:(NSUInteger)size
{
    if (self = [super init]) {
        if ((_realp = calloc(size, sizeof(float))) != NULL) {
            _length = size;
            return self;
        }
    }
    // something went wrong
    return nil;
}

- (void)dealloc
{
    free(_realp);
}

// copy floats to another array
- (void)copyFromArray:(CSDRRealArray *)other length:(NSUInteger)length fromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    // some sanity checks first
    NSParameterAssert(fromIndex + length <= other.length && toIndex + length <= self.length);
    memmove(self.realp + toIndex, other.realp + fromIndex, length * sizeof(float));
}

// clear array (set all values to 0.0)
- (void)clear
{
    memset(self.realp, 0, self.length * sizeof(float));
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@(%lu) = {", NSStringFromClass([self class]), self.length];
    for (NSUInteger i = 0; i < self.length; i++) {
        [string appendFormat:@" %f", self.realp[i]];
    }
    [string appendString:@" }"];
    return string;
}


#warning for backward compatibility only - remove when done!
+ (instancetype)arrayWithData:(NSData *)data
{
    CSDRRealArray *array = [self arrayWithLength:[data length] / sizeof(float)];
    memcpy(array.realp, [data bytes], [data length]);
    return array;
}

#warning for backward compatibility only - remove when done!
- (NSMutableData *)data
{
    return [NSMutableData dataWithBytes:self.realp length:self.length * sizeof(float)];
}

@end
