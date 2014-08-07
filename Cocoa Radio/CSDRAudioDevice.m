//
//  CSDRAudioDevice.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/30/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioUnitUtilities.h>
#import <mach/mach_time.h>
#import "CSDRAudioDevice.h"
#import "CSDRRealArray.h"
#import "CSDRRealBuffer.h"
#import "CSDRAppDelegate.h"
#import "audioprobes.h"

double subtractTimes(uint64_t end, uint64_t start);

static NSString *audioSourceNameKey                 = @"audioSourceName";
static NSString *audioSourceNominalSampleRateKey    = @"audioSourceNominalSampleRate";
static NSString *audioSourceAvailableSampleRatesKey = @"audioSourceAvailableSampleRates";
static NSString *audioSourceInputChannelsKey        = @"audioSourceInputChannels";
static NSString *audioSourceOutputChannelsKey       = @"audioSourceOutputChannels";
static NSString *audioSourceDeviceIDKey             = @"audioSourceDeviceID";
static NSString *audioSourceDeviceUIDKey            = @"audioSourceDeviceUID";

// private declarations
@interface CSDRAudioDevice ()
@property (readwrite) BOOL running;
@property (readwrite) BOOL prepared;
@property (readwrite) AudioComponentInstance auHAL;
@property (readwrite) CSDRRealBuffer *ringBuffer;
@end

@implementation CSDRAudioDevice


+ (NSArray *)initDeviceDict
{
    // Variables used for each of the functions
    UInt32 propertySize = 0;
    Boolean writable = NO;
    AudioObjectPropertyAddress property;
    NSMutableArray *devices;
    
    // Get the size of the device IDs array
    property.mSelector = kAudioHardwarePropertyDevices;
    property.mScope    = kAudioObjectPropertyScopeGlobal;
    property.mElement  = kAudioObjectPropertyElementMaster;
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                   &property, 0, NULL, &propertySize);
    
    // Create the array for device IDs
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(propertySize);
    
    // Get the device IDs
    AudioObjectGetPropertyData(kAudioObjectSystemObject,
                               &property, 0, NULL,
                               &propertySize, deviceIDs);
    
    NSUInteger numDevices = propertySize / sizeof(AudioDeviceID);
    
    // This is the array to hold the NSDictionaries
    devices = [[NSMutableArray alloc] initWithCapacity:numDevices];
    
    // Get per-device information
    for (int i = 0; i < numDevices; i++) {
        NSMutableDictionary *deviceDict = [[NSMutableDictionary alloc] init];
        [deviceDict setValue:[NSNumber numberWithInt:i]
                      forKey:audioSourceDeviceIDKey];
        
        CFStringRef string;
        
        // Get the name of the audio device
        property.mSelector = kAudioObjectPropertyName;
        property.mScope    = kAudioObjectPropertyScopeGlobal;
        property.mElement  = kAudioObjectPropertyElementMaster;
        
        propertySize = sizeof(string);
        AudioObjectGetPropertyData(deviceIDs[i], &property, 0, NULL,
                                   &propertySize, &string);
        
        // Even though it's probably OK to use the CFString as an NSString
        // I'm going to make a copy, just to be safe.
        NSString *deviceName = [(__bridge NSString *)string copy];
        CFRelease(string);
        
        [deviceDict setValue:deviceName
                      forKey:audioSourceNameKey];
        
        // Get the UID of the device, used by the audioQueue
        property.mSelector = kAudioDevicePropertyDeviceUID;
        propertySize = sizeof(string);
        AudioObjectGetPropertyData(deviceIDs[i], &property, 0, NULL,
                                   &propertySize, &string);
        
        // Again, copy to a NSString...
        NSString *deviceUID = [(__bridge NSString *)string copy];
        CFRelease(string);
        
        [deviceDict setValue:deviceUID
                      forKey:audioSourceDeviceUIDKey];

        //TODO: change these calls to non-deprecated functions
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        // Get the nominal sample rate
        Float64 currentSampleRate = 0;
        propertySize = sizeof(currentSampleRate);
        AudioDeviceGetProperty(deviceIDs[i], 0, NO,
                               kAudioDevicePropertyNominalSampleRate,
                               &propertySize, &currentSampleRate);
        
        
        [deviceDict setValue:[NSNumber numberWithFloat:currentSampleRate]
                      forKey:audioSourceNominalSampleRateKey];
        
        // Get an array of sample rates
        AudioValueRange *sampleRates;
        AudioDeviceGetPropertyInfo(deviceIDs[i], 0, NO,
                                   kAudioDevicePropertyAvailableNominalSampleRates,
                                   &propertySize, &writable);
        sampleRates = (AudioValueRange *)malloc(propertySize);
        AudioDeviceGetProperty(deviceIDs[i], 0, NO,
                               kAudioDevicePropertyAvailableNominalSampleRates,
                               &propertySize, sampleRates);

#pragma clang diagnostic pop

        NSUInteger numSampleRates = propertySize / sizeof(AudioValueRange);
        NSMutableArray *sampleRateTempArray = [[NSMutableArray alloc] init];
        for (int j = 0; j < numSampleRates; j++) {
            // An NSRange is a location and length...
            NSRange sampleRange;
            sampleRange.length   = sampleRates[j].mMaximum - sampleRates[j].mMinimum;
            sampleRange.location = sampleRates[j].mMinimum;
            
            [sampleRateTempArray addObject:[NSValue valueWithRange:sampleRange]];
        }
        
        // Create a immutable copy of the available sample rate array
        // and store it into the NSDict
        NSArray *tempArray = [sampleRateTempArray copy];
        
        [deviceDict setValue:tempArray
                      forKey:audioSourceAvailableSampleRatesKey];
        
        free(sampleRates);
        
        // Get the number of output channels for the device
//        AudioBufferList bufferList;
//        propertySize = sizeof(bufferList);
//        AudioDeviceGetProperty(deviceIDs[i], 0, NO,
//                               kAudioDevicePropertyStreamConfiguration,
//                               &propertySize, &bufferList);
        
//        int outChannels, inChannels;
//        if (bufferList.mNumberBuffers > 0) {
//            outChannels = bufferList.mBuffers[0].mNumberChannels;
//            [deviceDict setValue:[NSNumber numberWithInt:outChannels]
//                          forKey:audioSourceOutputChannelsKey];
//        } else {
//            [deviceDict setValue:[NSNumber numberWithInt:0]
//                          forKey:audioSourceOutputChannelsKey];
//        }
        
        // Again for input channels
//        propertySize = sizeof(bufferList);
//        AudioDeviceGetProperty(deviceIDs[i], 0, YES,
//                               kAudioDevicePropertyStreamConfiguration,
//                               &propertySize, &bufferList);
        
        // The number of channels is the number of buffers.
        // The actual buffers are NULL.
//        if (bufferList.mNumberBuffers > 0) {
//            inChannels = bufferList.mBuffers[0].mNumberChannels;
//            [deviceDict setValue:[NSNumber numberWithInt:inChannels]
//                          forKey:audioSourceInputChannelsKey];
//        } else {
//            [deviceDict setValue:[NSNumber numberWithInt:0]
//                          forKey:audioSourceInputChannelsKey];
//        }
        
        // Add this new device dict to the array and release it
        [devices addObject:deviceDict];
    }
    return [devices copy];
}

+ (NSArray *)deviceDict
{
    static NSArray *devices;
    static dispatch_once_t dictOnceToken;
    dispatch_once(&dictOnceToken, ^{
        devices = [CSDRAudioDevice initDeviceDict];
    });
    return devices;
}

- (id)init
{
    if (self = [super init]) {
        // this code is generic for input and output subclasses refine it further
        // !! this code is from Apple Technical Note TN2091. There are several different types of Audio Units.
        // some audio units serve as Outputs, Mixers, or DSP units. See AUComponent.h for listing
        AudioComponentDescription audioDescription;
        AudioComponent audioComponent;
        
        audioDescription.componentType = kAudioUnitType_Output;
        
        // every Component has a subType, which will give a clearer picture of what this components function will be.
        audioDescription.componentSubType = kAudioUnitSubType_HALOutput;
        
        // all Audio Units in AUComponent.h must use "kAudioUnitManufacturer_Apple" as the Manufacturer
        audioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        audioDescription.componentFlags = 0;
        audioDescription.componentFlagsMask = 0;
        
        // finds a component that meets audioDescription spec's
        audioComponent = AudioComponentFindNext(NULL, &audioDescription);
        if (audioComponent != NULL) {
            // gains access to the services provided by the component
            AudioComponentInstanceNew(audioComponent, &_auHAL);
            return self;
        }
    }
    // something went wrong
    return nil;
}

- (id)initWithRate:(float)newSampleRate
{
    if (self = [self init]) {
        self.sampleRate = newSampleRate;
    }
    
    return self;
}

- (void)unprepare
{
    [[NSException exceptionWithName:@"CSDRAudioDeviceException" reason:@"-unprepare called in base class" userInfo:nil] raise];
}

- (BOOL)prepare
{
    [[NSException exceptionWithName:@"CSDRAudioDeviceException" reason:@"-prepare called in base class" userInfo:nil] raise];
    return NO;
}

- (BOOL)start
{
    [[NSException exceptionWithName:@"CSDRAudioDeviceException" reason:@"-start called in base class" userInfo:nil] raise];
    return NO;
}

- (void)stop
{
    [[NSException exceptionWithName:@"CSDRAudioDeviceException" reason:@"-stop called in base class" userInfo:nil] raise];
}

@end

@implementation CSDRAudioOutput

OSStatus OutputProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *TimeStamp,
                    UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList * ioData)
{
    @autoreleasepool {
        
        CSDRAudioOutput *device = (__bridge CSDRAudioOutput *)inRefCon;
        CSDRRealBuffer *ringBuffer = device.ringBuffer;
        static uint64_t last_buffer_time;

        // determine whether this will have a buffer underflow, if so, trigger a discontinuity.  Perhaps, it'll be less
        // jarring to have one longer discontinuity than many smaller ones
        if (ringBuffer.fillLevel < inNumberFrames) {
            [device markDiscontinuity];
        }
        
        // during a period of discontinuity, produce silence
        if (device.discontinuity) {
            for (int i = 0; i < ioData->mNumberBuffers; i++) {
                bzero(ioData->mBuffers[i].mData, ioData->mBuffers[i].mDataByteSize);
            }
            return noErr;
        }
        
        // Load some data out of the ring buffer
        [ringBuffer fetchFrames:inNumberFrames into:ioData];
        
        // attempt to determine whether the buffer backlog is increasing
        if (COCOARADIOAUDIO_AUDIOBUFFER_ENABLED()) {
            uint64_t this_time = TimeStamp->mHostTime;
            double deltaTime = subtractTimes(this_time, last_buffer_time);
            double derivedSampleRate = inNumberFrames / deltaTime;
            int fillLevel = (int)ringBuffer.fillLevel;
            last_buffer_time = this_time;
            COCOARADIOAUDIO_AUDIOBUFFER((int)derivedSampleRate, fillLevel);
        }

        if (device.mute) {
            for (int i = 0; i < ioData->mNumberBuffers; i++) {
                bzero(ioData->mBuffers[i].mData, ioData->mBuffers[i].mDataByteSize);
            }
            return noErr;
        }

        // Copy the data to other channels
        for (int i = 1; i < ioData->mNumberBuffers; i++) {
            memcpy(ioData->mBuffers[i].mData, ioData->mBuffers[0].mData, ioData->mBuffers[i].mDataByteSize);
        }
        return noErr;
    }
}

- (id)init
{
    if (self = [super init]) {
        // this code is from Apple Technical Note TN2091. this code disables the "input bus" of the HAL
        AudioDeviceID outputDevice = kAudioObjectUnknown;
        AudioObjectPropertyAddress property_address = { kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
        UInt32 size = sizeof(AudioDeviceID);
        OSStatus err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property_address, 0, NULL, &size, &outputDevice);
        if (err == noErr) {
            err = AudioUnitSetProperty(self.auHAL, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDevice, sizeof(outputDevice));
            if (err == noErr) {
                // when using AudioUnitSetProperty the 4th parameter in the method refer to an AudioUnitElement. When using an AudioOutputUnit
                // the input element will be '1' and the output element will be '0'.
                UInt32 enableIO = 0;
                // disable input
                AudioUnitSetProperty(self.auHAL, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
                // enable output
                enableIO = 1;
                AudioUnitSetProperty(self.auHAL, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, sizeof(enableIO));
                return self;
            }
        }
    }
    // something went wrong
    return nil;
}

- (BOOL)prepare
{
    if (!self.prepared) {
        UInt32 size = sizeof(AudioStreamBasicDescription);
        Float64 trySampleRate = self.sampleRate;
        AudioStreamBasicDescription deviceFormat;
        AudioStreamBasicDescription desiredFormat;
        AURenderCallbackStruct output = { OutputProc, (__bridge void *)self };
        int channels = 1;
        OSStatus err;
        
        // setup the device characteristics
        desiredFormat.mFormatID         = kAudioFormatLinearPCM;
        desiredFormat.mSampleRate       = self.sampleRate;
        desiredFormat.mChannelsPerFrame = channels;
        desiredFormat.mBitsPerChannel   = 8 * sizeof(float);
        desiredFormat.mBytesPerFrame    = sizeof(float) * channels;
        desiredFormat.mBytesPerPacket   = sizeof(float) * channels;
        desiredFormat.mFramesPerPacket  = 1;
        desiredFormat.mFormatFlags      = kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked;
        
        // set format to output scope
        AudioUnitSetProperty(self.auHAL, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &desiredFormat, sizeof(AudioStreamBasicDescription));
        
        // attempt to set the sample rate (so far, this isn't working)
        err = AudioUnitSetProperty(self.auHAL, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &trySampleRate, sizeof(trySampleRate));
        
        trySampleRate = 0.0;
        err = AudioUnitGetProperty(self.auHAL, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &trySampleRate, &size);
        
        // get the device format back
        AudioUnitGetProperty (self.auHAL, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &deviceFormat, &size);
        
        // create a ring buffer for the audio (1 second worth of data)
        self.ringBuffer = [[CSDRRealBuffer alloc] initWithCapacity:self.sampleRate];
        
        // setup the callback
        AudioUnitSetProperty(self.auHAL, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &output, sizeof(output));

        self.prepared = YES;
    }
    return YES;
}

- (BOOL)start
{
    if (!self.prepared) {
        if (![self prepare]) {
            return NO;
        }
    }

    if (AudioUnitInitialize(self.auHAL) != noErr) {
        return NO;
    }
    if (AudioOutputUnitStart(self.auHAL) != noErr) {
        return NO;
    }
    self.running = YES;
    discontinuity = NO;
    return YES;
}

-(BOOL)discontinuity
{
    return discontinuity;
}

- (void)markDiscontinuity
{
    // NSLog(@"Marking audio discontinuity.");
    discontinuity = YES;
    // [self.ringBuffer clear];
}

-(void)bufferData:(CSDRRealArray *)input
{
    [self.ringBuffer storeData:input];

    // If it's not started yet, wait until 1/8 of a second is available
    if (!self.running) {
        if (self.ringBuffer.fillLevel >= self.ringBuffer.capacity / 8) {
            [self start];
        }
    } else if (discontinuity) {
        if (self.ringBuffer.fillLevel >= self.ringBuffer.capacity / 8) {
            discontinuity = false;
        }
    }
}

- (void)audioAvailable:(NSNotification *)notification
{
    [self bufferData:[notification object]];
}

@end
