//
//  GLTutorialController.h
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

typedef struct
{
    GLfloat x,y;
} Vector2;

typedef struct
{
    GLfloat x,y,z,w;
} Vector4;

typedef struct
{
    GLfloat r,g,b,a;
} Colour;

@interface GLTutorialController : NSObject
{
@private
    CVDisplayLinkRef displayLink;
    
    NSOpenGLView *view;
    
    BOOL isFirstRender;
    
    GLuint shaderProgram;
    GLuint vertexBuffer;
    
    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;
}

@property (nonatomic, readwrite, retain) IBOutlet NSOpenGLView *view;

@end
