uniform vec2 p;

attribute vec4 position;
attribute vec4 colour;

varying vec4 colourV;

void main (void)
{
    colourV = colour;
    gl_Position = vec4(p, 0.0, 0.0) + position;
}
