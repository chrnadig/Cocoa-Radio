//
//  CSDRWaterfallView.h
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import <Cocoa/Cocoa.h>
#import "OpenGLController.h"
#import "ShaderProgram.h"

#define TEXTURE_TYPE GL_TEXTURE_2D
//#define TEXTURE_TYPE GL_TEXTURE_RECTANGLE_ARB

@class CSDRAppDelegate;

@interface CSDRWaterfallView : OpenGLController

@property (readwrite) IBOutlet CSDRAppDelegate *appDelegate;
@property (readwrite) float sliderValue;
@property (readwrite) float sampleRate;
@property (readwrite) float tuningValue;
@property (readonly) GLint currentLine;
@property (readonly) GLuint textureID;

- (void)initialize;
- (IBAction) sliderUpdate:(id)sender;
- (void)update;

@end
