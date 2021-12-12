/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
                        - CREDITS -
    Thanks Bálint#1673 and Jessie#7257 for their huge help!
*/

#if GI == 1
    vec3 specularBRDF(float NdotL, vec3 fresnel, in float roughness) {
        float k = roughness + 1.0;
        return fresnel * geometrySchlickGGX(NdotL, (k * k) * 0.125);
    }

    vec3 directBRDF(vec3 N, vec3 V, vec3 L, material mat, vec3 shadowmap, vec3 celestialIlluminance) {
        vec3 specular = SPECULAR == 0 ? vec3(0.0) : cookTorranceSpecular(N, V, L, mat);
        vec3 diffuse  = mat.isMetal   ? vec3(0.0) : hammonDiffuse(N, V, L, mat);

        return (diffuse + specular) * shadowmap * celestialIlluminance;
    }

    vec3 pathTrace(in vec3 screenPos) {
        vec3 radiance = vec3(0.0);
        vec3 viewPos  = screenToView(screenPos); 

        vec3 celestialIlluminance = vec3(1.0);
        #if WORLD == OVERWORLD
            celestialIlluminance = worldTime <= 12750 ? 
              atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance
            : atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
        #endif

        for(int i = 0; i < GI_SAMPLES; i++) {
            vec3 throughput = vec3(1.0);

            vec3 hitPos = screenPos; 
            vec3 rayDir = normalize(viewPos);
            vec3 prevDir;

            for(int j = 0; j <= GI_BOUNCES; j++) {
                vec2 noise = uniformAnimatedNoise(vec2(randF(rngState), randF(rngState)));
                prevDir    = rayDir;

                /* Russian Roulette */
                if(j > 3) {
                    float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                    if(roulette < randF(rngState)) { break; }
                    throughput /= roulette;
                }
                float HdotV = maxEps(dot(normalize(-prevDir + rayDir), -prevDir));

                /* Material Parameters */
                material mat = getMaterial(hitPos.xy);
                mat.albedo   = texture(colortex4, hitPos.xy).rgb;
                mat3 TBN     = constructViewTBN(mat.normal);

                radiance += throughput * mat.albedo * BLOCKLIGHT_MULTIPLIER * mat.emission;
                radiance += throughput * directBRDF(mat.normal, -prevDir, shadowDir, mat, texture(colortex9, hitPos.xy).rgb, celestialIlluminance);

                /* Specular Bounce Probability */
                float fresnelLum    = luminance(specularFresnel(HdotV, getSpecularColor(mat.F0, mat.albedo), mat.isMetal));
                float diffuseLum    = fresnelLum / (fresnelLum + luminance(mat.albedo) * (1.0 - float(mat.isMetal)) * (1.0 - fresnelLum));
                float specularProb  = fresnelLum / maxEps(fresnelLum + diffuseLum);
                bool specularBounce = specularProb > randF(rngState);

                vec3 microfacet = sampleGGXVNDF(-prevDir * TBN, noise, pow2(mat.rough));
                rayDir          = specularBounce ? reflect(prevDir, TBN * microfacet) : generateCosineVector(mat.normal, noise);

                float NdotL  = maxEps(dot(mat.normal, rayDir));
                float HdotL  = maxEps(dot(normalize(-prevDir + rayDir), rayDir));
                vec3 fresnel = specularFresnel(HdotL, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);

                if(NdotL <= 0.0) break;

                if(specularBounce) {
                    throughput *= specularBRDF(NdotL, fresnel, mat.rough) / specularProb;
                } else {
                    throughput *= (1.0 - fresnelDielectric(NdotL, F0toIOR(mat.F0))) / (1.0 - specularProb);
                    throughput *= hammonDiffuse(mat.normal, -prevDir, rayDir, mat) / (NdotL * INV_PI);
                }

                if(!raytrace(screenToView(hitPos), rayDir, GI_STEPS, randF(rngState), hitPos)) { break; }
            }
        }
        return max0(radiance) / GI_SAMPLES;
    }
#endif
