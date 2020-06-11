// TODO: Reuse samplers for textures where possible (ramp should use a sampler set to always clamp)
// TODO: Detail normals, detail albedo, choosable UV set (may need to change vert function, aren't we out of passable interpolator variables?)
#include "EmShaderLighting.cginc"

uniform fixed4 _Color;
uniform UNITY_DECLARE_TEX2D(_MainTex);
uniform float4 _MainTex_ST;

uniform fixed _Cutoff;

//uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_LowLightTex);
//uniform float4 _LowLightTex_ST;

uniform fixed _SaturationAdjustment;

uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap);
uniform float4 _EmissionMap_ST;
//TODO: Rename to _EmissionColor
uniform fixed4 _EmissionColor;

uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_DiffuseControlMap);
uniform float4 _DiffuseControlMap_ST;
uniform half _DiffuseViewPull;
uniform fixed _DiffuseSoftness;
uniform fixed _LightOrView;
uniform half _ViewDirectionDiffuseBoost;

uniform fixed _DynamicShadowSharpness;
uniform fixed _DynamicShadowLift;

uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap);
uniform float4 _BumpMap_ST;
uniform half _BumpScale;

uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_OcclusionMap);
uniform float4 _OcclusionMap_ST;
uniform half _OcclusionStrength;

uniform fixed _Glossiness;
uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_MetallicGlossMap);
uniform float4 _MetallicGlossMap_ST;

// Was going to remove, but kept specifically for toon specular
uniform fixed4 _SpecularColour;
uniform fixed _ToonSpecular;
uniform fixed _ToonSpecularSharpness;
// Was going to remove, but kept specifically for toon specular
uniform sampler2D _SpecularMap;
// TODO: Remove
uniform float4 _SpecularMap_ST;
uniform fixed _ShDirectionalSpecularOn;
uniform fixed _ShReflectionSpecularOn;

uniform samplerCUBE _ReflectionCubemap;
uniform float4 _ReflectionCubemap_HDR;

uniform fixed _Anisotropy;
uniform fixed _Metallic;
uniform fixed _SmoothnessY;

uniform fixed _CapAnisoSpecular;

#if defined(HMD_HUE)
uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_HueMask);
uniform float4 _HueMask_ST;
uniform fixed _HueShift;
uniform fixed _FixedHueShift;
uniform fixed _HueAddOrSet;
#endif

#if defined(Geometry)
uniform half4 _OutlineColor;
uniform half _OutlineWidth;
uniform UNITY_DECLARE_TEX2D(_OutlineMask);
uniform float4 _OutlineMask_ST;
#endif

struct VertexData {
    float4 vertex : POSITION;
    float2 texcoord0 : TEXCOORD0;
    float2 texcoord1 : TEXCOORD1;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float4 color : COLOR;
};

struct VertexOutput {
#if defined(Geometry)
    float4 pos : CLIP_POS;
    float4 vertex : SV_POSITION;
#else
    float4 pos : SV_POSITION;
#endif
    float4 tex : TEXCOORD0;
    float3 normalDir : TEXCOORD1;
    float3 tangentDir : TEXCOORD2;
    float3 bitangentDir : TEXCOORD3;
    float4 posWorld : TEXCOORD4;
    float4 color : TEXCOORD5;
    float3 normal : TEXCOORD7;
    float4 screenPos : TEXCOORD8;
    float3 vCameraPosX : TEXCOORD10;
    float3 vCameraPosY : TEXCOORD11;
    float3 vCameraPosZ : TEXCOORD12;
    SHADOW_COORDS(6)
    UNITY_FOG_COORDS(9)
};

#if defined(Geometry)
    struct v2g
    {
        float4 pos : CLIP_POS;
        float4 vertex : SV_POSITION;
        float2 uv0 : TEXCOORD0;
        float2 uv1 : TEXCOORD1;
        float3 normalDir : TEXCOORD2;
        float3 tangentDir : TEXCOORD3;
        float3 bitangentDir : TEXCOORD4;
        float4 posWorld : TEXCOORD5;
        float4 color : TEXCOORD6;
        float3 normal : TEXCOORD8;
        float4 screenPos : TEXCOORD9;
        float3 vCameraPosX : TEXCOORD11;
        float3 vCameraPosY : TEXCOORD12;
        float3 vCameraPosZ : TEXCOORD13;
        SHADOW_COORDS(7)
        UNITY_FOG_COORDS(10)
    };

    struct g2f
    {
        float4 pos : SV_POSITION;
        float4 tex : TEXCOORD0;
        float3 normalDir : TEXCOORD1;
        float3 tangentDir : TEXCOORD2;
        float3 bitangentDir : TEXCOORD3;
        float4 posWorld : TEXCOORD4;
        float4 color : TEXCOORD5;
        float4 screenPos : TEXCOORD7;
        float3 vCameraPosX : TEXCOORD9;
        float3 vCameraPosY : TEXCOORD10;
        float3 vCameraPosZ : TEXCOORD11;
        SHADOW_COORDS(6)
        UNITY_FOG_COORDS(8)
    };
#endif

VertexOutput vert (VertexData v) {
    VertexOutput o = (VertexOutput)0;
    #if defined(Geometry)
        o.vertex = v.vertex;
    #endif
    
    o.pos = UnityObjectToClipPos( v.vertex );
    o.posWorld = mul(unity_ObjectToWorld, v.vertex);
    half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
    o.normalDir = UnityObjectToWorldNormal(v.normal);
    o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * tangentSign);
    o.tex = float4(v.texcoord0, v.texcoord1);
    //o.tex.uv = v.texcoord0;
    //o.tex.zw = v.texcoord1;
    o.screenPos = ComputeScreenPos(o.pos);
    o.normal = v.normal;
    o.color = float4(v.color.rgb, 0);
    
#if defined(USING_STEREO_MATRICES)
    float3 cameraPos = lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
#else
    float3 cameraPos = _WorldSpaceCameraPos;
#endif
    float3 objectPosition = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
    half3 objectViewDirection = normalize(cameraPos - objectPosition);
    float4x4 cameraViewPlaneToWorld = look_at_matrix(objectPosition, cameraPos, cross(objectViewDirection, half3(0,1,0)));

    o.vCameraPosX = mul(cameraViewPlaneToWorld, half3(1,0,0));
    o.vCameraPosY = mul(cameraViewPlaneToWorld, half3(0,1,0));
    o.vCameraPosZ = mul(cameraViewPlaneToWorld, half3(0,0,1));

    UNITY_TRANSFER_SHADOW(o, o.uv);
    UNITY_TRANSFER_FOG(o, o.pos);

    return o;
}

#if defined(Geometry)
    [maxvertexcount(6)]
    void geom(triangle v2g IN[3], inout TriangleStream<g2f> tristream)
    {
        g2f o;

        //Outlines loop
        for (int i = 2; i >= 0; i--)
        //for (int i = 0; i < 3; i++)
        {	
            float4 posWorld = (mul(unity_ObjectToWorld, IN[i].vertex));
            //half outlineWidthMask = tex2Dlod(_OutlineMask, float4(IN[i].uv, 0, 0));
            //half outlineWidthMask = EM_SAMPLE_TEX2D_LOD_SAMPLER(_OutlineMask, _MainTex, IN[i].uv0, 0);
            half outlineWidthMask = EM_SAMPLE_TEX2D_LOD(_OutlineMask, TRANSFORM_TEX(IN[i].uv0, _OutlineMask), 1).r;
            float3 outlineWidth = _OutlineWidth * .01 * outlineWidthMask;

            outlineWidth *= min(distance(posWorld, _WorldSpaceCameraPos) * 3, 1);
            float4 outlinePos = float4(IN[i].vertex + normalize(IN[i].normal) * outlineWidth, 1);
            
            o.pos = UnityObjectToClipPos(outlinePos);
            o.posWorld = posWorld;
            o.normalDir = IN[i].normalDir;
            o.tangentDir = IN[i].tangentDir;
            o.bitangentDir = IN[i].bitangentDir;
            o.tex = float4(IN[i].uv0, IN[i].uv1);
            //o.tex.uv = IN[i].uv0;
            //o.tex.zw = IN[i].uv1;
            o.color = float4(_OutlineColor.rgb, 1); // store if outline in alpha channel of vertex colors | 1 = is an outline
            o.screenPos = ComputeScreenPos(o.pos);
            o.vCameraPosX = IN[i].vCameraPosX;
            o.vCameraPosY = IN[i].vCameraPosY;
            o.vCameraPosZ = IN[i].vCameraPosZ;
        
            #if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
                o._ShadowCoord = IN[i]._ShadowCoord; //Can't use TRANSFER_SHADOW() macro here
            #endif
            UNITY_TRANSFER_FOG(o, o.pos);
            tristream.Append(o);
        }
        tristream.RestartStrip();
        
        //Main Mesh loop
        for (int j = 0; j < 3; j++)
        {
            o.pos = UnityObjectToClipPos(IN[j].vertex);
            o.posWorld = IN[j].posWorld;
            o.normalDir = IN[j].normalDir;
            o.tangentDir = IN[j].tangentDir;
            o.bitangentDir = IN[j].bitangentDir;
            o.tex = float4(IN[j].uv0, IN[j].uv1);
            //o.tex.uv = IN[j].uv0;
            //o.tex.zw = IN[j].uv1;
            o.color = float4(IN[j].color.rgb,0); // store if outline in alpha channel of vertex colors | 0 = not an outline
            o.screenPos = ComputeScreenPos(o.pos);
            o.vCameraPosX = IN[j].vCameraPosX;
            o.vCameraPosY = IN[j].vCameraPosY;
            o.vCameraPosZ = IN[j].vCameraPosZ;
        
            #if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
                o._ShadowCoord = IN[j]._ShadowCoord; //Can't use TRANSFER_SHADOW() or UNITY_TRANSFER_SHADOW() macros here, could use custom versions of them
                //o._LightCoord = IN[j]._LightCoord;
            #endif
            UNITY_TRANSFER_FOG(o, o.pos);
            tristream.Append(o);
        }
        tristream.RestartStrip();
    }
#endif

half4 frag(
#if defined(Geometry)
            g2f i
#else
            VertexOutput i
#endif
            , uint facing : SV_IsFrontFace) : SV_Target {
    float2 mainUV = i.tex.xy;
    float2 detailUV = i.tex.zw;
    
    // ----- Normals -- Unpack Normal map and calculate perturbed normals and smoothed (scaled) perturbed normals
    i.normalDir = normalize(i.normalDir);
    bool isFrontFace = facing > 0;
#if defined(Geometry)
    bool isOutline = i.color.a > 0.99;
#endif
    if (!isFrontFace) {
#if defined(Geometry)    
        if (isOutline) {
          discard;
        }
#endif
        i.normalDir *= -1;
        i.tangentDir *= -1;
        i.bitangentDir *= -1;
    }
    
    half3 lightColor = _LightColor0.rgb;
    
    half4 sampledOcclusion = UNITY_SAMPLE_TEX2D_SAMPLER(_OcclusionMap, _MainTex, TRANSFORM_TEX(mainUV, _OcclusionMap));
    half UNUSED_r = sampledOcclusion.r;
    half occlusion = LerpOneTo(sampledOcclusion.g, _OcclusionStrength);
    half UNUSED_b = sampledOcclusion.b;
    half UNUSED_a = sampledOcclusion.a;
    
    fixed4 sampledDiffuseControl = UNITY_SAMPLE_TEX2D_SAMPLER(_DiffuseControlMap, _MainTex, TRANSFORM_TEX(mainUV, _DiffuseControlMap));
    
    _DiffuseSoftness *= sampledDiffuseControl.r;
    _LightOrView *= sampledDiffuseControl.g;
    // [0,1] -> [0,1.5], there's no point to go higher than 1.5, all of the visible normals end up facing the view
    _DiffuseViewPull *= 1.5 * sampledDiffuseControl.b;
    // [0,1] -> [0,10], maybe could allow higher than 10, especially for darker surfaces? Or maybe it would be better if the diffuse colour didn't affect this boost so much?
    _ViewDirectionDiffuseBoost *= 10 * sampledDiffuseControl.a;
    
    // r = metallic
    // g = smoothnessY
    // b = anisotropy
    // a = smoothness
    half4 metallicGlossMap = UNITY_SAMPLE_TEX2D_SAMPLER(_MetallicGlossMap, _MainTex, TRANSFORM_TEX(mainUV, _MetallicGlossMap));
    _Metallic *= metallicGlossMap.r;
    _Glossiness *= metallicGlossMap.a;
    _SmoothnessY *= metallicGlossMap.g;
    _Anisotropy *= metallicGlossMap.b;
    
#ifdef _NORMALMAP
    half3x3 tangentTransform = half3x3( i.tangentDir, i.bitangentDir, i.normalDir);
    fixed3 _BumpMap_var = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, TRANSFORM_TEX(mainUV, _BumpMap)));
    half3 normalLocal = half3((_BumpScale * _BumpMap_var.rg), _BumpMap_var.b);
    half3 normalDirection = normalize(mul( normalLocal, tangentTransform )); // Perturbed normals
    half3 doubleSidedNormals = normalDirection;
    half3 doubleSidedTangent = cross(i.bitangentDir, doubleSidedNormals);
    half3 doubleSidedBitangent = cross(doubleSidedNormals, doubleSidedTangent);
  #if _DETAIL && defined(UNITY_ENABLE_DETAIL_NORMALMAP)
    // Do some extra stuff with detail normals, see UnityStandardInput.cginc NormalInTangentSpace(float4)
    #if _DETAIL_LERP
    #else
    #endif
  #endif
#else
    half3 doubleSidedNormals = i.normalDir;
    half3 doubleSidedTangent = i.tangentDir;
    half3 doubleSidedBitangent = i.bitangentDir;
#endif
    
    
    // ------- View and reflection directions
    half3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
    half3 viewReflectDirection = reflect( -viewDirection, doubleSidedNormals );
    half3 velvetDirection = normalize(doubleSidedNormals-0.5*viewDirection);
    
    
#if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
    half3 lightDirection = normalize(UnityWorldSpaceLightDir(i.posWorld.xyz));
#else
    // Normalize isn't needed for directional
    half3 lightDirection = UnityWorldSpaceLightDir(i.posWorld.xyz);
#endif
    half3 halfLightDirection = normalize(lightDirection + viewDirection);

    
    // ------- Fresnel
    half inverseFresnel = max(0, dot(doubleSidedNormals, viewDirection)); 
    half fresnel = 1.0 - inverseFresnel;
    
    // ------- Additional matrix setup
#if defined(UNITY_PASS_FORWARDBASE)
    // Picks a direction based on a combination of main light (always directional here), vertex lights and Spherical Harmonics
    half3 xiexeLightDir = -calcLightDir(i.posWorld.xyz);
#else
    // Add pass does not sample SH or look at vertex lights, only the main light direction of this add pass
    half3 xiexeLightDir = -lightDirection;
#endif
    float4x4 lightViewPlaneToWorld = look_at_matrix(0, 0 - xiexeLightDir, half3(1,0,0));
    
    half3 vCameraPosX = i.vCameraPosX;
    half3 vCameraNegX = -vCameraPosX;
    half3 vCameraPosY = i.vCameraPosY;
    half3 vCameraNegY = -vCameraPosY;
    half3 vCameraPosZ = i.vCameraPosZ;
    half3 vCameraNegZ = -vCameraPosZ;
    // The order is only important because we access [5] directly, it could be passed to the functions that use it as a single value and then the order will be irrelevant
    half3 vCamera[6] = {vCameraPosX,vCameraNegX,vCameraPosY,vCameraNegY,vCameraPosZ,vCameraNegZ};
    
    half3 vLightPosX = mul(lightViewPlaneToWorld, half3(1,0,0));
    half3 vLightNegX = -vLightPosX;
    half3 vLightPosY = mul(lightViewPlaneToWorld, half3(0,1,0));
    half3 vLightNegY = -vLightPosY;
    half3 vLightPosZ = mul(lightViewPlaneToWorld, half3(0,0,1));
    half3 vLightNegZ = -vLightPosZ;
    half3 vLight[6] = {vLightPosX,vLightNegX,vLightPosY,vLightNegY,vLightPosZ,vLightNegZ};
    
    half diffuseSoftness = _DiffuseSoftness;//0;
    half diffuseWidth = 2;
    half cameraDiffuseWidth = 1;
    half cameraForwardsPull = _DiffuseViewPull;//0.4;
    half lightOrCamera = _LightOrView;//0.5;
    

    // ------- Baked diffuse light
#if defined(UNITY_PASS_FORWARDBASE)
//#if defined(LIGHTPROBE_SH)
    half3 bakedLightAverageComponent = ShadeSH9(half4(0,0,0,1));

    half3 bakedLightComponent = EmSHDiffuse(doubleSidedNormals, cameraForwardsPull, vCamera, vLight, diffuseSoftness, lightOrCamera);
    
    half3 velvetColour = 1.5*ShadeSH9(velvetDirection);
    bakedLightComponent = lerp(bakedLightComponent, lerp(bakedLightComponent, max(velvetColour, bakedLightComponent), _ViewDirectionDiffuseBoost), pow(fresnel,4));
#else
    // SH lighting is only applied in the base pass
    half3 bakedLightComponent = 0;
    half3 bakedLightAverageComponent = 0;
#endif
    
    // ------- Dynamic diffuse light
    half3 dynamicLightComponent = 0;
    half3 dynamicLightAverageComponent = 0;
    // Should always be active so no point preprocessing
//#if defined(POINT) || defined(SPOT) || defined(DIRECTIONAL) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE)
    EM_LIGHT_ATTENUATION(lightAttenuation, i, i.posWorld.xyz);
    // TODO: What difference does it make doing the rounding here?
    
    // Get shadows and control their sharpness (XSToon style) and strength
    fixed oneMinusShadow = 1 - lightAttenuation.shadow;
    fixed shadowStrength = 1 - _LightShadowData.r;
//#if defined(SPOT)
//    // SPOT shadows are already super sharp
//    fixed sharpenedShadows = oneMinusShadow;
//#else
    // Need to catch the division by zero, an alternative would be to saturate(oneMinusShadow / shadowStrength) or maybe min(1, oneMinusShadow / shadowStrength)
    fixed fullStrengthShadows = shadowStrength == 0 ? 1 : oneMinusShadow / shadowStrength; //[0,shadowStrength] -> [0,1]
    // More expensive, but typically nicer results when transitioning between 0 and 1, but can have artifacts at full sharpness with soft shadows, particularly at a distance.
    //fixed sharpenedShadows = SpecialRemap(1 - _DynamicShadowSharpness, 1, fullStrengthShadows);
    // XSToon style shadow sharpening
    fixed sharpenedShadows = lerp(fullStrengthShadows, round(fullStrengthShadows), _DynamicShadowSharpness);
//#endif
    // Multiplying by shadowStrength takes us back to [0,shadowStrength]
    fixed modifiedShadows = sharpenedShadows * shadowStrength;
    //fixed attenuationNoShadowLift = lightAttenuation.light * modifiedShadows;
    // Some worlds are only lit by a directional dynamic light with full strength shadows which looks horrible, shadow lift can aleviate this
    modifiedShadows *= (1 - _DynamicShadowLift);
    modifiedShadows = 1 - modifiedShadows;
    //newShadows *= (1 - _DynamicShadowLift);
    fixed attenuation = lightAttenuation.light * modifiedShadows;
    fixed attenuationNoShadows = lightAttenuation.light;
    fixed shadows = lightAttenuation.light * (1 - lightAttenuation.shadow);
    
    dynamicLightAverageComponent = attenuationNoShadows * _LightColor0.rgb; 
    
    half3 dynamicLight = attenuation * _LightColor0.rgb;
    
    dynamicLightComponent = EmDynamicDiffuse(dynamicLight, lightDirection, doubleSidedNormals, cameraForwardsPull, vCamera, vLight, diffuseSoftness, lightOrCamera);

    half3 velvetLight = 1.5*dynamicLight * saturate(0.5 * (0.5 + dot(-xiexeLightDir, velvetDirection)));
    
    dynamicLightComponent = lerp(
      dynamicLightComponent,
      lerp(dynamicLightComponent, max(velvetLight, dynamicLightComponent), _ViewDirectionDiffuseBoost),
      pow(fresnel,4));
//#endif

    // ------- Vertex Lights
    // Should we run vertex lights through the same steps as important lights?
#if defined(VERTEXLIGHT_ON)
    half3 vertexLightComponent = EmVertexLightDiffuse(i.normalDir, i.posWorld.xyz);
#else
    half3 vertexLightComponent = 0;
#endif

    half3 finalDiffuseLight = bakedLightComponent + dynamicLightComponent + vertexLightComponent;

    // ------- Hue setup
#if defined(HMD_HUE)
    // This is the pseudo-random number generator taken from a ShaderForge shader, hence why the variables have horrible names and why I don't actually know what's going on. Though a couple are just constants used in conversion from RGB to HSV
    float hueInput = unity_OrthoParams.x;
    half2 node_6122 = float2(hueInput,0.0);
    float2 node_4111_skew = node_6122 + 0.2127+node_6122.x*0.3713*node_6122.y;
    float2 node_4111_rnd = 4.789*sin(489.123*(node_4111_skew));
    half node_4111 = frac(node_4111_rnd.x*node_4111_rnd.y*(1+node_4111_skew.x));
    node_4111 = lerp(node_4111, 0, _FixedHueShift);
    float4 node_3045_k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    fixed hueOffset = _HueShift;
    float node_3045_e = 1.0e-10;
    
    float4 node_3045_p = 0;
    float4 node_3045_q = 0;
    float node_3045_d = 0;
    fixed3 colorInHSV = 0;
    float3 node_1294 = 0;
    fixed hueMask = UNITY_SAMPLE_TEX2D_SAMPLER(_HueMask, _MainTex, TRANSFORM_TEX(mainUV, _HueMask)).r;
#endif 
    
    // ------- Emission
    half3 emissive = 0;
#if defined(UNITY_PASS_FORWARDBASE)
    fixed4 sampledEmissionTexture = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap,_MainTex, TRANSFORM_TEX(mainUV, _EmissionMap));
    emissive = (sampledEmissionTexture.rgb * _EmissionColor.rgb);
    
#if defined(HMD_HUE)    
    node_3045_p = lerp(float4(float4(emissive,0.0).zy, node_3045_k.wz), float4(float4(emissive,0.0).yz, node_3045_k.xy), step(float4(emissive,0.0).z, float4(emissive,0.0).y));
    node_3045_q = lerp(float4(node_3045_p.xyw, float4(emissive,0.0).x), float4(float4(emissive,0.0).x, node_3045_p.yzx), step(node_3045_p.x, float4(emissive,0.0).x));
    node_3045_d = node_3045_q.x - min(node_3045_q.w, node_3045_q.y);
    
    colorInHSV = float3(abs(node_3045_q.z + (node_3045_q.w - node_3045_q.y) / (6.0 * node_3045_d + node_3045_e)), node_3045_d / (node_3045_q.x + node_3045_e), node_3045_q.x);
    half initialEmissiveHue = lerp(colorInHSV.r, 0, _HueAddOrSet);
    node_1294 = (lerp(float3(1,1,1),saturate(3.0*abs(1.0-2.0*frac((initialEmissiveHue+hueOffset+node_4111)+float3(0.0,-1.0/3.0,1.0/3.0)))-1),colorInHSV.g)*colorInHSV.b);
                
    emissive = lerp(emissive,node_1294,hueMask);
#endif
#endif
    
    // ------- Diffuse texture
    
    // TODO: Move near the top
    // TODO?: Allow using a second texture that is used as light decreases?
    //half lowLightTexturePick = saturate(1-pow(max(0,grayscale(finalDiffuseLight)*2-1), 1));
    //fixed4 sampledMainTexture = lerp(UNITY_SAMPLE_TEX2D(_MainTex, TRANSFORM_TEX(mainUV, _MainTex)), UNITY_SAMPLE_TEX2D_SAMPLER(_LowLightTex,_MainTex, TRANSFORM_TEX(mainUV, _LowLightTex)), lowLightTexturePick);
    fixed4 sampledMainTexture = UNITY_SAMPLE_TEX2D(_MainTex, TRANSFORM_TEX(mainUV, _MainTex)) * _Color * half4(i.color.rgb, 1);

#if defined(_ALPHATEST_ON)
    clip(sampledMainTexture.a - _Cutoff);
#endif
    
#if defined(HMD_HUE)
    fixed3 diffuseAndColour = sampledMainTexture.rgb;
    
                node_3045_p = lerp(float4(float4(diffuseAndColour,0.0).zy, node_3045_k.wz), float4(float4(diffuseAndColour,0.0).yz, node_3045_k.xy), step(float4(diffuseAndColour,0.0).z, float4(diffuseAndColour,0.0).y));
                node_3045_q = lerp(float4(node_3045_p.xyw, float4(diffuseAndColour,0.0).x), float4(float4(diffuseAndColour,0.0).x, node_3045_p.yzx), step(node_3045_p.x, float4(diffuseAndColour,0.0).x));
                node_3045_d = node_3045_q.x - min(node_3045_q.w, node_3045_q.y);

                colorInHSV = float3(abs(node_3045_q.z + (node_3045_q.w - node_3045_q.y) / (6.0 * node_3045_d + node_3045_e)), node_3045_d / (node_3045_q.x + node_3045_e), node_3045_q.x);
                half initialHue = lerp(colorInHSV.r, 0, _HueAddOrSet);
                node_1294 = (lerp(float3(1,1,1),saturate(3.0*abs(1.0-2.0*frac((initialHue+hueOffset+node_4111)+float3(0.0,-1.0/3.0,1.0/3.0)))-1),colorInHSV.g)*colorInHSV.b);
                
    sampledMainTexture = lerp(sampledMainTexture, fixed4(node_1294,sampledMainTexture.a), hueMask);
#endif
    
    fixed3 albedoComponent = lerp((sampledMainTexture), grayscale(sampledMainTexture.rgb), (-1 * (_SaturationAdjustment)));

    // -------- Direct and Indirect specular
    half3 __specColor;
    half __oneMinusReflectivity;
    // Note that this is actually albedoComponent for metallic workflow
    half3 __diffColor = DiffuseAndSpecularFromMetallic(albedoComponent, _Metallic, __specColor, __oneMinusReflectivity);
    
    //return half4(__diffColor + 0.5,1);
    
    half outputAlpha;
    __diffColor = PreMultiplyAlpha(__diffColor, sampledMainTexture.a, __oneMinusReflectivity, /*out*/ outputAlpha);
    
    //FragmentCommonData fcd = RoughnessSetup(i.tex);
    //FragmentCommonData fcd = UNITY_SETUP_BRDF_INPUT(i.tex);
    
    
    FragmentCommonDataPlus fragmentCommonData = (FragmentCommonDataPlus)0;
    fragmentCommonData.diffColor = __diffColor;
    fragmentCommonData.specColor = __specColor;
    fragmentCommonData.oneMinusReflectivity = __oneMinusReflectivity;
    fragmentCommonData.smoothnessX = _Glossiness;
    fragmentCommonData.smoothnessY = lerp(_Glossiness, _SmoothnessY, _Anisotropy);
    fragmentCommonData.anisotropy = _Anisotropy;
    fragmentCommonData.normalWorld = doubleSidedNormals;
    fragmentCommonData.tangentWorld = doubleSidedTangent;
    fragmentCommonData.bitangentWorld = doubleSidedBitangent;
    fragmentCommonData.eyeVec = -viewDirection;
    fragmentCommonData.alpha = sampledMainTexture.a;//includes _Color.a
    fragmentCommonData.posWorld = i.posWorld.xyz;
    
    GlossyEnvironmentDataPlus glossyEnvironmentData = (GlossyEnvironmentDataPlus)0;
    glossyEnvironmentData.perceptualRoughnessX = SmoothnessToPerceptualRoughness(fragmentCommonData.smoothnessX);
    glossyEnvironmentData.perceptualRoughnessY = SmoothnessToPerceptualRoughness(fragmentCommonData.smoothnessY);
    glossyEnvironmentData.perceptualRoughness = min(glossyEnvironmentData.perceptualRoughnessX, glossyEnvironmentData.perceptualRoughnessY);
    
    half3 anisotropicRoughnessDirection = glossyEnvironmentData.perceptualRoughnessX >= glossyEnvironmentData.perceptualRoughnessY ? fragmentCommonData.bitangentWorld : fragmentCommonData.tangentWorld;
    half3 anisotropicRoughnessTangent = cross(anisotropicRoughnessDirection, -fragmentCommonData.eyeVec);
    half3 anisotropicRoughnessNormal = cross(anisotropicRoughnessTangent, anisotropicRoughnessDirection);
    half3 anisotropicBentNormal = normalize(lerp(fragmentCommonData.normalWorld, anisotropicRoughnessNormal, abs(glossyEnvironmentData.perceptualRoughnessX - glossyEnvironmentData.perceptualRoughnessY)));
    half3 anisotropicRoughnessReflectionDirection = reflect(fragmentCommonData.eyeVec, anisotropicBentNormal);
    
    glossyEnvironmentData.reflUVW = lerp(viewReflectDirection, anisotropicRoughnessReflectionDirection, fragmentCommonData.anisotropy);
    
    // 100 will result in complete blurring, which we will use to assume the overall brightness of the reflection fallback
    half reflectionMipAverage = 100;
    half lightLuminance = grayscale(bakedLightAverageComponent + dynamicLightAverageComponent + vertexLightComponent);
    // Instead of assuming the fallback reflections are of a fully lit scene, we could try and get the brightness of the fallback and further adjust the fallback brightness to match the surrounding light
    //half reflectionFallbackLuminance = grayscale(texCUBElod(_ReflectionCubemap,float4(glossyEnvironmentData.reflUVW,reflectionMipAverage)).rgb);
    //half fallbackReflectionAdjust = reflectionFallbackLuminance == 0 ? 0 : lightLuminance/reflectionFallbackLuminance;
    
    glossyEnvironmentData.reflectionFallbackMultiplier = lightLuminance;

    half3 emIndirectSpecular = Em_IndirectSpecular(i.posWorld.xyz, occlusion, glossyEnvironmentData, _ReflectionCubemap, _ReflectionCubemap_HDR);
    #if defined(Geometry)
    if (isOutline) {
          // No reflections on outlines
          emIndirectSpecular = 0;
    }
    #endif
    
    //
    //BRDF time
    //
    
    
    // ------- Specular
    // -- Specular setup
    half roughness = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughness);
#if defined(_SPECULARHIGHLIGHTS_OFF)
    half3 sharedSpecularComponent = 0;
#else
    half anisoSpecLimitSmoothness = saturate(2 * max(_Glossiness,_SmoothnessY));
    
    half3 sharedSpecular = 0;
    
    half tDotV = dot(viewDirection, doubleSidedTangent);
    half bDotV = dot(viewDirection, doubleSidedBitangent);
    half nDotV = abs(dot(doubleSidedNormals, viewDirection));

    half roughnessX = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughnessX);
    half roughnessY = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughnessY);
    fixed4 sampledSpecularColourMap = tex2D(_SpecularMap, TRANSFORM_TEX(mainUV, _SpecularMap));
    // We want a really quick blend from normal style to toon style and to then use the rest of the slider/map value to control how smooth the edges of the toon specular are
    // We have to be careful not to blend into toon specular right at 0 as the immediate blend between ~95% normal and ~5% toon is horrible, any values near to zero should result in normal specular so as to account for poor mipmapping (e.g. a 3x3 texture atlas)
    fixed isToonSpecular = sampledSpecularColourMap.a * _ToonSpecular;
    // [0,0.1) -> 1-0 = 1
    // (0.1,1] -> lerp between 1-0 = 1 and 1-1 = 0
    fixed toonSpecularSoftness = saturate(1 - (1.1 * (isToonSpecular) - 0.1));
    //isToonSpecular = 1 - pow(1 - isToonSpecular, 5);
    // [0,0.1) -> 100% smooth
    // (0.1,0.2) -> Lerp between smooth and toon
    // (0.2,1] -> 100% toon
    isToonSpecular = saturate(10 * isToonSpecular - 1);
    fixed toonSpecularBrightness = sqr(max(fragmentCommonData.smoothnessX, fragmentCommonData.smoothnessY));
    
    // -- Dynamic Light specular
  #if defined(POINT) || defined(SPOT) || defined(DIRECTIONAL) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE) 
    
    sharedSpecular += EmSpecular(doubleSidedNormals, doubleSidedTangent, doubleSidedBitangent, halfLightDirection, lightDirection, roughness, roughnessX, roughnessY, fragmentCommonData.anisotropy, anisoSpecLimitSmoothness, _CapAnisoSpecular, tDotV, bDotV, nDotV, toonSpecularBrightness, isToonSpecular, toonSpecularSoftness, _LightColor0.rgb * attenuation, _LightColor0.rgb * attenuationNoShadows, fragmentCommonData.specColor);
    //sharedSpecular += max(0, dynamicSpecular);
  #endif
  #if defined(UNITY_PASS_FORWARDBASE)
    bool shDirectionalSpecularAlwaysOn = _ShDirectionalSpecularOn == 1;
    bool shDirectionalSpecularOnIfNoDynamic = _ShDirectionalSpecularOn == 2;
    bool shReflectionSpecularAlwaysOn = _ShReflectionSpecularOn == 1;
    bool shReflectionSpecularOnIfNoDynamicOrDirectional = _ShReflectionSpecularOn == 2;
    
    bool noDynamicLight = !any(_LightColor0.rgb);
    
    bool shDirectionalSpecularOn = shDirectionalSpecularAlwaysOn || (shDirectionalSpecularOnIfNoDynamic && !any(_LightColor0.rgb));
    
    // -- SH Dominant Direction Specular
    half3 shLightDir = calcLightDirSH(i.posWorld.xyz);
    bool noSHDirectionalLight = !any(shLightDir);
    half3 shHalfLightDirection = normalize(shLightDir + viewDirection);
    half3 shSpecularColour = max(0,ShadeSH9(half4(1*shLightDir, 1))-ShadeSH9(half4(0,0,0,1)));
    
    bool shReflectionSpecularOn = shReflectionSpecularAlwaysOn || (shReflectionSpecularOnIfNoDynamicOrDirectional && noDynamicLight && noSHDirectionalLight);

    half3 shDirectionalSpecular = EmSpecular(doubleSidedNormals, doubleSidedTangent, doubleSidedBitangent, shHalfLightDirection, shLightDir, roughness, roughnessX, roughnessY, fragmentCommonData.anisotropy, anisoSpecLimitSmoothness, _CapAnisoSpecular, tDotV, bDotV, nDotV, toonSpecularBrightness, isToonSpecular, toonSpecularSoftness, shSpecularColour, shSpecularColour, fragmentCommonData.specColor) *
    shDirectionalSpecularOn;
    
    // -- SH View Direction Specular
    half3 shSpecularDirection = 0.5*normalize(viewReflectDirection+doubleSidedNormals);
    // Trial and error to get nice values, it's pretty similar to just doing ShadeSH9 with unchanged normals, though doesn't seem to result in such big issues with directional baked lights
    half3 sss = max(0,ShadeSH9(half4(shSpecularDirection, 1))-0.4*ShadeSH9(half4(0,0,0,1)));
    // wondering what it would look like without the second sss term
    //sss = 8 * sss * sss;
    sss = 1.5 * sss;

    half3 bakedSpecColour = max(sss, 0);
    
    //half shSpecularFresnel = saturate(0.77*pow(dot(doubleSidedNormals, normalize(doubleSidedNormals + viewDirection)),1));
    // typically lighting will be coming from above and how this works the lighting is centred around the point in the middle of the screen
    // todo: can anythign be done with view position?
    //half3 shSpecularDirectionBoost = half3(0,0,0);//half3(0,-0.3,0);
    
    //half3 shReflectDirection = normalize(shSpecularDirectionBoost + lerp(normalize(doubleSidedNormals + viewDirection),viewReflectDirection,shSpecularFresnel));
    half3 shReflectDirection = viewDirection;
    half3 shHalfReflectDirection = normalize(doubleSidedNormals * 0 + viewDirection * 2);
                          
    half3 bakedSpecular = shReflectionSpecularOn * EmSpecular(doubleSidedNormals, doubleSidedTangent, doubleSidedBitangent, shHalfReflectDirection, shReflectDirection, roughness, roughnessX, roughnessY, fragmentCommonData.anisotropy, anisoSpecLimitSmoothness, _CapAnisoSpecular, tDotV, bDotV, nDotV, toonSpecularBrightness, isToonSpecular, toonSpecularSoftness, bakedSpecColour, bakedSpecColour, fragmentCommonData.specColor);
    
    // Both of these specular options are using the same light source, they should not add together
    sharedSpecular += max(0,max(bakedSpecular, shDirectionalSpecular));
    
  #endif
    half3 sharedSpecularComponent = sharedSpecular * sampledSpecularColourMap.rgb * _SpecularColour.rgb;
#endif
    
    

#if defined(Geometry)
    if (isOutline) {
      // No specular on outlines
      sharedSpecularComponent = 0;
    }
#endif
    //end specular
    
    // Surface reduction from standard:
    
    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;
#   ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*glossyEnvironmentData.perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#   else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#   endif


    half specularKill = any(fragmentCommonData.specColor) ? 1.0 : 0.0;
    half grazingTerm = saturate(max(fragmentCommonData.smoothnessX, fragmentCommonData.smoothnessY) + (1-fragmentCommonData.oneMinusReflectivity));

    half3 indirectSpecularFresnelLerp = FresnelLerp(fragmentCommonData.specColor, grazingTerm, saturate(dot(fragmentCommonData.normalWorld, -fragmentCommonData.eyeVec)));
    //indirectSpecularFresnelLerp = lerp(indirectSpecularFresnelLerp, 0, isToonSpecular);

   
    half3 finalDiffuse = fragmentCommonData.diffColor * finalDiffuseLight;
    
    // Removes indirect lighting from reflection probes in nearly unlit to completely unlit environments
    #if defined(UNITY_PASS_FORWARDBASE)
    // FIXME: baked light seems waaaay off
    half indirectSpecularModifier = saturate(grayscale((bakedLightAverageComponent*100 + (vertexLightComponent + dynamicLightAverageComponent) * 10)));
    #else
    // There isn't any indirect specular anyway since we're in a forwardadd pass, but this should let the compiler be even more aggressive with removing unneeded code
    half indirectSpecularModifier = 0;
    #endif
    half3 finalColor = finalDiffuse * occlusion * 1
                       + sharedSpecularComponent * specularKill * 1
                       + surfaceReduction * emIndirectSpecular * indirectSpecularFresnelLerp * indirectSpecularModifier;
    finalColor = max(finalColor, emissive);
    
    //DEBUG
    //half debugValue1 = GGXNormalDistribution(roughness, saturate(nDotH));
    //half3 debugValue3 = debugValue1 * FresnelTerm(fragmentCommonData.specColor, nDotH);
    //debugValue3 = max(0, dynamicLight2);
    //
    //if (Luminance(debugValue3) > 1) {
    //  if (Luminance(debugValue3) > 2) {
    //    if (Luminance(debugValue3) > 3) {
    //      debugValue3 = half3(0,0,1);
    //    } else {
    //      debugValue3 = half3(0,1,0);
    //    }
    //  } else {
    //    debugValue3 = half3(1,0,0);
    //  }
    //}
    ////#if defined(UNITY_PASS_FORWARDBASE)
    //////sharedSpecular += max(0,dynamicSpecular * saturate(nDotL));
    //half4 debugValue = half4(debugValue3, 1);
    //return max(0, half4(finalColor,1) * 0.001 - 1) + 1 - lightAttenuation.shadow;
    //return max(0, half4(finalColor,1) * 0.001 - 1) + newShadows;
    //return max(0, half4(finalColor,1) * 0.001 - 12) + grayscale(albedoComponent);
    //#else
#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
    return half4(finalColor,outputAlpha);
#else
    return half4(finalColor,1);
#endif
    //#endif
}