/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:09 */

layout (location = 0) out vec4 albedo;
layout (location = 1) out vec4 shadowmap;

#include "/include/material.glsl"
#include "/include/fragment/water.glsl"

void main() {
   vec4 rain = RGBtoLinear(texture(colortex5, texCoords));
   shadowmap = texture(colortex9, texCoords);

   // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
   #if WATER_CAUSTICS == 1
      bool canCast = isEyeInWater > 0.5 ? true : getBlockId(texCoords) == 1;
      if(canCast) { shadowmap.rgb *= waterCaustics(texCoords); }
   #endif

   #if WHITE_WORLD == 1
	   albedo = vec4(1.0);
      return;
   #endif

   vec4 albedoTex = texture(colortex0, texCoords);

   albedo.rgb = RGBtoLinear(albedoTex.rgb);
   albedo    += rain;
}
