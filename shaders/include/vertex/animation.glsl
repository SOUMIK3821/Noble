/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

const float windSpeed = 1.4;
       vec3 windDir   = windSpeed * frameTimeCounter * vec3(-0.2, 0.35, -1.0);

void wavingLeaves(inout vec3 worldPosition, float skyFalloff) {
    worldPosition += (sin(worldPosition * (1.0 + FBM(worldPosition * 0.7, 1, 1.0)) + windDir * 1.5) * vec3(0.2, 0.3, 0.2)) * 0.2 * skyFalloff;
}

void wavingPlants(inout vec3 worldPosition, float skyFalloff, bool isTopVertex, bool isTopBlock) {
	vec2 offset  = (sin(worldPosition.xz * (1.0 + FBM(worldPosition.xz, 1, 1.5)) + windDir.xz * vec2(2.0))) * 0.1 + vec2(0.06, -0.03);
		 offset *= (isTopBlock ? 1.5 : float(isTopVertex)) * skyFalloff;

	worldPosition.xz += offset;
}

void animate(inout vec3 worldPosition, bool isTopVertex, float skyFalloff) {
	worldPosition += cameraPosition;
	
	switch(blockId) {
		case LEAVES_ID:              wavingLeaves(worldPosition, skyFalloff);                     break;
		case DOUBLE_PLANTS_LOWER_ID: wavingPlants(worldPosition, skyFalloff, isTopVertex, false); break;
		case DOUBLE_PLANTS_UPPER_ID: wavingPlants(worldPosition, skyFalloff, isTopVertex, true);  break;
		case PLANTS_ID:              wavingPlants(worldPosition, skyFalloff, isTopVertex, false); break;
	}
	worldPosition -= cameraPosition;
}
