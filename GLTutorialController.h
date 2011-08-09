//
//  GLTutorialController.h
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <CoreVideo/CVDisplayLink.h>

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

@property (nonatomic, readwrite, retain) IBOutlet NSWindow *window;
@property (nonatomic, readwrite, retain) IBOutlet NSOpenGLView *view;

@end
