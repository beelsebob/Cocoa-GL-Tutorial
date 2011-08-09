//
//  GLTutorialController.m
//  GLTutorial
//
//  Created by Tom Davie on 20/02/2011.
//  Copyright 2011 Tom Davie. All rights reserved.
//

#import "GLTutorialController.h"

#import "error.h"

typedef struct
{
    Vector4 position;
    Colour colour;
} Vertex;

@interface GLTutorialController ()

- (void)createOpenGLView;

- (void)createDisplayLink;

- (void)createOpenGLResources;
- (void)loadShader;
- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file;
- (void)linkProgram:(GLuint)program;
- (void)validateProgram:(GLuint)program;

- (void)loadBufferData;

- (void)renderForTime:(CVTimeStamp)time;

@end

CVReturn displayCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

CVReturn displayCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
{
    GLTutorialController *controller = (GLTutorialController *)displayLinkContext;
    [controller renderForTime:*inOutputTime];
    return kCVReturnSuccess;
}

@interface GLTutorialController ()

@property (readwrite, assign) GLuint shaderProgram;
@property (readwrite, assign) GLuint vertexArrayObject;
@property (readwrite, assign) GLuint vertexBuffer;

@property (readwrite, assign) GLint positionUniform;
@property (readwrite, assign) GLint colourAttribute;
@property (readwrite, assign) GLint positionAttribute;

@end

@implementation GLTutorialController
{
    CVDisplayLinkRef displayLink;
}

@synthesize view;
@synthesize window;

@synthesize shaderProgram;
@synthesize vertexArrayObject;
@synthesize vertexBuffer;
@synthesize positionUniform;
@synthesize colourAttribute;
@synthesize positionAttribute;

- (void)awakeFromNib
{
    [self createOpenGLView];
    [self createOpenGLResources];
    [self createDisplayLink];
}

- (void)createOpenGLView
{
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] =
    {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize    , 24                           ,
        NSOpenGLPFAAlphaSize    , 8                            ,
        NSOpenGLPFADoubleBuffer ,
        NSOpenGLPFAAccelerated  ,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes] autorelease];
    [self setView:[[[NSOpenGLView alloc] initWithFrame:[[[self window] contentView] bounds] pixelFormat:pixelFormat] autorelease]];
    [[[self window] contentView] addSubview:[self view]];
}

- (void)createDisplayLink
{
    CGDirectDisplayID displayID = CGMainDisplayID();
    CVReturn error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    
    if (kCVReturnSuccess == error)
    {
        CVDisplayLinkSetOutputCallback(displayLink, displayCallback, self);
        CVDisplayLinkStart(displayLink);
    }
    else
    {
        NSLog(@"Display Link created with error: %d", error);
        displayLink = NULL;
    }
}

- (void)createOpenGLResources
{
    [[[self view] openGLContext] makeCurrentContext];
    [self loadShader];
    [self loadBufferData];
}

- (void)loadShader
{
    GLuint vertexShader;
    GLuint fragmentShader;
    
    vertexShader   = [self compileShaderOfType:GL_VERTEX_SHADER   file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]];
    fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
    
    if (0 != vertexShader && 0 != fragmentShader)
    {
        [self setShaderProgram:glCreateProgram()];
        GetError();
        
        glAttachShader([self shaderProgram], vertexShader  );
        GetError();
        glAttachShader([self shaderProgram], fragmentShader);
        GetError();
        
        glBindFragDataLocation([self shaderProgram], 0, "fragColour");
        
        [self linkProgram:[self shaderProgram]];
        
        [self setPositionUniform:glGetUniformLocation([self shaderProgram], "p")];
        GetError();
        if ([self positionUniform] < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'p' uniform."];
        }
        [self setColourAttribute:glGetAttribLocation([self shaderProgram], "colour")];
        GetError();
        if ([self colourAttribute] < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'colour' attribute."];
        }
        [self setPositionAttribute:glGetAttribLocation([self shaderProgram], "position")];
        GetError();
        if ([self positionAttribute] < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];
        }
        
        glDeleteShader(vertexShader  );
        GetError();
        glDeleteShader(fragmentShader);
        GetError();
    }
    else
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed."];
    }
}

- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file
{
    GLuint shader;
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to read shader file %@", file];
    }
    
    shader = glCreateShader(type);
    GetError();
    glShaderSource(shader, 1, &source, NULL);
    GetError();
    glCompileShader(shader);
    GetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader compilation failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    GetError();
    if (0 == status)
    {
        glDeleteShader(shader);
        GetError();
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed for file %@", file];
    }
    
    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);
    GetError();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();
        NSLog(@"Shader program linking failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    GetError();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)validateProgram:(GLuint)program
{
    GLint logLength;
    
    glValidateProgram(program);
    GetError();
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GetError();
    if (logLength > 0)
    {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GetError();
        NSLog(@"Program validation produced errors:\n%s", log);
        free(log);
    }
    
    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    GetError();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)loadBufferData
{
    Vertex vertexData[4] = {
        { .position = { .x=-0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=0.0, .b=0.0, .a=1.0 } },
        { .position = { .x=-0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=1.0, .b=0.0, .a=1.0 } },
        { .position = { .x= 0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=0.0, .b=1.0, .a=1.0 } },
        { .position = { .x= 0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=1.0, .b=1.0, .a=1.0 } }
    };
    
    GLuint vao;
    glGenVertexArrays(1, &vao);
    GetError();
    [self setVertexArrayObject:vao];
    glBindVertexArray([self vertexArrayObject]);
    GetError();
    
    GLuint vbo;
    glGenBuffers(1, &vbo);
    GetError();
    [self setVertexBuffer:vbo];
    glBindBuffer(GL_ARRAY_BUFFER, [self vertexBuffer]);
    GetError();
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
    GetError();
    
    glEnableVertexAttribArray((GLuint)[self positionAttribute]);
    GetError();
    glEnableVertexAttribArray((GLuint)[self colourAttribute]  );
    GetError();
    glVertexAttribPointer((GLuint)[self positionAttribute], 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
    GetError();
    glVertexAttribPointer((GLuint)[self colourAttribute]  , 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, colour  ));
    GetError();
}

- (void)renderForTime:(CVTimeStamp)time
{
    [[[self view] openGLContext] makeCurrentContext];
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    GetError();
    glClear(GL_COLOR_BUFFER_BIT);
    GetError();
    
    glUseProgram([self shaderProgram]);
    GetError();
    
    GLfloat timeValue = (GLfloat)(time.videoTime) / (GLfloat)(time.videoTimeScale);
    Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };
    glUniform2fv([self positionUniform], 1, (const GLfloat *)&p);
    GetError();
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GetError();

    [[[self view] openGLContext] flushBuffer];
}

- (void)dealloc
{
    glDeleteProgram([self shaderProgram]);
    GetError();
    GLuint vbo = [self vertexBuffer];
    glDeleteBuffers(1, &vbo);
    GetError();
    [self setVertexBuffer:vbo];
    
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
    [view release];
    
    [super dealloc];
}

@end
