# Cocoa GL Tutorial

This is a simple tutorial on getting started with OpenGL on Mac OS.  It really covers two orthogonal topics.

1. How to get a Cocoa view that you can use to draw with OpenGL.
2. How to get started with basic drawing in modern OpenGL.

You can use either part of the tutorial independently.  Note that this means that even if you are targetting a platform other than MacOS, and do not intend to use Objective-C, you can still get an idea of the required GL code here.

## Why?

There are a thousand and one OpenGL tutorials out there.  Many of them are massively out of date and use bucket loads of deprecated functionality.  A few are more up to date, but use OpenGL versions that are only supported on limited hardware.  This tutorial aims to show you how to get started with OpenGL that is both modern, and runs on near-enough everything newer than 7-8 years old.

## OpenGL In Cocoa

As I said earlier, you can treat the two main parts of this tutorial independently.  If you're not using OS X, or are simply uninterested in how to get going with Cocoa, skip straight to 'Getting Started With Drawing'.

As with all Cocoa UI code, drawing begins with a view.  OpenGL is rendered in an NSOpenGLView.  To request an OpenGL 3.2 Core context (modern OpenGL) we must create the view in code as Apple's OpenGL team considers Interface Builder users too stupid to be trusted to not tick options they don't want.

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

Each OpenGL view creates an OpenGL Context to draw into.  The context object essentially isolates your OpenGL code from all other OpenGL code on the OS.  Before drawing, you must tell the OS that OpenGL commands need to be directed to this context and not the various other ones hanging around like for example the one used to composite for the window manager.  We do this by asking our view for it's OpenGL context and making it current:

    [[[self view] openGLContext] makeCurrentContext];

Once our context is bound we can get on with creating all the OpenGL resources we're going to need to draw with.  This is covered in 'Getting Started With Drawing'.

There's one other important thing to set up before we move on to actually using OpenGL.  Cocoa's normal view hierarchy redraws views only when needed.  When writing OpenGL code we typically want to animate things, so we want to refresh more often.  We could do this by repeatedly calling setNeedsDisplay on our view, but this is rather flawed.  By doing this, we may end up rendering far more often than we really need to -- we typically only want to rerender once every time the screen refreshes.  To do this, we create a display link.

A display link gives us a call back when the screen is about to refresh, and allows us to prepare a framebuffer.  So, as we awake from being loaded from the nib, we create a display link to get driving our render process:

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

This asks CoreVideo to call the function 'displayCallback' every time the screen is about to refresh.  Note that we pass self to the last argument of CVDisplayLinkSetOutputCallback.  This gives us a reference we can use to call our controller to ask it to render:

    CVReturn displayCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
    {
        GLTutorialController *controller = (GLTutorialController *)displayLinkContext;
        [controller renderForTime:*inOutputTime];
        return kCVReturnSuccess;
    }

We then make our context current, do our rendering, and swap buffers.

    - (void)renderForTime:(CVTimeStamp)time
    {
        [[[self view] openGLContext] makeCurrentContext];
        
        ...
        
        [[[self view] openGLContext] flushBuffer];
    }

## Getting Started With Drawing

We're going to see a simple example of how to draw a single quadrilateral moving around on the screen.

Drawing with OpenGL always follows the same pattern.  First we put our resources on the graphics processor.  Second, we ask the processor to draw things.  Resources can mean any number of things, for example:

* Programs to tell the processor exactly how to draw;
* mesh data for our models;
* texture data;

In this tutorial you'll see how to upload a program to draw with (also known as a shader), and how to upload mesh data to draw.  Finally, we'll look at how to instruct the GPU to draw the data.

### Shaders

When we draw using the modern programmable pipeline we always need to give the GPU a program to use to colour in our primitives.  These *shader programs* need to do at least two things:

1. *Vertex shading* - Telling the GPU how to transform our mesh data to display it.
2. *Fragment shading* - Telling the GPU how to colour in each pixel, on each polygon we draw.

Lets start by having a look at our vertex shader.  Every OpenGL shader requires a version pragrma to tell the compiler how to compile it.  We use GLSL version 1.50 as we are targetting OpenGL 3.2.

    #version 150

The vertex shader runs once for each vertex we ask the GPU to render.  We start by declaring our inputs and outputs.  The inputs to our vertex shader are passed in from our OpenGL code when we render.  And we need somewhere for them to arrive.

First, we define an input that is *uniform* across all vertices.  We'll see later that we pass a value into our uniform once for the entire data set.  In this instance, the uniform contains a 2 dimensional vector telling us where we want to render our quad.

    uniform vec2 p;

Next we define our vertex *attributes*.  Attributes are inptus to the vertex shader which are unique to each vertex.  This is where the data we want to be rendered get passed in.  In our case we want each vertex on our quad to have a position and a colour, so we define our two attributes:

    in vec4 position;
    in vec4 colour;

Finally, when OpenGL renders our quad, it's going to walk across the polygons we provide colouring pixels.  For each pixel we want a bunch of values that vary depending on where they are.  Our varyings are the outputs of the vertex shader, and are passed into the fragment shader to use to determine the fragment colour.  We want to colour each pixel differently, so we declare a single varying output, the colour.

    out vec4 colourV;

Now that we've declared our inputs and outputs, we define our program.  We pass the vertex colours through.  For positions, we use the overloaded vec4 constructor to create a 4 dimensional vector from the uniform offset p, we then add that to the position of the vertex we're dealing with:

    void main (void)
    {
        colourV = colour;
        gl_Position = vec4(p, 0.0, 0.0) + position;
    }

So that's a simple vertex shader.  Next we need to look at our fragment shader.    Again we start by declaring our inputs.  The varying we defined as an output in our vertex shader is the input for our fragment shader.  The values are interpolated between the vertices for each pixel.

    in vec4 colourV;

Our fragment shader outputs colours for our fragments.  We must declare the output variable as well.

    out vec4 fragColour;
    
We then define our program, which tells OpenGL to simply pass the interpolated colour through as the colour of the fragment:
    
    void main(void)
    {
        fragColour = colourV;
    }

### Uploading Data

Our shader program is plain text at the moment.  Clearly we need to compile it and link it.  OpenGL is expected to run on all kinds of different hardware, be it made by AMD, Imagination Technologies, Intel, nVidia, VIA or anyone else.  Because we need our code to run on such heterogenious hardware, we compile and link the shader program at runtime.

#### Uploading The Shaders

Lets work from the top down, we start by loading the text from our files and compiling it:

    - (void)loadShader
    {
        GLuint vertexShader;
        GLuint fragmentShader;
        
        vertexShader   = [self compileShaderOfType:GL_VERTEX_SHADER   file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]];
        fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER file:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];

If we successfully compiled the code, we create a program, add the vertex and fragment shaders to it.

        if (0 != vertexShader && 0 != fragmentShader)
        {
            shaderProgram = glCreateProgram();
            GetError();
            
            glAttachShader(shaderProgram, vertexShader  );
            GetError();
            glAttachShader(shaderProgram, fragmentShader);
            GetError();

We then tell OpenGL which of our colour buffers to put the fragment shader's output in.  By specifying 0 we ask for the 0th colour buffer, which by default is the back buffer for our view:

            glBindFragDataLocation(shaderProgram, 0, "fragColour");

We then link the program we've created.

            [self linkProgram:shaderProgram];

Once we have linked the program, we ask OpenGL to tell us about the uniforms and attributes in our programs.  We'll use these values later to tell OpenGL which bits of our mesh data mean what.

            positionUniform = glGetUniformLocation(shaderProgram, "p");
            GetError();
            if (positionUniform < 0)
            {
                [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'p' uniform."];
            }
            colourAttribute = glGetAttribLocation(shaderProgram, "colour");
            GetError();
            if (colourAttribute < 0)
            {
                [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'colour' attribute."];
            }
            positionAttribute = glGetAttribLocation(shaderProgram, "position");
            GetError();
            if (positionAttribute < 0)
            {
                [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];
            }

Finally, we delete the temporary compiled object code, as we've now successfully linked it into a shader program.

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


Lets look at how we compile the vertex and fragment shaders now.  First we need to get the ASCII text to compile:

    - (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file
    {
        GLuint shader;
        const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];
        
        if (nil == source)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Failed to read shader file %@", file];
        }

We ask OpenGL to create somewhere to put our shader object code:

        shader = glCreateShader(type);
        GetError();

We give OpenGL the source code:

        glShaderSource(shader, 1, &source, NULL);
        GetError();

And we ask OpenGL to compile it:

        glCompileShader(shader);
        GetError();

We now ask OpenGL to give us back the compiler log, and print it out.  This will help with debugging if we made a mistake writing our shader:

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

While the info log is interesting, the compile status is what tells us whether we succeeded in compiling the code or not.  We make sure we were successful, and return our reference to the object code:

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

Linking follows a similar pattern.  We ask OpenGL to link the program, print out the linker log, and then check the link status to make sure everything went well.

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

#### Uploading The Mesh Data

In this simple example we define our quad as an array of data in our source file.  Normally you would do this by loading a model file of some sort, but for just drawing a quad we'll take a short cut:

    - (void)loadBufferData
    {
        Vertex vertexData[4] = {
            { .position = { .x=-0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=0.0, .b=0.0, .a=1.0 } },
            { .position = { .x=-0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=1.0, .b=0.0, .a=1.0 } },
            { .position = { .x= 0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=0.0, .b=1.0, .a=1.0 } },
            { .position = { .x= 0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=1.0, .b=1.0, .a=1.0 } }
        };

The array of vertex data is all very well, but it's not where we want it.  It's stored in system RAM, instead, we want to put it on the graphics card.  To get OpenGL to store this data on the graphics card we first ask for a Vertex Array Object - this gives us a method of quickly setting up our buffer and vertex array states.  We bind the vertex array object so that future calls will affect this VAO:

        GLuint vao;
        glGenVertexArrays(1, &vao);
        GetError();
        [self setVertexArrayObject:vao];
        
        glBindVertexArray([self vertexArrayObject]);
        GetError();

We then ask for a Vertex Buffer Object to store the data in.   We tell OpenGL that future calls relating to the array buffer will be talking about the buffer we just created:


        GLuint vbo;
        glGenBuffers(1, &vbo);
        GetError();
        [self setVertexBuffer:vbo];
        
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        GetError();

Finally we upload the data.  We tell OpenGL that the data is static (we're not going to modify it lots), and we're going to use it for drawing:

        glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
        GetError();

Remember when we asked OpenGL to tell us about the attributes in our program?  Now we need to tell OpenGL how to map those attribute locations onto the data we just uploaded.  First, we tell OpenGL to enable the attributes:

        glEnableVertexAttribArray((GLuint)positionAttribute);
        GetError();
        glEnableVertexAttribArray((GLuint)colourAttribute  );
        GetError();

Now we tell OpenGL where in the currently bound buffer to find the data.  First, we tell it about the positions.  They have 4 components, each of which is a floating point value.  We don't want to normalise the data.  The data is spaced out by the size of our Vertex data structure, and you can find the first one at the offset of the position in that data structure.

        glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
        GetError();

We do the same for the colour, but this time we give the offset of the colour attribute.

        glVertexAttribPointer((GLuint)colourAttribute  , 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, colour  ));
        GetError();
    }

### Drawing

With all that data on the graphics card, we now need to make use of it.  Each time we render, we start by clearing the screen to black.  First we tell OpenGL that black is the right colour to clear to:
        
        glClearColor(0.0, 0.0, 0.0, 1.0);
        GetError();

Then we clear the colours:

        glClear(GL_COLOR_BUFFER_BIT);
        GetError();

We tell OpenGL to use the shader program we uploaded earlier:

        glUseProgram(shaderProgram);
        GetError();

Next, we need to tell OpenGL where we want the quad to be rendered this frame.  To make the quad move in a circle we use the sine and cosine of the time:

        GLfloat timeValue = (GLfloat)(time.videoTime) / (GLfloat)(time.videoTimeScale);
        Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };

We fill the uniform in the shader with the value we computed.

        glUniform2fv(positionUniform, 1, (const GLfloat *)&p);
        GetError();

Finally, we tell OpenGL to actually draw the data in our array.  We draw a triangle fan, and provide the 4 vertices in buffer.
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        GetError();
    }

## What Next

So you've got your first quad drawing, where do you go next?

* Take a look at my [second tutorial](http://www.github.org/beelsebob/Cocoa-GL-Tutorial-2), which covers adding texturing.
* Discussing things on IRC can be useful.  I recommend ##opengl on irc.freenode.org.
* Playing with the shader program will let you quickly generate different effects.
* Reading more tutorials is a good next step.  Make sure you stick with tutorials that use modern OpenGL, there's a lot out there that use old deprecated code.  I'd recommend the [ArcSynthesis](http://www.arcsynthesis.org/gltut/) tutorial if you have OpenGL 3 capable hardware.

