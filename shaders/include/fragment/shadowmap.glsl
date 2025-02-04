/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

const float invShadowMapResolution = 1.0 / shadowMapResolution;

/*
float contactShadow(vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter) {
    vec3 rayPosition  = viewToScreen(viewPosition);
         rayDirection = normalize(viewToScreen(viewPosition + rayDirection) - rayPosition);

    const float contactShadowDepthLenience = 0.2;

    vec3 increment    = rayDirection * (contactShadowDepthLenience * rcp(stepCount));
         rayPosition += increment * (1.0 + jitter);

    for(int i = 0; i <= stepCount; i++, rayPosition += increment) {
        if(saturate(rayPosition.xy) != rayPosition.xy) return 1.0;

        float depth = texelFetch(depthtex1, ivec2(rayPosition.xy * viewSize), 0).r;
        if(depth >= rayPosition.z) return 1.0;

                 depth = linearizeDepth(depth);
        float rayDepth = linearizeDepth(rayPosition.z);

        if(abs(depth - rayDepth) / depth < contactShadowDepthLenience) return 0.0;
    }
    return 1.0;
}
*/

vec3 worldToShadow(vec3 worldPosition) {
	return projectOrthogonal(shadowProjection, transform(shadowModelView, worldPosition));
}

float visibility(sampler2D tex, vec3 samplePos) {
    return step(samplePos.z, texelFetch(tex, ivec2(samplePos.xy * shadowMapResolution), 0).r);
}

vec3 getShadowColor(vec3 samplePos) {
    if(saturate(samplePos) != samplePos) return vec3(1.0);

    float shadowDepth0 = visibility(shadowtex0, samplePos);
    float shadowDepth1 = visibility(shadowtex1, samplePos);
    vec4  shadowColor  = texelFetch(shadowcolor0, ivec2(samplePos.xy * shadowMapResolution), 0);
    
    #if TONEMAP == ACES
        shadowColor.rgb = srgbToAP1Albedo(shadowColor.rgb);
    #else
        shadowColor.rgb = srgbToLinear(shadowColor.rgb);
    #endif

    return mix(vec3(shadowDepth0), shadowColor.rgb * (1.0 - shadowColor.a), saturate(shadowDepth1 - shadowDepth0));
}

float rng = interleavedGradientNoise(gl_FragCoord.xy);

#if SHADOWS == 1 
    #if SHADOW_TYPE == 1
        float findBlockerDepth(vec2 shadowCoords, float shadowDepth, out float subsurfaceDepth) {
            float blockerDepthSum    = 0.0;
            float subsurfaceDepthSum = 0.0;

            float weightSum = 0.0;

            for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
                vec2 offset       = BLOCKER_SEARCH_RADIUS * sampleDisk(i, BLOCKER_SEARCH_SAMPLES, rng) * invShadowMapResolution;
                vec2 sampleCoords = distortShadowSpace(shadowCoords + offset) * 0.5 + 0.5;
                
                if(saturate(sampleCoords) != sampleCoords) return -1.0;

                float depth  = texelFetch(shadowtex0, ivec2(sampleCoords * shadowMapResolution), 0).r;
                float weight = step(depth, shadowDepth);

                blockerDepthSum += depth * weight;
                weightSum       += weight;

                subsurfaceDepthSum += max0(shadowDepth - depth);
            }
            // Subsurface depth calculation from sixthsurge
            // -shadowProjectionInverse[2].z helps us convert the depth to a meters scale
            subsurfaceDepth = (-shadowProjectionInverse[2].z * subsurfaceDepthSum) / (SHADOW_DEPTH_STRETCH * BLOCKER_SEARCH_SAMPLES);

            return weightSum == 0.0 ? -1.0 : blockerDepthSum / weightSum;
        }
    #endif

    vec3 PCF(vec3 shadowPosition, float penumbraSize) {
	    vec3 shadowResult = vec3(0.0); vec2 offset = vec2(0.0);

        for(int i = 0; i < SHADOW_SAMPLES; i++) {
            #if SHADOW_TYPE != 2
                offset = sampleDisk(i, SHADOW_SAMPLES, rng) * penumbraSize * invShadowMapResolution;
            #endif

            vec3 samplePos = distortShadowSpace(shadowPosition + vec3(offset, 0.0)) * 0.5 + 0.5;
            shadowResult  += getShadowColor(samplePos);
        }
        return shadowResult * rcp(SHADOW_SAMPLES);
    }
#endif

vec3 calculateShadowMapping(vec3 scenePosition, vec3 geometricNormal, out float subsurfaceDepth) {
    #if SHADOWS == 1 
        vec3  shadowPosition = worldToShadow(scenePosition);
        float NdotL          = dot(geometricNormal, shadowLightVector);

        // Shadow bias implementation from Emin and concept from gri573
        float biasAdjust = log2(max(4.0, shadowDistance - shadowMapResolution * 0.125)) * 0.35;
        shadowPosition  += mat3(shadowProjection) * (mat3(shadowModelView) * geometricNormal) * getDistortionFactor(shadowPosition.xy) * biasAdjust;
        shadowPosition  *= 1.0002;

        float penumbraSize = NORMAL_SHADOW_PENUMBRA;

        subsurfaceDepth = 0.0;

        #if SHADOW_TYPE == 1
            vec3  shadowPosDistort = distortShadowSpace(shadowPosition) * 0.5 + 0.5;
            float avgBlockerDepth  = findBlockerDepth(shadowPosition.xy, shadowPosDistort.z, subsurfaceDepth);

            if(avgBlockerDepth < EPS) {
                subsurfaceDepth = 1.0;
                return vec3(-1.0);
            }

            if(NdotL < EPS) return vec3(0.0);

            if(texture(shadowcolor0, shadowPosDistort.xy).a > 0.0)
                penumbraSize = max(MIN_SHADOW_PENUMBRA, LIGHT_SIZE * (shadowPosDistort.z - avgBlockerDepth) / avgBlockerDepth);
            else
                penumbraSize = WATER_CAUSTICS_BLUR_RADIUS;
        #endif

        return PCF(shadowPosition, penumbraSize);
    #else
        return vec3(1.0);
    #endif
}
