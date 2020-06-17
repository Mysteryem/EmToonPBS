//todo: Why is the include order important here?
#include "EmShaderFunctionsToon5.cginc"
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

struct Attenuation {
  fixed light, shadow;
};

#ifdef POINT
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord3 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
    Attenuation destNameS; \
    destNameS.light = tex2D(_LightTexture0, dot(lightCoordS, lightCoordS).rr).UNITY_ATTEN_CHANNEL; \
    destNameS.shadow = UNITY_SHADOW_ATTENUATION(input, worldPos);
#endif

#ifdef SPOT
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord4 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
    Attenuation destNameS; \
    destNameS.light = (lightCoordS.z > 0) * UnitySpotCookie(lightCoordS) * UnitySpotAttenuate(lightCoordS.xyz); \
    destNameS.shadow = UNITY_SHADOW_ATTENUATION(input, worldPos);
#endif

#ifdef DIRECTIONAL
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    Attenuation destNameS; \
    destNameS.light = 1; \
    destNameS.shadow = UNITY_SHADOW_ATTENUATION(input, worldPos);
#endif

#ifdef POINT_COOKIE
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord3 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
    Attenuation destNameS; \
    destNameS.light = tex2D(_LightTextureB0, dot(lightCoordS, lightCoordS).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoordS).w; \
    destNameS.shadow = UNITY_SHADOW_ATTENUATION(input, worldPos);
#endif

#ifdef DIRECTIONAL_COOKIE
#define EM_LIGHT_ATTENUATION(destNameS, input, worldPos) \
    unityShadowCoord2 lightCoordS = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
    Attenuation destNameS; \
    destNameS.light = tex2D(_LightTexture0, lightCoordS).w; \
    destNameS.shadow = UNITY_SHADOW_ATTENUATION(input, worldPos);
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
    // Note that is not normalized for point or spot lights
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
     || length(lightDir) < 0.01) {
    return half3(0, 0, 0);
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

inline half3 ShadeSH9(half3 vec) {
  return ShadeSH9(half4(vec, 1));
}

half3 EmVertexLightDiffuse(half3 normalDir, float3 posWorld) {
  half3 vertexLightComponent = 0;
  for (int index = 0; index < 4; index++) {  
    float3 lightPosition = float3(unity_4LightPosX0[index], unity_4LightPosY0[index], unity_4LightPosZ0[index]);
  
    float3 vertexToLightSource = lightPosition.xyz - posWorld;    
    float3 lightDirection = normalize(vertexToLightSource);
    float squaredDistance = dot(vertexToLightSource, vertexToLightSource);
    float attenuation = 1.0 / (1.0 + unity_4LightAtten0[index] * squaredDistance);
    attenuation = attenuation * attenuation;
    float3 diffuseReflection = attenuation * unity_LightColor[index].rgb * max(0.0, dot(normalDir, lightDirection) * 0.5 + 0.5);
  
    vertexLightComponent = vertexLightComponent + diffuseReflection;
  }
  return vertexLightComponent;
}

half3 EmSHDiffuse(half3 doubleSidedNormals, half cameraForwardsPull, half3 vCamera[6], half3 vLight[6], half diffuseSoftness, half lightOrCamera) {
    // Softens the lighting and reduces error with baked directional lights
    const half shadeMul = 0.7;
    
    // Magic values to ensure full coverage of all possible input normals and reduce overlap
    //  - Overlap creates more areas of different colour when using sharp diffuse...and the areas typically end up having less aetheticly pleasing shapes
    //  - Not having full coverage of all possible input normals will result in black areas appearing
    const half diffuseWidth = 2;
    const half cameraDiffuseWidth = 1;
    
    half3 cameraBakedDiffuse = 0;
    half3 lightBakedDiffuse = 0;
    
    for (int j = 0; j < 6; j++) {
      
      // vCamera[5] is the negative Z Camera direction which is the normal going from the object position and towards the camera, this pulls the normal towards the camera (if the normal had been at the object origin)
      half3 vCameraBakedNormalDir = normalize(doubleSidedNormals + cameraForwardsPull * vCamera[5]);
      half3 vCameraShade = ShadeSH9(shadeMul * vCamera[j]);
      half vCameraDot = saturate(0.5 * (0.5 + dot(vCameraBakedNormalDir, vCamera[j])));
      // TODO? What if instead of the special remap, we instead used a greyscale ramp texture?
      vCameraDot = saturate(SpecialRemap(diffuseSoftness, cameraDiffuseWidth, vCameraDot));
      cameraBakedDiffuse = max(cameraBakedDiffuse, vCameraShade * vCameraDot);
      
      // Light
      half3 vLightShade = ShadeSH9(shadeMul * vLight[j]);
      half vLightDot = saturate(0.5 * (0.5 + dot(doubleSidedNormals, vLight[j])));
      
      vLightDot = saturate(SpecialRemap(diffuseSoftness, diffuseWidth, vLightDot));
      // Averaging doesn't look good at all, maxLuminance() looks ok when fully sharp but breaks horrible when smooth and min() is always black
      lightBakedDiffuse = max(lightBakedDiffuse, vLightShade * vLightDot);
    }
    
    return lerp(lightBakedDiffuse, cameraBakedDiffuse, lightOrCamera);
}

half3 EmDynamicDiffuse(half3 dynamicLight, half3 lightDirection, half3 doubleSidedNormals, half cameraForwardsPull, half3 vCamera[6], half3 vLight[6], half diffuseSoftness, half lightOrCamera) {
  // Magic values to ensure full coverage of all possible input normals and reduce overlap
  //  - Overlap creates more areas of different colour when using sharp diffuse...and the areas typically end up having less aetheticly pleasing shapes
  //  - Not having full coverage of all possible input normals will results in black areas appearing
  const half diffuseWidth = 2;
  const half cameraDiffuseWidth = 1;
  
  // Just helps not having to type it all out
  const half dynamicSideMul = 0.2;
  const half3 dynamicSideMul3 = half3(0.2,0.2,0.2);
  
  half dynamicSide[6] = {dynamicSideMul,dynamicSideMul,dynamicSideMul,dynamicSideMul,0,1};

  half dynamicLightDiffuseStrength = 0;
  half dynamicCameraDiffuseStrength = 0;
  
  half dynamicCameraSideMul[6] = {0.9,0.9,0.9,0.9,0,0.9};
  
  for (int k = 0; k < 6; k++) {
    half vLightDot = saturate(0.5 * (0.5 + dot(doubleSidedNormals, vLight[k])));
    vLightDot = saturate(SpecialRemap(diffuseSoftness, diffuseWidth, vLightDot));
    dynamicLightDiffuseStrength = max(dynamicLightDiffuseStrength, dynamicSide[k] * vLightDot);
    
    half3 vCameraDynamicNormalDir = normalize(doubleSidedNormals + cameraForwardsPull * vCamera[5]);
    half vCameraIntensity = dynamicCameraSideMul[k] * 0.9 * (0.1 + dot(lightDirection, vCamera[k]));
    half vCameraDot = saturate(0.5 * (0.5 + dot(vCameraDynamicNormalDir, vCamera[k])));
    vCameraDot = saturate(SpecialRemap(diffuseSoftness, cameraDiffuseWidth, vCameraDot));
    dynamicCameraDiffuseStrength = max(dynamicCameraDiffuseStrength, vCameraIntensity * vCameraDot);
  }
  
  return dynamicLight * lerp(dynamicLightDiffuseStrength, dynamicCameraDiffuseStrength, lightOrCamera);
}

// Good god this is a mess, a Struct for common variables used between all 3 specular function calls would be nice
half3 EmSpecular(half3 doubleSidedNormals, half3 doubleSidedTangent, half3 doubleSidedBitangent, half3 halfLightDirection, half3 lightDirection, half roughness, half roughnessX, half roughnessY, half anisotropy, half anisoSpecLimitSmoothness, fixed capAnisoSpecular, half tDotV, half bDotV, half nDotV, fixed toonSpecularBrightness, fixed isToonSpecular, fixed toonSpecularSoftness, half3 lightColourAndAttenuation, half3 lightColourAndAttenuationNoShadows, half3 specularColour) {
    half nDotH = dot(doubleSidedNormals, halfLightDirection);
    half tDotL = dot(doubleSidedTangent, lightDirection);
    half bDotL = dot(doubleSidedBitangent, lightDirection);
    half nDotL = dot(doubleSidedNormals, lightDirection);
    half tDotH = dot(doubleSidedTangent, halfLightDirection);
    half bDotH = dot(doubleSidedBitangent, halfLightDirection);

    half halfLightSpecular = GGXNormalDistribution(roughness, saturate(nDotH));
    
    
    half anisotropicSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotL, bDotL, nDotL, roughnessX, roughnessY);
    anisotropicSpecularVisibility = max(0,anisotropicSpecularVisibility);
    half anisotropicSpecular = D_GGXAnisotropic(tDotH, bDotH, nDotH, roughnessX, roughnessY);

    anisotropicSpecular *= anisotropicSpecularVisibility;

    #ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSpecular = sqrt(max(1e-2h, anisotropicSpecular));
    #endif
    // Supposedly specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSpecular = max(0, anisotropicSpecular * nDotL);
    // Limit overbrightening on weird normals
    anisotropicSpecular = lerp(anisotropicSpecular, min(anisotropicSpecular, 2*(anisoSpecLimitSmoothness + grayscale(lightColourAndAttenuationNoShadows))), capAnisoSpecular);
    
    halfLightSpecular = lerp(halfLightSpecular, anisotropicSpecular, anisotropy);
    
    // TODO: Should this be done before the lerp?
    halfLightSpecular = halfLightSpecular * saturate(nDotL);
    
    half3 dynamicMaterialSpecularInfluence = FresnelTerm(specularColour, nDotH);

    half dynamicToonSpecular = toonSpecularBrightness
                               //the remap gets artifacts when zoomed out when >1
                               * SpecialRemap(toonSpecularSoftness, 1, saturate(halfLightSpecular))
                               / Luminance(dynamicMaterialSpecularInfluence);
    
    half dynamicSpecularBase = lerp(halfLightSpecular, dynamicToonSpecular, isToonSpecular);
    
    half3 dynamicSpecular = lightColourAndAttenuation * // Light colour and attenuation
                            dynamicMaterialSpecularInfluence * // Material specular colour influence
                            dynamicSpecularBase; // Specular intensity
    
    return max(0,dynamicSpecular);
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

inline half3 Em_IndirectSpecular(float3 posWorld, half occlusion, GlossyEnvironmentDataPlus glossIn, samplerCUBE ReflectionCubemap, float4 ReflectionCubemap_HDR) {
    #if defined(UNITY_PASS_FORWARDBASE)
        #if defined(_GLOSSYREFLECTIONS_OFF)
            half3 specular = unity_IndirectSpecColor.rgb;
        #else
            #if defined(FALLBACK_REPLACE_PROBES)
            bool useFallbackReflections = true;
            #else
            bool noReflectionProbe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, half3(0,0,0), 0).w == 0;
            
            bool useFallbackReflections = noReflectionProbe;
            #endif
        
            half3 R = glossIn.reflUVW;
            half perceptualRoughness = min(glossIn.perceptualRoughnessX, glossIn.perceptualRoughnessY);
        
            perceptualRoughness *= 1.7 - 0.7 * perceptualRoughness;
        
            half mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
            
            half3 specular;
            
            half3 env0Fallback = glossIn.reflectionFallbackMultiplier * DecodeHDR(texCUBElod(ReflectionCubemap, half4(R, mip)), ReflectionCubemap_HDR);
            
            half3 R1 = getReflectionUV(R, posWorld, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
            half4 env0Probe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R1, mip);
            half3 env0 = useFallbackReflections ? env0Fallback : DecodeHDR(env0Probe, unity_SpecCube0_HDR);

            #if UNITY_SPECCUBE_BLENDING && !defined(FALLBACK_REPLACE_PROBES)
                const float kBlendFactor = 0.99999;
                float blendLerp = unity_SpecCube0_BoxMin.w;
                UNITY_BRANCH
                if (blendLerp < kBlendFactor || true)
                {
                    half3 R2 = getReflectionUV(R, posWorld, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);

                    half4 env1Probe = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, R2, mip);
                    half3 env1 = DecodeHDR(env1Probe, unity_SpecCube1_HDR);
                    specular = lerp(env1, env0, blendLerp);
                }
                else
                {
                    specular = env0;
                }
            #else
                specular = env0;
            #endif
        #endif
        
        return specular * occlusion;
    #else
        return half3(0,0,0);
    #endif
}