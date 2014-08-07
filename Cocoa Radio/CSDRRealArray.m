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
#warning change ring buffer too!
    free(_realp);
}

// copy floats to another array - not thread safe
- (void)copyToArray:(CSDRRealArray *)other numElements:(NSUInteger)numElements fromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    // some sanity checks first
    if (fromIndex + numElements <= self.length && toIndex + numElements <= other.length) {
        memcpy(other.realp + toIndex, self.realp + fromIndex, numElements * sizeof(float));
    } else {
        NSLog(@"-copyToArray called with invalid arguments: numElements = %lu, fromIndex = %lu, toIndex = %lu, fromLength = %lu, toLength = %lu",
              numElements, fromIndex, toIndex, self.length, other.length);
    }
}

// clear array (set all values to 0.0)
- (void)clear
{
    memset(self.realp, 0, self.length * sizeof(float));
}

// re-adjust size, insert 0 at start
// CAUTION: this is not thread safe (and cannot be done thread safe)
- (void)setLengthGrowingAtHead:(NSUInteger)newLength
{
    if (newLength > self.length) {
        // realloc does not make sense since we might need to copy values again
        float *newValues = malloc(newLength * sizeof(float));
        if (newValues != NULL) {
            // clear new space at head
            memset(newValues, 0, (newLength - self.length) * sizeof(float));
            // copy old values
            memcpy(newValues + newLength - self.length, self.realp, self.length * sizeof(float));
            // free old space and assign new space
            free(self.realp);
            self.realp = newValues;
            self.length = newLength;
        }
    } else {
        // just shrink with realloc
        float *newValues = realloc(self.realp, newLength * sizeof(float));
        if (newValues != NULL) {
            self.realp = newValues;
            self.length = newLength;
        }
    }
}

// re-adjust size, insert 0 at end
// CAUTION: this is not thread safe (and cannot be done thread safe)
- (void)setLengthGrowingAtTail:(NSUInteger)newLength
{
    // try to realloc to new size
    float *newValues = realloc(self.realp, newLength * sizeof(float));
    // do nothing in case of failure - old pointer is still valid!
    if (newValues != NULL) {
        // clear new space at tail
        if (newLength > self.length) {
            memset(newValues + self.length, 0, newLength - self.length);
        }
        self.realp = newValues;
        self.length = newLength;
    }
}

// CAUTION: this is not thread safe
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
