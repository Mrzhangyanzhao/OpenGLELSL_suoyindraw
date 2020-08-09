attribute vec4 position;
attribute vec4 positionColor;

uniform mat4 projectionMartix;
uniform mat4 modelViewMartix;

varying lowp vec4 varyColor;

void main(){
    varyColor = positionColor;
    vec4 vPos;
    vPos = projectionMartix * modelViewMartix * position;
    gl_Position = vPos;
}
