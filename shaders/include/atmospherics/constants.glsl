/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* ATMOSPHERE CONSTANTS */
const float anisoFactor = 0.76;

const float earthRad = 6371e3;
const float atmosRad = 6481e3;

const float hR = 8.40e3;
const float hM = 1.25e3;

/* CLOUDS CONSTANTS */
const float innerCloudRad = earthRad + CLOUDS_ALTITUDE;
const float outerCloudRad = innerCloudRad + CLOUDS_THICKNESS;

// Coefficients provided by Jessie#7257 and LVutner#5199

#if TONEMAP == 0
    vec3 kRlh = linearToAP1(vec3(5.8, 13.3, 33.31)    * 1e-6);
    vec3 kMie = linearToAP1(vec3(21.0)                * 1e-6);
    vec3 kOzo = linearToAP1(vec3(3.426, 8.298, 0.356) * 1e-7);
#else
    vec3 kRlh = vec3(5.8, 13.3, 33.31)    * 1e-6;
    vec3 kMie = vec3(21.0)                * 1e-6;
    vec3 kOzo = vec3(3.426, 8.298, 0.356) * 1e-7;
#endif

mat2x3 kScattering = mat2x3(kRlh, kMie);
mat3x3 kExtinction = mat3x3(kRlh, kMie * 1.11, kOzo);

vec3 atmosRayPos = vec3(0.0, earthRad + eyeAltitude, 0.0);

const float isotropicPhase = 0.079577471;

/* CELESTIAL CONSTANTS */
const float moonRad    = 1.7374e3;
const float moonDist   = 3.8440e5;
const float moonAlbedo = 0.12;

const float sunRad  = 6.9634e8;
const float sunDist = 1.496e11;
const float sunTemp = 5778.0;

const float sunAngularRad  = CELESTIAL_SIZE_MULTIPLIER * sunRad  / sunDist;
const float moonAngularRad = CELESTIAL_SIZE_MULTIPLIER * moonRad / moonDist;

vec3 sunIlluminance = vec3(1.0, 0.949, 0.937) * 125e3; // Brightness of light reaching the earth (J/m²)
vec3 sunLuminance   = sunIlluminance / (TAU * (1.0 - cos(sunAngularRad)));

vec3 moonLuminance   = moonAlbedo * sunIlluminance;
vec3 moonIlluminance = moonLuminance * (TAU * (1.0 - cos(moonAngularRad))); // The rough amount of light the moon emits that reaches the earth

vec3 illuminanceShadowLight = worldTime <= 12750 ? sunIlluminance : moonIlluminance;
