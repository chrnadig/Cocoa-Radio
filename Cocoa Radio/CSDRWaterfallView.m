//
//  CSDRWaterfallView.m
//  Cocoa Radio
//
//  Created by William Dillon on 6/7/12.
//  Copyright (c) 2012. All rights reserved. Licensed under the GPL v.2
//

#import "CSDRWaterfallView.h"
#import "OpenGLView.h"
#import "CSDRAppDelegate.h"
#import "CSDRRealArray.h"

// texture size
#define WIDTH  2048
#define HEIGHT 4096

// private declarations
@interface CSDRWaterfallView ()
@property (readwrite) BOOL initialized;
@property (readwrite) GLint currentLine;
@property (readwrite) ShaderProgram *shader;
@end

@implementation CSDRWaterfallView

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attributes [] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccumSize, 32,
        NSOpenGLPFADepthSize, 16,
        NSOpenGLPFAMultisample,
        NSOpenGLPFASampleBuffers, 1,
        NSOpenGLPFASamples, 4,
        (NSOpenGLPixelFormatAttribute)nil
    };
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

- (void)initGL
{
    self.initialized = NO;
    return;
}

-(void)initialize
{
    if (!self.initialized) {
        // Read the shader from file
        float *blankImage;
        NSError *nsError = nil;
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *shaderURL = [bundle URLForResource:@"waterfallShader" withExtension:@"ogl"];
        NSString *shaderString = [NSString stringWithContentsOfURL:shaderURL encoding:NSUTF8StringEncoding error:&nsError];

        if (shaderString == nil) {
            NSLog(@"Unable to open shader file: %@", [nsError localizedDescription]);
            return;
        }
        
        self.shader = [[ShaderProgram alloc] initWithVertex:nil andFragment:shaderString];
        
        // Set black background
        glClearColor(0.0, 0.0, 0.0, 1.0);
        
        // Set viewing mode
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        // Set blending characteristics
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_TEXTURE_2D);
        
        // set texturing to replacement mode
        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
        
        // Get a texture ID
        glGenTextures(1, &_textureID);
        
        // Set texturing parameters
        glBindTexture(GL_TEXTURE_2D, self.textureID);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        
        // allocate memory for texture and initialize with blank image - compensate for calculations done in shader
        if ((blankImage = malloc(WIDTH * HEIGHT * sizeof(float))) != NULL) {
            float blankValue = self.appDelegate.bottomValue * self.appDelegate.range;
            for (NSUInteger i = 0; i < WIDTH * HEIGHT; i++) {
                blankImage[i] = blankValue;
            }
            glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, WIDTH, HEIGHT, 0, GL_ALPHA, GL_FLOAT, blankImage);
            free(blankImage);
            self.initialized = YES;
        }
        glBindTexture(GL_TEXTURE_2D, 0);
    }
}

- (void)draw
{
    if (!self.initialized) {
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }

    glBindTexture(GL_TEXTURE_2D, self.textureID);

    CSDRRealArray *newSlice = self.appDelegate.fftData;
    if (newSlice != nil) {
        // Replace the oldest line in the texture - fill just alpha, shader does the rest
        self.currentLine = self.currentLine == HEIGHT ? 0 : self.currentLine + 1;
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, self.currentLine, WIDTH, 1, GL_ALPHA, GL_FLOAT, newSlice.realp);
    }

    [self.shader bind];

    // Set the uniforms
    [self.shader setIntValue:3 forUniform:@"persistance"];
    [self.shader setIntValue:self.currentLine forUniform:@"currentLine"];
    [self.shader setIntValue:HEIGHT forUniform:@"height"];
    [self.shader setIntValue:self.appDelegate.average forUniform:@"average"];
    [self.shader setFloatValue:self.appDelegate.bottomValue forUniform:@"bottomValue"];
    [self.shader setFloatValue:self.appDelegate.range forUniform:@"range"];
    
    glBegin(GL_QUADS); {
        float top = (float)self.currentLine / HEIGHT;
        float bot = top + 1.0;
        float left = 0.0;
        float right = 1.0;

		glColor3f(0.0, 1.0, 0.0);
        glTexCoord2d(left, top);
		glVertex2f(-1.0, -1.0);
		glTexCoord2d(left, bot);
		glVertex2f(-1.0, 1.0);
		glTexCoord2d(right, bot);
		glVertex2f(1.0, 1.0);
		glTexCoord2d(right, top);
		glVertex2f(1.0, -1.0);
	} glEnd();
    
    [self.shader unBind];
    glBindTexture(GL_TEXTURE_2D, 0);
    
#if 0
    // draw IF bandwidth
    glBegin(GL_QUADS);
    {
        glColor4f(1.0, 0.5, 0.5, 0.25);
        glVertex2f(self.sliderValue - 0.1, -1); // vertex 1
        glVertex2f(self.sliderValue + 0.1, -1); // vertex 2
        glVertex2f(self.sliderValue + 0.1,  1); // vertex 3
        glVertex2f(self.sliderValue - 0.1,  1); // vertex 4
    }
    glEnd();
#endif
    
    glLineWidth(2.0);
	glBegin( GL_LINES ); {
		glColor3f( 1.0, 0.0, 0.0 );
		glVertex2f(self.sliderValue, -1);
		glVertex2f(self.sliderValue,  1);
	} glEnd();

}

- (void)update
{
    [openGLView setNeedsDisplay:YES];
}

- (IBAction) sliderUpdate:(id)sender
{
	self.sliderValue = -([sender floatValue] - 1);
	[openGLView setNeedsDisplay: YES];
    return;
}

// helper to calculate and set frequency
- (void)calculateFrequency:(float)location
{
    NSRect bounds = [openGLView bounds];
    float normalized;
    if (location > bounds.origin.x + bounds.size.width - 1.0) {
        location = bounds.origin.x + bounds.size.width - 1.0;
    } else if (location < bounds.origin.x + 1.0) {
        location = bounds.origin.x + 1.0;
    }
    normalized = location / bounds.size.width;
    self.sliderValue = 2.0 * normalized - 1;
    // calculate the tuned frequency and send it to the app delegate
    float tunedFreq = normalized * self.sampleRate - self.sampleRate / 2.0;
    self.tuningValue = tunedFreq;
    tunedFreq += self.appDelegate.loValue * 1000000;
    self.appDelegate.tuningValue = tunedFreq / 1000000;
}

- (void)mouseDownLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{
    // a left-mouse click is a re-tuning of the LO according to the location of the click
    [self calculateFrequency:location.x];
}

- (void)mouseDraggedLocation:(NSPoint)location Flags:(NSUInteger)modifierFlags
{
    // update frequency while dragging
    [self calculateFrequency:location.x];
}

@end
