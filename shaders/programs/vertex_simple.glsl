/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 textureCoords;

void main() {
    gl_Position   = gl_ModelViewProjectionMatrix * gl_Vertex;
    textureCoords = gl_MultiTexCoord0.xy;
}
