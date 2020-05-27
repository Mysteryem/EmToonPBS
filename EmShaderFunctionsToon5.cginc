#include "UnityStandardUtils.cginc"
#include "EmShaderLighting.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityCG.cginc"

struct FragmentCommonDataPlus {
    half3 diffColor, specColor;
    half oneMinusReflectivity, smoothnessX, smoothnessY, anisotropy;
    float3 normalWorld, tangentWorld, bitangentWorld;
    float3 eyeVec;
    half alpha;
    float3 posWorld;
};

struct GlossyEnvironmentDataPlus {
    half perceptualRoughness,perceptualRoughnessX, perceptualRoughnessY;
    half3 reflUVW;
    half reflectionFallbackMultiplier;
};

half sqr(half x) {
  return x * x;
}

// GGX specular
half GGXNormalDistribution(half roughness, half NdotH) {
    // UnityStandardBRDF: // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
    //roughness = max(roughness, 0.002);
    half roughnessSqr = roughness*roughness;
    half NdotHSqr = NdotH*NdotH;
    half TanNdotHSqr = (1-NdotHSqr)/NdotHSqr;
    return (1.0/3.1415926535) * sqr(roughness/(NdotHSqr * (roughnessSqr + TanNdotHSqr)));
}

// Smith Joint GGX Anisotropic Visibility
// Taken from https://cedec.cesa.or.jp/2015/session/ENG/14698.html
float SmithJointGGXAnisotropic(float TdotV, float BdotV, float NdotV, float TdotL, float BdotL, float NdotL, float roughnessX, float roughnessY)
{
  //TdotV = abs(TdotV);
  //BdotV = abs(BdotV);
  //NdotV = abs(NdotV);
  //TdotL = abs(TdotL);
  //BdotL = abs(BdotL);
  //NdotL = abs(NdotL);
	float aT = max(0.000001, roughnessX);
	float aT2 = aT * aT;
	float aB = max(0.000001, roughnessY);
	float aB2 = aB * aB;

	float lambdaV = NdotL * sqrt(aT2 * TdotV * TdotV + aB2 * BdotV * BdotV + NdotV * NdotV);
	float lambdaL = NdotV * sqrt(aT2 * TdotL * TdotL + aB2 * BdotL * BdotL + NdotL * NdotL);

	
  float visibility = saturate(0.5 / (lambdaV + lambdaL));
  
  float cap = 25 *
  (max(1-RoughnessToPerceptualRoughness(roughnessX), 1-RoughnessToPerceptualRoughness(roughnessY)));
  //return min(cap, visibility);
  return visibility;
}

float absMax(float maxAbs, float f) {
  return max(maxAbs, abs(f)) * sign(f);
}

// Anisotropic GGX
// From HDRenderPipeline
float D_GGXAnisotropic(float TdotH, float BdotH, float NdotH, float roughnessT, float roughnessB)
{
  //TdotH = abs(TdotH);
  //BdotH = abs(BdotH);
  //NdotH = abs(NdotH);
  //TdotH = saturate(TdotH);
  //BdotH = saturate(BdotH);
  //NdotH = saturate(NdotH);
  //float testMax = 0;
  //BdotH = absMax(testMax, BdotH);
  //TdotH = absMax(testMax, TdotH);
  //NdotH = absMax(testMax, NdotH);
  roughnessT = max(0.000001, roughnessT);
  roughnessB = max(0.000001, roughnessB);
  //roughnessT = 1;
  //roughnessB = 1;
	float f = TdotH * TdotH / (roughnessT * roughnessT) + BdotH * BdotH / (roughnessB * roughnessB) + NdotH * NdotH;
	float aniso = 1.0 / (roughnessT * roughnessB * f * f);
  // Prevents overbrightening with weird normals (f -> 0)
  float brightnessCap = 25 *
  (max(1-RoughnessToPerceptualRoughness(roughnessB), 1-RoughnessToPerceptualRoughness(roughnessT)));
  //return min(brightnessCap, aniso);
  return aniso;
}

inline half SpecialRemap2(half softness, half width, half input, float fwidth) {
  half2 fresStep = .5 + float2(-1, 1) * fwidth;
  input *= width;
  half2 fresStep_var = lerp(float2(0.0, 1.0), fresStep, 1-softness);
  return smoothstep(fresStep_var.x, fresStep_var.y, input);
}

half SpecialRemap(half softness, half width, half input) {
  return SpecialRemap2(softness, width, input, fwidth(input));
}

float3 HUEtoRGB(in float H)
{
  float R = abs(H * 6 - 3) - 1;
  float G = 2 - abs(H * 6 - 2);
  float B = 2 - abs(H * 6 - 4);
  return saturate(float3(R,G,B));
}

float3 HSVtoRGB(in float3 HSV)
{
  float3 RGB = HUEtoRGB(HSV.x);
  return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

static const float Epsilon = 1e-10;
 
float3 RGBtoHCV(in float3 RGB)
{
  // Based on work by Sam Hocevar and Emil Persson
  float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
  float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
  float C = Q.x - min(Q.w, Q.y);
  float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
  return float3(H, C, Q.x);
}

float3 RGBtoHSV(in float3 RGB)
{
  float3 HCV = RGBtoHCV(RGB);
  float S = HCV.y / (HCV.z + Epsilon);
  return float3(HCV.x, S, HCV.z);
}

float4x4 axis_matrix(float3 right, float3 up, float3 forward)
{
    float3 xaxis = right;
    float3 yaxis = up;
    float3 zaxis = forward;
    return float4x4(
		xaxis.x, yaxis.x, zaxis.x, 0,
		xaxis.y, yaxis.y, zaxis.y, 0,
		xaxis.z, yaxis.z, zaxis.z, 0,
		0, 0, 0, 1
	);
}

// http://stackoverflow.com/questions/349050/calculating-a-lookat-matrix
float4x4 look_at_matrix(float3 at, float3 eye, float3 up)
{
    float3 zaxis = normalize(at - eye);
    float3 xaxis = normalize(cross(up, zaxis));
    float3 yaxis = cross(zaxis, xaxis);
    return axis_matrix(xaxis, yaxis, zaxis);
}

float GTR2_aniso(float NdotH, float HdotX, float HdotY, float ax, float ay)
{
    return 1 / (UNITY_PI * ax*ay * sqr( sqr(HdotX/ax) + sqr(HdotY/ay) + NdotH*NdotH ));
}

float smithG_GGX_aniso(float NdotV, float VdotX, float VdotY, float ax, float ay)
{
    return 1 / (NdotV + sqrt( sqr(VdotX*ax) + sqr(VdotY*ay) + sqr(NdotV) ));
}

float cibbiAnisoSpec(float NdotH, float HdotX, float HdotY, float NdotV, float VdotX, float VdotY, float LdotV, float LdotX, float LdotY, float NdotL, float ax, float ay) {
  float aniso = GTR2_aniso(NdotH, HdotX, HdotY, ax, ay)
  * smithG_GGX_aniso(NdotV, VdotX, VdotY, ax, ay)
  * smithG_GGX_aniso(NdotL, LdotX, LdotY, ax, ay)
  * UNITY_PI;
  return max(0, aniso * NdotL);
}

// From xiexe's xstoon
//Reflection direction, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
half3 getReflectionUV(half3 direction, half3 position, half4 cubemapPosition, half3 boxMin, half3 boxMax) 
{
    #if UNITY_SPECCUBE_BOX_PROJECTION
    UNITY_BRANCH
    if (cubemapPosition.w > 0) {
        half3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
        half scalar = min(min(factors.x, factors.y), factors.z);
        direction = direction * scalar + (position - cubemapPosition);
    }
    #endif
    return direction;
}

half3 Em_IndirectSpecular(FragmentCommonDataPlus data, half occlusion, GlossyEnvironmentDataPlus glossIn, samplerCUBE ReflectionCubemap, float4 ReflectionCubemap_HDR, bool Usecubemapinsteadofreflectionprobes) {
    #if defined(UNITY_PASS_FORWARDBASE) && !defined(_GLOSSYREFLECTIONS_OFF)
        bool noReflectionProbe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, half3(0,0,0), 0).w == 0;
        bool useFallbackReflections = Usecubemapinsteadofreflectionprobes || noReflectionProbe;
    
        half3 R = glossIn.reflUVW;
        half perceptualRoughness = min(glossIn.perceptualRoughnessX, glossIn.perceptualRoughnessY);
    
        perceptualRoughness *= 1.7 - 0.7 * perceptualRoughness;
    
        half mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
        
        half3 specular;
        
        half3 env0Fallback = glossIn.reflectionFallbackMultiplier * DecodeHDR(texCUBElod(ReflectionCubemap, half4(R, mip)), ReflectionCubemap_HDR);
        
        half3 R1 = getReflectionUV(R, data.posWorld, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half4 env0Probe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R1, mip);
        half3 env0 = useFallbackReflections ? env0Fallback : DecodeHDR(env0Probe, unity_SpecCube0_HDR);
        #if UNITY_SPECCUBE_BLENDING
            const float kBlendFactor = 0.99999;
            float blendLerp = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (blendLerp < kBlendFactor || true)
            {
                half3 R2 = getReflectionUV(R, data.posWorld, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);

                half4 env1Probe = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, R2, mip);
                half3 env1 = DecodeHDR(env1Probe, unity_SpecCube1_HDR);
                specular = lerp(env1, env0, blendLerp);
            }
            else
            {
                specular = env0;
            }
        #else
            //specular = env0;
        #endif
        
        return specular * occlusion;
    #else
        return half3(0,0,0);
    #endif
}