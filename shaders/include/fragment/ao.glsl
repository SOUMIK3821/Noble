/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [References]:
        LearnOpenGL. (2015). SSAO. https://learnopengl.com/Advanced-Lighting/SSAO
		Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
		Jimenez et al. (2016). Practical Realtime Strategies for Accurate Indirect Occlusion. https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
*/

#if AO_TYPE == 0

	float SSAO(vec3 viewPosition, vec3 normal) {
		float occlusion = 0.0;

		for(int i = 0; i < SSAO_SAMPLES; i++) {
			vec3 rayDirection = generateCosineVector(normal, rand2F());
			vec3 rayPosition  = viewPosition + rayDirection * SSAO_RADIUS;
			float rayDepth    = getViewPosition0(viewToScreen(rayPosition).xy).z;

			float rangeCheck = quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPosition.z - rayDepth));
        	occlusion 		+= (rayDepth >= rayPosition.z + EPS ? 1.0 : 0.0) * rangeCheck;
		}
		return pow(1.0 - occlusion * rcp(SSAO_SAMPLES), SSAO_STRENGTH);
	}

#elif AO_TYPE == 1

	float RTAO(vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
		vec3 rayPosition = viewPosition + normal * 1e-2;
		float occlusion  = 1.0;

		vec3 hitPosition = vec3(0.0);

		for(int i = 0; i < RTAO_SAMPLES; i++) {
			vec3 rayDirection = generateCosineVector(normal, rand2F());

			if(!raytrace(depthtex1, rayPosition, rayDirection, RTAO_STEPS, randF(), hitPosition)) {
				bentNormal += rayDirection;
				continue;
			}
			occlusion -= rcp(RTAO_SAMPLES);
		}
		bentNormal = normalize(bentNormal);
		return occlusion;
	}
#else

	float multiBounceApprox(float visibility) { 
    	const float albedo = 0.2; 
    	return visibility / (albedo * visibility + (1.0 - albedo)); 
 	}

	float findMaximumHorizon(vec2 coords, vec3 viewPosition, vec3 viewDirection, vec3 normal, vec3 sliceDir, vec2 radius) {
		float horizonCos = -1.0;

		vec2 stepSize  		= radius * rcp(GTAO_HORIZON_STEPS);
		vec2 increment 		= sliceDir.xy * stepSize;
		vec2 screenPosition = coords + rand2F() * increment;

		for(int i = 0; i < GTAO_HORIZON_STEPS; i++, screenPosition += increment) {
			float depth = texelFetch(depthtex0, ivec2(screenPosition * viewSize), 0).r;
			if(saturate(screenPosition) != screenPosition || depth == 1.0 || isHand(screenPosition)) continue;

			vec3 horizonVec = screenToView(vec3(screenPosition, depth)) - viewPosition;
			float cosTheta  = mix(dot(horizonVec, viewDirection) * fastRcpLength(horizonVec), -1.0, linearStep(2.0, 3.0, lengthSqr(horizonVec)));
		
			horizonCos = max(horizonCos, cosTheta);
		}
		return fastAcos(horizonCos);
	}

	float GTAO(vec2 coords, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
		float visibility = 0.0;

		float rcpViewLength = fastRcpLength(viewPosition);
		vec2 radius  		= GTAO_RADIUS * rcpViewLength * rcp(vec2(1.0, aspectRatio));
		vec3 viewDirection  = viewPosition * -rcpViewLength;

		for(int i = 0; i < GTAO_SLICES; i++) {
			float sliceAngle = (PI * rcp(GTAO_SLICES)) * (i + randF());
			vec3  sliceDir   = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

			vec3 orthoDir   = sliceDir - dot(sliceDir, viewDirection) * viewDirection;
			vec3 axis       = cross(sliceDir, viewDirection);
			vec3 projNormal = normal - axis * dot(normal, axis);

			float sgnGamma = sign(dot(projNormal, orthoDir));
			float normLen  = fastRcpLength(projNormal);
			float cosGamma = saturate(dot(projNormal, viewDirection) * normLen);
			float gamma    = sgnGamma * fastAcos(cosGamma);

			vec2 horizons;
			horizons.x = -findMaximumHorizon(coords, viewPosition, viewDirection, normal,-sliceDir, radius);
			horizons.y =  findMaximumHorizon(coords, viewPosition, viewDirection, normal, sliceDir, radius);
			horizons   = gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);
			
			vec2 arc    = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);
			visibility += dot(arc, vec2(0.25)) * normLen;

			float bentAngle = dot(horizons, vec2(0.5));
			bentNormal 	   += viewDirection * cos(bentAngle) + orthoDir * sin(bentAngle);
		}
		bentNormal = normalize(normalize(bentNormal) - 0.5 * viewDirection);
		return multiBounceApprox(visibility * rcp(GTAO_SLICES));
	}
#endif
