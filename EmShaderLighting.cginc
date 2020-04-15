#include "AutoLight.cginc"
//todo: Split into EmShaderDefines (remember to ifdef i
#if defined(SHADER_API_D3D11) || defined(SHADER_API_XBOXONE)
#define EM_DECLARE_SAMPLER(samplerName) SamplerState sampler##samplerName
#define EM_SAMPLE_TEX2D_LOD(tex,coord,lod) tex.SampleLevel (sampler##tex,coord,lod)
#define EM_SAMPLE_TEX2D_LOD_SAMPLER(tex,samplertex,coord,lod) tex.SampleLevel(sampler##samplertex,coord,lod)
#else
// Empty, no separate sampler is declared
#define EM_DECLARE_SAMPLER(sampler) 
// Doesn't seem right that these ignore the sampler, but this behaviour matches unity's
#define EM_SAMPLE_TEX2D_LOD(tex,coord,lod) tex2Dlod (tex,float4(coord,0.0,lod))
#define EM_SAMPLE_TEX2D_LOD_SAMPLER(tex,samplertex,coord,lod) tex2Dlod (tex,float4(coord,0.0,lod))
#endif

#ifdef POINT
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord3 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
    fixed destNameS = tex2D(_LightTexture0, dot(lightCoordS, lightCoordS).rr).UNITY_ATTEN_CHANNEL;
#endif

#ifdef SPOT
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord4 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
    fixed destNameS = (lightCoordS.z > 0) * UnitySpotCookie(lightCoordS) * UnitySpotAttenuate(lightCoordS.xyz);
#endif

#ifdef DIRECTIONAL
    //#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) fixed destNameS = UNITY_SHADOW_ATTENUATION(input, worldPos);
    #define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) fixed destNameS = 1;
#endif

#ifdef POINT_COOKIE
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord3 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
    fixed destNameS = tex2D(_LightTextureB0, dot(lightCoordS, lightCoordS).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoordS).w;
#endif

#ifdef DIRECTIONAL_COOKIE
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord2 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
    fixed destNameS = tex2D(_LightTexture0, lightCoordS).w;
#endif

// From Xiexe's Unity Shaders
half3 getVertexLightsDir(float3 worldPos)
{
    half3 toLightX = half3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
    half3 toLightY = half3(unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
    half3 toLightZ = half3(unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
    half3 toLightW = half3(unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);

    half3 dirX = toLightX - worldPos;
    half3 dirY = toLightY - worldPos;
    half3 dirZ = toLightZ - worldPos;
    half3 dirW = toLightW - worldPos;
    
    dirX *= length(toLightX);
    dirY *= length(toLightY);
    dirZ *= length(toLightZ);
    dirW *= length(toLightW);

    half3 dir = (dirX + dirY + dirZ + dirW);
    return normalize(dir); //Has to be normalized before feeding into LightDir, otherwise you end up with some weird behavior.
}

// From Xiexe's Unity Shaders
// Get the most intense light Dir from probes OR from a light source. Method developed by Xiexe / Merlin
half3 calcLightDir(float3 worldPos)
{   
    half3 lightDir = UnityWorldSpaceLightDir(worldPos);

    half3 probeLightDir = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;
    lightDir = (lightDir + probeLightDir); //Make light dir the average of the probe direction and the light source direction.
    
    #if defined(VERTEXLIGHT_ON)
        half3 vertexDir = getVertexLightsDir(worldPos);
        lightDir = (lightDir + probeLightDir + vertexDir);
    #endif

    #if !defined(POINT) && !defined(SPOT) && !defined(VERTEXLIGHT_ON) // if the average length of the light probes is null, and we don't have a directional light in the scene, fall back to our fallback lightDir
        if(length(unity_SHAr.xyz*unity_SHAr.w + unity_SHAg.xyz*unity_SHAg.w + unity_SHAb.xyz*unity_SHAb.w) == 0 && length(lightDir) < 0.1)
        {
            lightDir = half4(1, 1, 1, 0);
        }
    #endif 

    return normalize(lightDir);
}

half3 calcLightDirSH(float3 worldPos) {
  half3 lightDir = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;
  if(length(unity_SHAr.xyz*unity_SHAr.w + unity_SHAg.xyz*unity_SHAg.w + unity_SHAb.xyz*unity_SHAb.w) == 0
     && length(lightDir) < 0.1) {
    return half4(0, -1, 0, 1);
  }
  return normalize(lightDir);
}

half grayscale(half3 v){
    //return Luminance(v);
    return dot(v, float3(0.3,0.59,0.11));
}

/* http://www.geomerics.com/wp-content/uploads/2015/08/CEDEC_Geomerics_ReconstructingDiffuseLighting1.pdf */
float shEvaluateDiffuseL1Geomerics_local(float L0, float3 L1, float3 n)
{
	// average energy
	float R0 = L0;

	// avg direction of incoming light
	float3 R1 = 0.5f * L1;

	// directional brightness
	float lenR1 = length(R1);

	// linear angle between normal and direction 0-1
	//float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
	//float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
	float q = dot(normalize(R1), n) * 0.5 + 0.5;
	q = saturate(q); // Thanks to ScruffyRuffles for the bug identity.

	// power for q
	// lerps from 1 (linear) to 3 (cubic) based on directionality
	float p = 1.0f + 2.0f * lenR1 / R0;

	// dynamic range constant
	// should vary between 4 (highly directional) and 0 (ambient)
	float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

	return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}

half3 BetterSH9 (half4 normal) {
	float3 indirect;
	float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
	indirect.r = shEvaluateDiffuseL1Geomerics_local(L0.r, unity_SHAr.xyz, normal);
	indirect.g = shEvaluateDiffuseL1Geomerics_local(L0.g, unity_SHAg.xyz, normal);
	indirect.b = shEvaluateDiffuseL1Geomerics_local(L0.b, unity_SHAb.xyz, normal);
	indirect = max(0, indirect);
	return indirect;

}

half3 ShadeSH9(half3 vec) {
  return ShadeSH9(half4(vec, 1));
}
