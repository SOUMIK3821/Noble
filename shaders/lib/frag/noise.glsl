/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

// Functions below aren't my property. They either are public domain
// or require to credit the author.

const vec2 poisson32[32] = vec2[](
    vec2(-0.975402, -0.0711386),
    vec2(-0.920347, -0.41142),
    vec2(-0.883908, 0.217872),
    vec2(-0.884518, 0.568041),
    vec2(-0.811945, 0.90521),
    vec2(-0.792474, -0.779962),
    vec2(-0.614856, 0.386578),
    vec2(-0.580859, -0.208777),
    vec2(-0.53795, 0.716666),
    vec2(-0.515427, 0.0899991),
    vec2(-0.454634, -0.707938),
    vec2(-0.420942, 0.991272),
    vec2(-0.261147, 0.588488),
    vec2(-0.211219, 0.114841),
    vec2(-0.146336, -0.259194),
    vec2(-0.139439, -0.888668),
    vec2(0.0116886, 0.326395),
    vec2(0.0380566, 0.625477),
    vec2(0.0625935, -0.50853),
    vec2(0.125584, 0.0469069),
    vec2(0.169469, -0.997253),
    vec2(0.320597, 0.291055),
    vec2(0.359172, -0.633717),
    vec2(0.435713, -0.250832),
    vec2(0.507797, -0.916562),
    vec2(0.545763, 0.730216),
    vec2(0.56859, 0.11655),
    vec2(0.743156, -0.505173),
    vec2(0.736442, -0.189734),
    vec2(0.843562, 0.357036),
    vec2(0.865413, 0.763726),
    vec2(0.872005, -0.927)
);

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 4.1414))) * 43758.5453);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)), 
			      dot(p, vec2(269.5, 183.3)), 
			      dot(p, vec2(419.2, 371.9)));
	return fract(sin(q) * 43758.5453);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
		     dot(p, vec3(269.5, 183.3, 246.1)),
		     dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

vec4 hash43(vec3 p) {
	vec4 p4 = fract(vec4(p.xyzx) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float noise(vec2 p) {
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);

	float res = mix(
		mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
		mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
	return res * res;
}

const vec3 interleavedConstants = vec3(0.06711056, 0.00583715, 52.9829189);

float interleavedGradientNoise(vec2 p) {
    float f = interleavedConstants.x * p.x + interleavedConstants.y * p.y;
    return fract(interleavedConstants.z * fract(f));
}

vec2 interleavedGradientNoise2D(vec2 p) {
    vec2 x = vec2(dot(p, interleavedConstants.xy), dot(p, interleavedConstants.yx));
    return fract(interleavedConstants.z * fract(x));
}

float FBM(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < FBM_OCTAVES; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Gold Noise ©2015 dcerisano@standard3d.com

float gold_noise(in vec2 xy, in float seed){
    return fract(tan(distance(xy * GOLDEN_RATIO, xy) * seed) * xy.x);
}

//	<https://www.shadertoy.com/view/Xd23Dh>
//	by inigo quilez <http://iquilezles.org/www/articles/voronoise/voronoise.htm>
float voronoise(in vec2 p, float u, float v) {
	float k = 1.0 + 63.0 * pow(1.0 - v, 6.0);
    vec2 i = floor(p);
    vec2 f = fract(p);
	vec2 a = vec2(0.0, 0.0);

    for(int y = -2; y <= 2; y++) {
        for(int x = -2; x <= 2; x++) {

            vec2 g = vec2(x, y);
		    vec3 o = hash32(i + g) * vec3(u, u, 1.0);
		    vec2 d = g - f + o.xy;
		    float w = pow(1.0 - smoothstep(0.0, 1.414, length(d)), k);
		    a += vec2(o.z * w, w);
        }
    }
    return a.x / a.y;
}

/*
#define KERNEL_RADIUS 25
#define SHARPNESS 0.9

vec4 blurFunction(vec2 uv, float r, vec4 color, float depth, inout float weight) {
    vec4 c = texture2D(colortex0, uv);
    float d = texture2D(colortex1, uv).r;
  
    float blurSigma = float(KERNEL_RADIUS) * 0.5;
    float blurFalloff = 1.0 / (2.0 * blurSigma * blurSigma);
  
    float ddiff = (d - depth) * SHARPNESS;
    float w = exp2(-r * r * blurFalloff - ddiff * ddiff);
    weight += w;

    return c * w;
}

vec4 bilateralBlur(vec4 color, float depth) {
    float weight = 1.0;
    vec2 resolution = vec2(1.0 / viewWidth, 0.0);
  
    for (float r = 0; r < KERNEL_RADIUS; r++) {
        vec2 uv = texCoords + resolution * r;
        color += blurFunction(uv, r, color, depth, weight);  
    }
  
    for (float r = 0; r < KERNEL_RADIUS; r++) {
        vec2 uv = texCoords - resolution * r;
        color += blurFunction(uv, r, color, depth, weight);  
    }
    return color / weight;
}
*/

/*------------------ DENOISER BY BRUTPITT ------------------*/
// https://github.com/BrutPitt/glslSmartDeNoise/ //

vec4 smartDeNoise(sampler2D tex, vec2 uv, float sigma, float kSigma, float threshold) {
    float radius = floor(kSigma*sigma + 0.5);
    radius = RADIUS;
    float radQ = radius * radius;
    
    float invSigmaQx2 = 0.5 / (sigma * sigma);     // 1.0 / (sigma^2 * 2.0)
    float invSigmaQx2PI = INV_PI * invSigmaQx2;    // 1.0 / (sqrt(PI) * sigma)
    
    float invThresholdSqx2 = .5 / (threshold * threshold);     // 1.0 / (sigma^2 * 2.0)
    float invThresholdSqrt2PI = INV_SQRT_OF_2PI / threshold;   // 1.0 / (sqrt(2*PI) * sigma)
    
    vec4 centrPx = texture2D(tex, uv);
    float zBuff = 0.0;
    vec4 aBuff = vec4(0.0);
    
    for(float x = -radius; x <= radius; x++) {
        float pt = sqrt(radQ - x * x);  

        for(float y = -pt; y <= pt; y++) {
            vec2 d = vec2(x, y);

            float blurFactor = exp(-dot(d, d) * invSigmaQx2) * invSigmaQx2PI; 
            vec4 walkPx = texture2D(tex, uv + d / vec2(viewWidth, viewHeight));

            vec4 dC = walkPx - centrPx;
            float deltaFactor = exp(-dot(dC, dC) * invThresholdSqx2) * invThresholdSqrt2PI * blurFactor;
                                 
            zBuff += deltaFactor;
            aBuff += deltaFactor * walkPx;
        }
    }
    return aBuff / zBuff;
}
