/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
	[Credits]
		Null (https://github.com/null511)
		ninjamike1211
			
		Thanks to them for their help!
*/

const float layerHeight = 1.0 / float(POM_LAYERS);


#if POM_DEPTH_WRITE == 1
    float projectDepth(float depth) {
        return (-gbufferProjection[2].z * depth + gbufferProjection[3].z) / depth * 0.5 + 0.5;
    }

    float unprojectDepth(float depth) {
        return gbufferProjection[3].z / (gbufferProjection[2].z + depth * 2.0 - 1.0);
    }
#endif

void wrapCoordinates(inout vec2 coords) {
    coords -= floor((coords - botLeft) / texSize) * texSize;
}

vec2 localToAtlas(vec2 localCoords) {
    return (fract(localCoords) * texSize + botLeft);
}

vec2 atlasToLocal(vec2 atlasCoords) {
    return (atlasCoords - botLeft) / texSize;
}

#if POM == 1
	float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
		wrapCoordinates(coords);
		return 1.0 - textureGrad(normals, coords, texDeriv[0], texDeriv[1]).a;
	}
#else
	#include "/include/utility/sampling.glsl"

	float sampleHeightMap(inout vec2 coords, mat2 texDeriv) {
		wrapCoordinates(coords);

		vec2 uv[4];
		vec2 f = getLinearCoords(atlasToLocal(coords), texSize * atlasSize, uv);

		uv[0] = localToAtlas(uv[0]);
		uv[1] = localToAtlas(uv[1]);
		uv[2] = localToAtlas(uv[2]);
		uv[3] = localToAtlas(uv[3]);

    	return 1.0 - textureGradLinear(normals, uv, texDeriv, f, 3);
	}
#endif

float dither = interleavedGradientNoise(gl_FragCoord.xy);

vec2 parallaxMapping(vec3 viewPosition, mat2 texDeriv, inout float height, out vec2 shadowCoords, out float traceDistance) {
	vec3 tangentDirection = normalize(viewToScene(viewPosition)) * tbn;
    traceDistance = 0.0;

    vec2 increment = (tangentDirection.xy / tangentDirection.z) * POM_DEPTH * texSize * layerHeight;

    vec2  currCoords     = textureCoords;
    float currFragHeight = sampleHeightMap(currCoords, texDeriv);

    for(int i = 0; i < POM_LAYERS && traceDistance < currFragHeight; i++) {
        currCoords    -= increment * (dither * 0.5 + 0.5);
        currFragHeight = sampleHeightMap(currCoords, texDeriv);
        traceDistance += layerHeight;
    }

	vec2 prevCoords = currCoords + increment;

	#if POM == 1
		height       = traceDistance;
		shadowCoords = prevCoords;
		return currCoords;
	#else
	    float afterHeight  = currFragHeight - traceDistance;
		float beforeHeight = sampleHeightMap(prevCoords, texDeriv) - traceDistance + layerHeight;
		float weight       = afterHeight / (afterHeight - beforeHeight);

		vec2 smoothenedCoords = mix(currCoords, prevCoords, weight);

		height       = sampleHeightMap(smoothenedCoords, texDeriv);
		shadowCoords = smoothenedCoords;
		return smoothenedCoords;
	#endif
}

#if POM_SHADOWING == 1
    float parallaxShadowing(vec2 parallaxCoords, float height, mat2 texDeriv) {
	    vec3  tangentDirection = shadowLightVector * tbn;
        float currLayerHeight  = height;

        vec2 increment = (tangentDirection.xy / tangentDirection.z) * POM_DEPTH * texSize * layerHeight;

        vec2  currCoords     = parallaxCoords;
        float currFragHeight = 1.0;

        for(int i = 0; i < POM_LAYERS; i++) {
		    if(currLayerHeight >= currFragHeight) return 0.0;

            currCoords      += increment * dither;
            currFragHeight   = sampleHeightMap(currCoords, texDeriv);
            currLayerHeight -= layerHeight;
        }
 	    return 1.0;
    }
#endif
