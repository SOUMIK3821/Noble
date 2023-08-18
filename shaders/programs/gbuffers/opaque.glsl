/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX
	#define attribute in
	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;
	attribute vec2 mc_midTexCoord;

	flat out int blockId;
	out vec2 textureCoords;
	out vec2 lightmapCoords;
	out vec2 texSize;
	out vec2 botLeft;
	out vec3 viewPosition;
	out vec4 vertexColor;
	out mat3 tbn;

	#include "/include/vertex/animation.glsl"

	void main() {
		#if defined PROGRAM_HAND && RENDER_MODE == 1
			gl_Position = vec4(1.0);
			return;
		#endif

		textureCoords  = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lightmapCoords = gl_MultiTexCoord1.xy * rcp(240.0);
		vertexColor    = gl_Color;

		#if defined PROGRAM_ENTITY
			// Thanks Niemand#1929 for the nametag fix
			if(vertexColor.a >= 0.24 && vertexColor.a < 0.255) {
				gl_Position = vec4(10.0, 10.0, 10.0, 1.0);
				return;
			}
		#endif

		#if POM > 0 && defined PROGRAM_TERRAIN
			vec2 halfSize = abs(textureCoords - mc_midTexCoord);
			texSize       = halfSize * 2.0;
			botLeft       = mc_midTexCoord - halfSize;
		#endif

    	viewPosition = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

    	tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
    	tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[1] = cross(tbn[0], tbn[2]) * sign(at_tangent.w);

		blockId = int((mc_Entity.x - 1000.0) + 0.25);
	
		vec3 worldPosition = transform(gbufferModelViewInverse, viewPosition);

		#if RENDER_MODE == 0 && defined PROGRAM_TERRAIN && WAVING_PLANTS == 1
			animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(lightmapCoords.y));
		#endif
	
		gl_Position    = transform(gbufferModelView, worldPosition).xyzz * diagonal4(gl_ProjectionMatrix) + gl_ProjectionMatrix[3];
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

		#if TAA == 1 && EIGHT_BITS_FILTER == 0
			gl_Position.xy += taaJitter(gl_Position);
		#endif
	}

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 1,3 */

	layout (location = 0) out uvec4 data0;
	layout (location = 1) out vec2  data1;

	flat in int blockId;
	in vec2 textureCoords;
	in vec2 lightmapCoords;
	in vec2 texSize;
	in vec2 botLeft;
	in vec3 viewPosition;
	in vec4 vertexColor;
	in mat3 tbn;

	#if defined PROGRAM_ENTITY
		uniform vec4 entityColor;
	#endif

	#if POM > 0 && defined PROGRAM_TERRAIN
		#include "/include/fragment/parallax.glsl"
	#endif

	vec2 computeLightmap(vec3 normal) {
		#if DIRECTIONAL_LIGHTMAP == 1 && GI == 0
			// Thanks ninjamike1211 for the help
			vec2 lightmap 	   = lightmapCoords;
			vec3 scenePosition = viewToScene(viewPosition);

			vec2 blocklightDeriv = vec2(dFdx(lightmap.x), dFdy(lightmap.x));
			vec2 skylightDeriv   = vec2(dFdx(lightmap.y), dFdy(lightmap.y));

			vec3 lightmapVectorX = dFdx(scenePosition) * blocklightDeriv.x + dFdy(scenePosition) * blocklightDeriv.y;
				 lightmap.x     *= saturate(dot(normalize(lightmapVectorX), normal) + 0.8) * 0.8 + 0.2;

    		lightmap.y *= saturate(dot(vec3(0.0, 1.0, 0.0), normal) + 0.8) * 0.2 + 0.8;
		
			return any(isnan(lightmap)) || any(lessThan(lightmap, vec2(0.0))) ? lightmapCoords : lightmap;
		#endif
		return lightmapCoords;
	}

	void main() {
		vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
		if(saturate(fragCoords) != fragCoords) discard;

		#if defined PROGRAM_HAND && RENDER_MODE == 1
			discard;
		#endif

		float parallaxSelfShadowing = 1.0;

		#if POM > 0 && defined PROGRAM_TERRAIN
			vec2 coords = textureCoords;

			if(texture(normals, textureCoords).a < 1.0) {
				mat2 texDeriv = mat2(dFdx(textureCoords), dFdy(textureCoords));

				float height = 1.0, traceDistance = 0.0;
				vec2  shadowCoords = vec2(0.0);

				coords = parallaxMapping(viewPosition, texDeriv, height, shadowCoords, traceDistance);

				#if POM_SHADOWING == 1
					parallaxSelfShadowing = parallaxShadowing(shadowCoords, height, texDeriv);
				#endif

				#if POM_DEPTH_WRITE == 1
					gl_FragDepth = projectDepth(unprojectDepth(gl_FragCoord.z) + traceDistance);
				#endif
			}

			if(saturate(coords) != coords) discard;
		#else
			vec2 coords = textureCoords;
		#endif

		vec4 albedoTex = texture(tex, coords);
		if(albedoTex.a < 0.102) discard;

		vec4 normalTex = texture(normals, coords);

		#if !defined PROGRAM_TEXTURED
			vec4 specularTex = texture(specular, coords);
		#else
			vec4 specularTex = vec4(0.0);
		#endif

		albedoTex *= vertexColor;

		vec2 lightmap = lightmapCoords;

		float F0 		 = specularTex.y;
		float ao 		 = normalTex.z;
		float roughness  = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0 - specularTex.x);
		float emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
		float subsurface = saturate(specularTex.z * (maxVal8 / 190.0) - (65.0 / 190.0));

		#if defined PROGRAM_ENTITY
			albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
			
			ao = all(lessThanEqual(normalTex.rgb, vec3(EPS))) ? 1.0 : ao;
		#endif

		#if WHITE_WORLD == 1
	    	albedoTex.rgb = vec3(1.0);
    	#endif

		#if defined PROGRAM_BEACONBEAM
			if(albedoTex.a <= 1.0 - EPS) discard;
			emission = 1.0;
		#endif

		#if HARDCODED_EMISSION == 1
			if(blockId >= LAVA_ID && blockId < SSS_ID && emission <= EPS) emission = HARDCODED_EMISSION_VAL;
		#endif

		vec3 normal = tbn[2];
		#if !defined PROGRAM_BLOCK
			if(all(greaterThan(normalTex, vec4(EPS)))) {
				normal.xy = normalTex.xy * 2.0 - 1.0;
				normal.z  = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
				normal    = tbn * normal;

				if(any(greaterThan(normalTex.xy, vec2(1e-3)))) lightmap = computeLightmap(normalize(normal));
			}
		#endif

		#if defined PROGRAM_SPIDEREYES
			lightmap = vec2(lightmapCoords.x, 0.0);
		#endif

		#if defined PROGRAM_TERRAIN && RAIN_PUDDLES == 1
			if(wetness > 0.0 && isEyeInWater == 0) {
				float porosity    = saturate(specularTex.z * (maxVal8 / 64.0));
				vec2 puddleCoords = (viewToWorld(viewPosition).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE * 0.01);

				float puddle  = saturate(FBM(puddleCoords, 3, 1.0) * 0.5 + 0.5);
		  	  	  	  puddle *= pow2(quintic(0.0, 1.0, lightmapCoords.y));
	  				  puddle *= (1.0 - porosity);
			  	  	  puddle *= wetness;
			  	  	  puddle *= quintic(0.89, 0.99, tbn[2].y);
					  puddle  = saturate(puddle);
	
				F0        = clamp(F0 + waterF0 * puddle, 0.0, mix(1.0, 229.5 * rcpMaxVal8, float(F0 * maxVal8 <= 229.5)));
				roughness = mix(roughness, 0.0, puddle);
				normal    = mix(normal, tbn[2], puddle);
			}
		#endif

		vec3 labPbrData0 = vec3(parallaxSelfShadowing, saturate(lightmap));
		vec4 labPbrData1 = vec4(ao, emission, F0, subsurface);
		vec4 labPbrData2 = vec4(albedoTex.rgb, roughness);
		vec2 encNormal   = encodeUnitVector(normalize(normal));
	
		uvec4 shiftedData0  = uvec4(round(labPbrData0 * labPbrData0Range), blockId) << uvec4(0, 1, 14, 26);
		uvec4 shiftedData1  = uvec4(round(labPbrData1 * maxVal8                  )) << uvec4(0, 8, 16, 24);
		uvec4 shiftedData2  = uvec4(round(labPbrData2 * maxVal8                  )) << uvec4(0, 8, 16, 24);
		uvec2 shiftedNormal = uvec2(round(encNormal   * maxVal16                 )) << uvec2(0, 16);

		data0.x = shiftedData0.x  | shiftedData0.y | shiftedData0.z | shiftedData0.w;
		data0.y = shiftedData1.x  | shiftedData1.y | shiftedData1.z | shiftedData1.w;
		data0.z = shiftedData2.x  | shiftedData2.y | shiftedData2.z | shiftedData2.w;
		data0.w = shiftedNormal.x | shiftedNormal.y;

		data1 = encodeUnitVector(normalize(tbn[2]));
	}
#endif
