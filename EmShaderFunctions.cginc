#include "UnityStandardUtils.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityCG.cginc"

half sqr(half x) {
  return x * x;
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

