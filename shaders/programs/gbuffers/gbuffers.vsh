/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

attribute vec4 at_tangent;
attribute vec3 mc_Entity;

out float blockId;
out vec2 texCoords;
out vec2 lmCoords;
out vec3 viewPos;
out vec3 geoNormal;
out vec4 vertexColor;
out mat3 TBN;

#ifdef TRANSLUCENT
	out vec3 waterNormals;
#endif

#include "/settings.glsl"
#define STAGE_VERTEX

#include "/include/uniforms.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"
#include "/include/utility/color.glsl"
#include "/include/fragment/water.glsl"

vec2 taaJitter(vec4 pos) {
    return taaOffsets[framemod] * (pos.w * pixelSize);
}

void main() {
	texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoords    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vertexColor = gl_Color;

    geoNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
    viewPos   = transMAD3(gl_ModelViewMatrix, gl_Vertex.xyz);

    vec3 tangent = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
	TBN 		 = mat3(tangent, cross(tangent, geoNormal), geoNormal);

	blockId 	= mc_Entity.x - 1000.0;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

	#ifdef TRANSLUCENT
		if(int(blockId + 0.5) == 1) {
			vec3 worldPos = viewToWorld(viewPos);
			worldPos.y   += calculateWaterWaves(worldPos.xz);
			waterNormals  = getWaveNormals(worldPos);

    		vec4 viewToClip = gl_ProjectionMatrix * vec4(worldToView(worldPos), 1.0);
			gl_Position     = viewToClip;
		}
	#endif

	#ifdef WEATHER
		vec3 rainWorldPos = mat3(gbufferModelViewInverse) * viewPos;
		rainWorldPos.xz  += RAIN_DIRECTION * rainWorldPos.y * RAIN_ANGLE_INTENSITY;

		vec4 rainViewToClip = gl_ProjectionMatrix * vec4(mat3(gbufferModelView) * rainWorldPos, 1.0);
		gl_Position         = rainViewToClip;
	#endif

	#ifdef ENTITY
		// Thanks Kneemund for the nametag fix
		if(vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
			gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
		}
	#endif

	#if TAA == 1
		bool canJitter = ACCUMULATION_VELOCITY_WEIGHT == 0 ? true : hasMoved();
		if(canJitter) { gl_Position.xy += taaJitter(gl_Position); }
    #endif
}
