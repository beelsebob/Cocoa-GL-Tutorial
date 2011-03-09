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

#if defined(DEBUG)
// This code Copyright (c) Max Rupp
#define eglError( Error )\
{\
NSLog( @"OpenGL Error: %@", Error );\
\
assert( 0 );\
}

#define eglGetError( )\
{\
for ( GLenum Error = glGetError( ); ( GL_NO_ERROR != Error ); Error = glGetError( ) )\
{\
switch ( Error )\
{\
case GL_INVALID_ENUM:      eglError( @"GL_INVALID_ENUM"      ); break;\
case GL_INVALID_VALUE:     eglError( @"GL_INVALID_VALUE"     ); break;\
case GL_INVALID_OPERATION: eglError( @"GL_INVALID_OPERATION" ); break;\
case GL_STACK_OVERFLOW:    eglError( @"GL_STACK_OVERFLOW"    ); break;\
case GL_STACK_UNDERFLOW:   eglError( @"GL_STACK_UNDERFLOW"   ); break;\
case GL_OUT_OF_MEMORY:     eglError( @"GL_OUT_OF_MEMORY"     ); break;\
default:                                                        break;\
}\
}\
}
// End of (c) Max Rupp code.
#else
#define eglGetError()
#endif

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
    
    GLuint shaderProgram;
    GLuint vertexBuffer;
    
    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;
}

@property (nonatomic, readwrite, retain) IBOutlet NSOpenGLView *view;

@end
