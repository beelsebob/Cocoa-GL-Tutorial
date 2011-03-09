uniform float x;
uniform float y;

attribute vec4 position;
attribute vec4 colour;

varying vec4 colourV;

void main (void)
{
    colourV = colour;
    gl_Position = vec4(x, y, 0.0, 0.0) + position;
}
