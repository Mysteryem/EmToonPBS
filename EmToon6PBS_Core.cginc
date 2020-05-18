// TODO: Reuse samplers for textures where possible (ramp should use a sampler set to always clamp)
// TODO: Detail normals, detail albedo, choosable UV set (may need to change vert function, aren't we out of passable interpolator variables?)
#include "EmShaderFunctionsToon5.cginc"

uniform fixed4 _Color;
uniform UNITY_DECLARE_TEX2D(_MainTex);
uniform float4 _MainTex_ST;

//uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_LowLightTex);
//uniform float4 _LowLightTex_ST;

uniform fixed _SaturationAdjustment;

uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap);
uniform float4 _EmissionMap_ST;
uniform fixed4 _Emission;

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
uniform fixed _Usecubemapinsteadofreflectionprobes;

uniform fixed _Anisotropy;
uniform fixed _Metallic;
uniform fixed _SmoothnessY;

uniform fixed _CapAnisoSpecular;

#if defined(HMD_HUE)
uniform UNITY_DECLARE_TEX2D_NOSAMPLER(_HueMask);
uniform float4 _HueMask_ST;
uniform fixed _HueShift;
uniform fixed _FixedHueShift;
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
    float2 uv0 : TEXCOORD0;
    float3 normalDir : TEXCOORD1;
    float3 tangentDir : TEXCOORD2;
    float3 bitangentDir : TEXCOORD3;
    float4 posWorld : TEXCOORD4;
    float4 color : TEXCOORD5;
    float3 normal : TEXCOORD7;
    float4 screenPos : TEXCOORD8;
    float3 objPos : TEXCOORD10;
    float3 vCameraPosX : TEXCOORD11;
    float3 vCameraPosY : TEXCOORD12;
    float3 vCameraPosZ : TEXCOORD13;
    SHADOW_COORDS(6)
    UNITY_FOG_COORDS(9)
};

#if defined(Geometry)
    struct v2g
    {
        float4 pos : CLIP_POS;
        float4 vertex : SV_POSITION;
        float2 uv0 : TEXCOORD0;
        float3 normalDir : TEXCOORD1;
        float3 tangentDir : TEXCOORD2;
        float3 bitangentDir : TEXCOORD3;
        float4 posWorld : TEXCOORD4;
        float4 color : TEXCOORD5;
        float3 normal : TEXCOORD7;
        float4 screenPos : TEXCOORD8;
        float3 objPos : TEXCOORD10;
        float3 vCameraPosX : TEXCOORD11;
        float3 vCameraPosY : TEXCOORD12;
        float3 vCameraPosZ : TEXCOORD13;
        SHADOW_COORDS(6)
        UNITY_FOG_COORDS(9)
    };

    struct g2f
    {
        float4 pos : SV_POSITION;
        float2 uv0 : TEXCOORD0;
        float3 normalDir : TEXCOORD1;
        float3 tangentDir : TEXCOORD2;
        float3 bitangentDir : TEXCOORD3;
        float4 posWorld : TEXCOORD4;
        float4 color : TEXCOORD5;
        float4 screenPos : TEXCOORD7;
        float3 objPos : TEXCOORD9;
        float3 vCameraPosX : TEXCOORD10;
        float3 vCameraPosY : TEXCOORD11;
        float3 vCameraPosZ : TEXCOORD12;
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
    o.uv0 = v.texcoord0;
    o.screenPos = ComputeScreenPos(o.pos);
    o.objPos = normalize(v.vertex);
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
            half outlineWidthMask = EM_SAMPLE_TEX2D_LOD(_OutlineMask, TRANSFORM_TEX(IN[i].uv0, _OutlineMask), 1);
            float3 outlineWidth = _OutlineWidth * .01 * outlineWidthMask;

            outlineWidth *= min(distance(posWorld, _WorldSpaceCameraPos) * 3, 1);
            float4 outlinePos = float4(IN[i].vertex + normalize(IN[i].normal) * outlineWidth, 1);
            
            o.pos = UnityObjectToClipPos(outlinePos);
            o.posWorld = posWorld;
            o.normalDir = IN[i].normalDir;
            o.tangentDir = IN[i].tangentDir;
            o.bitangentDir = IN[i].bitangentDir;
            o.uv0 = IN[i].uv0;
            o.color = float4(_OutlineColor.rgb, 1); // store if outline in alpha channel of vertex colors | 1 = is an outline
            o.screenPos = ComputeScreenPos(o.pos);
            o.objPos = normalize(outlinePos);
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
            o.uv0 = IN[j].uv0;
            o.color = float4(IN[j].color.rgb,0); // store if outline in alpha channel of vertex colors | 0 = not an outline
            o.screenPos = ComputeScreenPos(o.pos);
            o.objPos = normalize(IN[j].vertex);
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
    
    half4 sampledOcclusion = UNITY_SAMPLE_TEX2D_SAMPLER(_OcclusionMap, _MainTex, TRANSFORM_TEX(i.uv0, _OcclusionMap));
    half occlusion = grayscale(LerpOneTo(sampledOcclusion.rgb, _OcclusionStrength));
    half UNUSED_g = sampledOcclusion.g;
    half UNUSED_b = sampledOcclusion.b;
    half UNUSED_a = sampledOcclusion.a;
    
    // r = metallic
    // g = smoothnessY
    // b = anisotropy
    // a = smoothness
    half4 metallicGlossMap = UNITY_SAMPLE_TEX2D_SAMPLER(_MetallicGlossMap, _MainTex, TRANSFORM_TEX(i.uv0, _MetallicGlossMap));
    _Metallic *= metallicGlossMap.r;
    _Glossiness *= metallicGlossMap.a;
    _SmoothnessY *= metallicGlossMap.g;
    _Anisotropy *= metallicGlossMap.b;
    
    half3x3 tangentTransform = half3x3( i.tangentDir, i.bitangentDir, i.normalDir);
    fixed3 _BumpMap_var = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, TRANSFORM_TEX(i.uv0, _BumpMap)));
    half3 normalLocal = half3((_BumpScale * _BumpMap_var.rg), _BumpMap_var.b);
    half3 normalDirection = normalize(mul( normalLocal, tangentTransform )); // Perturbed normals
    half3 doubleSidedNormals = normalDirection;
    half3 doubleSidedTangent = cross(i.bitangentDir, doubleSidedNormals);
    half3 doubleSidedBitangent = cross(doubleSidedNormals, doubleSidedTangent);
    
    
    // ------- View and reflection directions
    half3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
    half3 viewReflectDirection = reflect( -viewDirection, normalDirection );
    half3 velvetDirection = normalize(doubleSidedNormals-0.5*viewDirection);
    
    half3 lightDirection = UnityWorldSpaceLightDir(i.posWorld.xyz);
    half3 halfLightDirection = normalize(lightDirection + viewDirection);

    
    // ------- Fresnel
    half inverseFresnel = max(0, dot(doubleSidedNormals, viewDirection)); 
    half fresnel = 1.0 - inverseFresnel;
    
    // ------- Additional matrix setup

    half3 xiexeLightDir = -calcLightDir(i.posWorld.xyz);
    float4x4 lightViewPlaneToWorld = look_at_matrix(0, 0 - xiexeLightDir, half3(1,0,0));
    
    half3 vCameraPosX = i.vCameraPosX;
    half3 vCameraNegX = -vCameraPosX;
    half3 vCameraPosY = i.vCameraPosY;
    half3 vCameraNegY = -vCameraPosY;
    half3 vCameraPosZ = i.vCameraPosZ;
    half3 vCameraNegZ = -vCameraPosZ;
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
    half3 bakedLightComponent = 0;
    half3 bakedLightAverageComponent = 0;
#if defined(UNITY_PASS_FORWARDBASE)
//#if defined(LIGHTPROBE_SH)
    bakedLightAverageComponent = ShadeSH9(half4(0,0,0,1));

    // Softens the lighting and reduces error with baked directional lights
    half shadeMul = 0.7;
    
    half3 cameraBakedDiffuse = 0;
    half3 lightBakedDiffuse = 0;
    
    for (int j = 0; j < 6; j++) {
      
      //
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
      lightBakedDiffuse = max(lightBakedDiffuse, vLightShade * vLightDot);
    }
    
    half3 velvetColour = 1.5*ShadeSH9(velvetDirection);
    
    bakedLightComponent = lerp(lightBakedDiffuse, cameraBakedDiffuse, lightOrCamera);
    bakedLightComponent = lerp(bakedLightComponent, lerp(bakedLightComponent, max(velvetColour, bakedLightComponent), _ViewDirectionDiffuseBoost), pow(fresnel,4));
    
#endif
    
    // ------- Dynamic diffuse light
    half3 dynamicLightComponent = 0;
    half3 dynamicLightAverageComponent = 0;
    // Should always be active so no point preprocessing
//#if defined(POINT) || defined(SPOT) || defined(DIRECTIONAL) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE)
    EM_LIGHT_ATTENUATION(lightAttenuation, i, i.posWorld.xyz);
    // TODO: What difference does it make doing the rounding here?
    //lightAttenuation.shadow = lerp(lightAttenuation.shadow, round(lightAttenuation.shadow), _DynamicShadowSharpness); 
    fixed attenuation = lightAttenuation.light * lightAttenuation.shadow;
    fixed attenuationNoShadows = lightAttenuation.light;
    fixed shadows = lightAttenuation.light * (1 - lightAttenuation.shadow);
    
    dynamicLightAverageComponent = attenuationNoShadows * _LightColor0.rgb; 
    
    // Get shadows and control their strength/sharpness(xiexe style)
    shadows = lerp(shadows, round(shadows), _DynamicShadowSharpness);
    half3 attenuationNoShadowLift = attenuationNoShadows - shadows;
    shadows *= (1 - _DynamicShadowLift);
    attenuation = attenuationNoShadows - shadows;
    
    half dynamicSideMul = 0.2;
    half3 dynamicSideMul3 = half3(0.2,0.2,0.2);
    half dynamicSide[6] = {dynamicSideMul,dynamicSideMul,dynamicSideMul,dynamicSideMul,0,1};
    half3 dynamicLight = attenuation * _LightColor0.rgb;
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
    half3 dynamicLightDiffuse = dynamicLightDiffuseStrength * dynamicLight;
    half3 dynamicCameraDiffuse = dynamicCameraDiffuseStrength * dynamicLight;
    
    half3 velvetLight = 1.5*dynamicLight * saturate(0.5 * (0.5 + dot(-xiexeLightDir, velvetDirection)));
    
    dynamicLightComponent = lerp(dynamicLightDiffuse, dynamicCameraDiffuse, lightOrCamera);
    dynamicLightComponent = lerp(
      dynamicLightComponent,
      lerp(dynamicLightComponent, max(velvetLight, dynamicLightComponent), _ViewDirectionDiffuseBoost),
      pow(fresnel,4));
//#endif

    // ------- Vertex Lights
    half3 vertexLightComponent = 0;
#if defined(VERTEXLIGHT_ON)
    for (int index = 0; index < 4; index++) {  
      float4 lightPosition = float4(unity_4LightPosX0[index], 
       unity_4LightPosY0[index], 
       unity_4LightPosZ0[index], 1.0);
    
      float3 vertexToLightSource = 
       lightPosition.xyz - i.posWorld;    
      float3 lightDirection = normalize(vertexToLightSource);
      float squaredDistance = 
       dot(vertexToLightSource, vertexToLightSource);
      float attenuation = 1.0 / (1.0 + 
       unity_4LightAtten0[index] * squaredDistance);
      attenuation = attenuation * attenuation;
      float3 diffuseReflection = attenuation * unity_LightColor[index].rgb 
       * max(0.0, dot(i.normalDir, lightDirection) * 0.5 + 0.5);
       // As we are not using fresnelledNormals, should we run vertex lights through the same steps as important lights?
       //* max(0.0, dot(fresnelledNormals, lightDirection) * 0.5 + 0.5);     
    
      vertexLightComponent = vertexLightComponent + diffuseReflection;
    }
#endif

    half3 finalDiffuseLight = bakedLightComponent + dynamicLightComponent + vertexLightComponent;

    // ------- Hue setup
#if defined(HMD_HUE)
    half2 node_6122 = float2(lerp(unity_OrthoParams.x, 0, _FixedHueShift),0.0);
    float2 node_4111_skew = node_6122 + 0.2127+node_6122.x*0.3713*node_6122.y;
    float2 node_4111_rnd = 4.789*sin(489.123*(node_4111_skew));
    half node_4111 = frac(node_4111_rnd.x*node_4111_rnd.y*(1+node_4111_skew.x));
    float4 node_3045_k = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    fixed hueOffset = _HueShift;
    float node_3045_e = 1.0e-10;
    
    float4 node_3045_p = 0;
    float4 node_3045_q = 0;
    float node_3045_d = 0;
    fixed3 node_3045 = 0;
    float3 node_1294 = 0;
    fixed hueMask = UNITY_SAMPLE_TEX2D_SAMPLER(_HueMask, _MainTex, TRANSFORM_TEX(i.uv0, _HueMask)).r;
#endif 
    
    // ------- Emission
    half3 emissive = 0;
#if defined(UNITY_PASS_FORWARDBASE)
    fixed4 sampledEmissionTexture = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap,_MainTex, TRANSFORM_TEX(i.uv0, _EmissionMap));
    emissive = (sampledEmissionTexture * _Emission.rgb);
    
#if defined(HMD_HUE)    
    node_3045_p = lerp(float4(float4(emissive,0.0).zy, node_3045_k.wz), float4(float4(emissive,0.0).yz, node_3045_k.xy), step(float4(emissive,0.0).z, float4(emissive,0.0).y));
    node_3045_q = lerp(float4(node_3045_p.xyw, float4(emissive,0.0).x), float4(float4(emissive,0.0).x, node_3045_p.yzx), step(node_3045_p.x, float4(emissive,0.0).x));
    node_3045_d = node_3045_q.x - min(node_3045_q.w, node_3045_q.y);
    
    node_3045 = float3(abs(node_3045_q.z + (node_3045_q.w - node_3045_q.y) / (6.0 * node_3045_d + node_3045_e)), node_3045_d / (node_3045_q.x + node_3045_e), node_3045_q.x);
    node_1294 = (lerp(float3(1,1,1),saturate(3.0*abs(1.0-2.0*frac((hueOffset+node_4111)+float3(0.0,-1.0/3.0,1.0/3.0)))-1),node_3045.g)*node_3045.b);
                
    emissive = lerp(emissive,node_1294,hueMask);
#endif
#endif
    
    // ------- Diffuse texture
    
    // Allow using a second texture that is used as light decreases?
    //half lowLightTexturePick = saturate(1-pow(max(0,grayscale(finalDiffuseLight)*2-1), 1));
    //fixed4 sampledMainTexture = lerp(UNITY_SAMPLE_TEX2D(_MainTex, TRANSFORM_TEX(i.uv0, _MainTex)), UNITY_SAMPLE_TEX2D_SAMPLER(_LowLightTex,_MainTex, TRANSFORM_TEX(i.uv0, _LowLightTex)), lowLightTexturePick);
    fixed4 sampledMainTexture = UNITY_SAMPLE_TEX2D(_MainTex, TRANSFORM_TEX(i.uv0, _MainTex)) * _Color * half4(i.color.rgb, 1);
    
#if defined(HMD_HUE)
    fixed3 diffuseAndColour = sampledMainTexture.rgb;

                node_3045_p = lerp(float4(float4(diffuseAndColour,0.0).zy, node_3045_k.wz), float4(float4(diffuseAndColour,0.0).yz, node_3045_k.xy), step(float4(diffuseAndColour,0.0).z, float4(diffuseAndColour,0.0).y));
                node_3045_q = lerp(float4(node_3045_p.xyw, float4(diffuseAndColour,0.0).x), float4(float4(diffuseAndColour,0.0).x, node_3045_p.yzx), step(node_3045_p.x, float4(diffuseAndColour,0.0).x));
                node_3045_d = node_3045_q.x - min(node_3045_q.w, node_3045_q.y);

                node_3045 = float3(abs(node_3045_q.z + (node_3045_q.w - node_3045_q.y) / (6.0 * node_3045_d + node_3045_e)), node_3045_d / (node_3045_q.x + node_3045_e), node_3045_q.x);
                node_1294 = (lerp(float3(1,1,1),saturate(3.0*abs(1.0-2.0*frac((hueOffset+node_4111)+float3(0.0,-1.0/3.0,1.0/3.0)))-1),node_3045.g)*node_3045.b);
                
    sampledMainTexture = lerp(sampledMainTexture, fixed4(node_1294,1), hueMask);
#endif
    
    fixed3 diffuseComponent = lerp((sampledMainTexture), grayscale(sampledMainTexture.rgb), (-1 * (_SaturationAdjustment)));

    // -------- Direct and Indirect specular
    half3 __specColor;
    half __oneMinusReflectivity;
    // Note that this is actually albedoComponent for metallic workflow
    half3 __diffColor = DiffuseAndSpecularFromMetallic(diffuseComponent, _Metallic, __specColor, __oneMinusReflectivity);
    
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
    
    bool noReflectionProbe = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, half3(0,0,0), 0).w == 0;
    bool useFallbackReflections = _Usecubemapinsteadofreflectionprobes || noReflectionProbe;
    glossyEnvironmentData.reflUVW = lerp(viewReflectDirection, anisotropicRoughnessReflectionDirection, fragmentCommonData.anisotropy);
    
    half reflectionMipAverage = 100;
    half reflectionFallbackLuminance = grayscale(texCUBElod(_ReflectionCubemap,float4(glossyEnvironmentData.reflUVW,reflectionMipAverage)).rgb);
    half lightLuminance = grayscale(bakedLightAverageComponent + dynamicLightAverageComponent + vertexLightComponent);
    //half fallbackReflectionAdjust = reflectionFallbackLuminance == 0 ? 0 : lightLuminance/reflectionFallbackLuminance;
    
    glossyEnvironmentData.reflectionFallbackMultiplier = lightLuminance;

    half3 emIndirectSpecular = Em_IndirectSpecular(fragmentCommonData, occlusion, glossyEnvironmentData, _ReflectionCubemap, _ReflectionCubemap_HDR, _Usecubemapinsteadofreflectionprobes);
    #if defined(Geometry)
    if (isOutline) {
          // No reflections on outlines
          emIndirectSpecular = 0;
    }
    #endif
    
    //
    //BRDF time
    //
    
    half3 diffuseTerm = dynamicLightComponent;
    
    
    // ------- Specular
    // -- Dynamic Light specular
    
    half anisoSpecLimitSmoothness = saturate(2 * max(_Glossiness,_SmoothnessY));
    
    half3 sharedSpecular = 0;
    
    half tDotV = dot(viewDirection, doubleSidedTangent);
    half bDotV = dot(viewDirection, doubleSidedBitangent);
    half nDotV = abs(dot(doubleSidedNormals, viewDirection));

    half roughnessX = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughnessX);
    half roughnessY = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughnessY);
    half roughness = PerceptualRoughnessToRoughness(glossyEnvironmentData.perceptualRoughness);
    fixed4 sampledSpecularColourMap = tex2D(_SpecularMap, TRANSFORM_TEX(i.uv0, _SpecularMap));
    // We want a really quick blend from normal style to toon style and to then use the rest of the slider/map value to control how smooth the edges of the toon specular are
    // We have to be careful not to blend into toon specular right at 0 as the immediate blend between ~95% normal an ~5% toon is horrible, any values near to zero should result in normal specular to account for mipmapping
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
#if defined(POINT) || defined(SPOT) || defined(DIRECTIONAL) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE) 
    
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

#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSpecular = sqrt(max(1e-2h, anisotropicSpecular));
#	endif
    // Supposedly specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSpecular = max(0, anisotropicSpecular * nDotL);
    // Limit overbrightening on weird normals
    anisotropicSpecular = lerp(anisotropicSpecular, min(anisotropicSpecular, 2*(anisoSpecLimitSmoothness + grayscale(_LightColor0.rgb * attenuationNoShadows))), _CapAnisoSpecular);
    
    halfLightSpecular = lerp(halfLightSpecular, anisotropicSpecular, fragmentCommonData.anisotropy);
    
    // TODO: Should this be done before the lerp?
    halfLightSpecular = halfLightSpecular * saturate(nDotL);
    
    half3 dynamicMaterialSpecularInfluence = FresnelTerm(fragmentCommonData.specColor, nDotH);

    half dynamicToonSpecular = toonSpecularBrightness
                               //the remap gets artifacts when zoomed out when >1
                               * SpecialRemap(toonSpecularSoftness, 1, saturate(halfLightSpecular))
                               / Luminance(dynamicMaterialSpecularInfluence);
    
    half dynamicSpecularBase = lerp(halfLightSpecular, dynamicToonSpecular, isToonSpecular);
    
    half3 dynamicSpecular = _LightColor0.rgb * // Light colour
                            //attenuationNoShadowLift * // Light attenuation
                            attenuation * // Light attenuation
                            dynamicMaterialSpecularInfluence * // Material specular colour influence
                            dynamicSpecularBase * // Specular intensity
                            sampledSpecularColourMap.rgb * // Specular map property
                            _SpecularColour.rgb; // Specular colour property
    sharedSpecular += max(0, dynamicSpecular);
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
    
    bool shReflectionSpecularOn = shReflectionSpecularAlwaysOn || (shReflectionSpecularOnIfNoDynamicOrDirectional && noDynamicLight && noSHDirectionalLight);

    
    half3 shHalfLightDirection = normalize(shLightDir + viewDirection);
    half nDotSHH = dot(doubleSidedNormals, shHalfLightDirection);
    half tDotSHH = dot(doubleSidedTangent, shHalfLightDirection);
    half bDotSHH = dot(doubleSidedBitangent, shHalfLightDirection);
    half nDotSHL = dot(doubleSidedNormals, shLightDir);
    half tDotSHL = dot(doubleSidedTangent, shLightDir);
    half bDotSHL = dot(doubleSidedBitangent, shLightDir);
    half shHalfLightSpecular = GGXNormalDistribution(roughness, nDotSHH);
    
    half anisotropicSHSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotSHL, bDotSHL, nDotSHL, roughnessX, roughnessY);
    anisotropicSHSpecularVisibility = max(0,anisotropicSHSpecularVisibility);
    half anisotropicSHSpecular = D_GGXAnisotropic(tDotSHH, bDotSHH, nDotSHH, roughnessX, roughnessY);

    anisotropicSHSpecular *= anisotropicSHSpecularVisibility;
#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSHSpecular = sqrt(max(1e-2h, anisotropicSHSpecular));
#	endif
    // note: was 2*shLightDir
    
    half3 shSpecularColour = max(0,ShadeSH9(half4(1*shLightDir, 1))-ShadeSH9(half4(0,0,0,1)));
    
    // Supposedly specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSHSpecular = max(0, anisotropicSHSpecular * nDotSHL);
    // Limit overbrightening on weird normals
    anisotropicSHSpecular = lerp(anisotropicSHSpecular, min(anisotropicSHSpecular, 2*(anisoSpecLimitSmoothness + grayscale(shSpecularColour))), _CapAnisoSpecular);
    shHalfLightSpecular = lerp(shHalfLightSpecular, anisotropicSHSpecular, fragmentCommonData.anisotropy);
    
    shHalfLightSpecular *= saturate(nDotSHL);
    
    half3 shDirectionalMaterialSpecularInfluence = FresnelTerm(fragmentCommonData.specColor, nDotSHH);
    
    half shDirectionalToonSpecular = toonSpecularBrightness
                                     //the remap gets artifacts when zoomed out when >1
                                     * SpecialRemap(toonSpecularSoftness, 1, saturate(shHalfLightSpecular))
                                     / Luminance(shDirectionalMaterialSpecularInfluence);
    
    half shDirectionalSpecularBase = lerp(shHalfLightSpecular, shDirectionalToonSpecular, isToonSpecular);
    
    half3 shDirectionalSpecular = shSpecularColour * // 'Light' colour and attenuation
                                  shDirectionalMaterialSpecularInfluence * // Material specular colour influence
                                  shDirectionalSpecularBase * // Specular intensity
                                  sampledSpecularColourMap.rgb * // Specular map property
                                  _SpecularColour.rgb * // Specular colour property
                                  shDirectionalSpecularOn; // Optionally disable sh directional specular
    
    // todo: multiply by the specular colour and colour map!!
    // -- SH Reflect Direction Specular
    half3 shSpecularDirection = viewReflectDirection;
    //half shSpecularFresnel = saturate(0.77*pow(dot(doubleSidedNormals, normalize(doubleSidedNormals + viewDirection)),1));
    // typically lighting will be coming from above and how this works the lighting is centred around the point in the middle of the screen
    // todo: can anythign be done with view position?
    //half3 shSpecularDirectionBoost = half3(0,0,0);//half3(0,-0.3,0);
    
    //half3 shReflectDirection = normalize(shSpecularDirectionBoost + lerp(normalize(doubleSidedNormals + viewDirection),viewReflectDirection,shSpecularFresnel));
    half3 shReflectDirection = viewDirection;
    half3 shHalfReflectDirection = normalize(doubleSidedNormals * 0 + viewDirection * 2);
    half nDotSHRH = dot(doubleSidedNormals, shHalfReflectDirection);
    half tDotSHRH = dot(doubleSidedTangent, shHalfReflectDirection);
    half bDotSHRH = dot(doubleSidedBitangent, shHalfReflectDirection);
    half nDotSHR = dot(doubleSidedNormals, shReflectDirection);
    half tDotSHR = dot(doubleSidedTangent, shReflectDirection);
    half bDotSHR = dot(doubleSidedBitangent, shReflectDirection);
    
    half shSpecular = GGXNormalDistribution(roughness, dot(doubleSidedNormals, viewDirection));
    
    half anisotropicSHRSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotSHR, bDotSHR, nDotSHR, roughnessX, roughnessY);
    anisotropicSHRSpecularVisibility = max(0,anisotropicSHRSpecularVisibility);
    half anisotropicSHRSpecular = D_GGXAnisotropic(tDotSHRH, bDotSHRH, nDotSHRH, roughnessX, roughnessY);
    anisotropicSHRSpecular *= anisotropicSHRSpecularVisibility;
    
#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSHRSpecular = sqrt(max(1e-2h, anisotropicSHRSpecular));
#	endif
    // Trial and error to get nice values, it's pretty similar to just doing ShadeSH9 with unchanged normals, though doesn't seem to result in such big issues with directional baked lights
    half3 sss = max(0,ShadeSH9(half4(0.5*normalize(shSpecularDirection+doubleSidedNormals), 1))-0.4*ShadeSH9(half4(0,0,0,1)));
    // wondering what it would look like without the second sss term
    //sss = 8 * sss * sss;
    sss = 1.5 * sss;

    half3 bakedSpecColour = max(sss, 0);

    // Supposedly specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSHRSpecular = max(0, anisotropicSHRSpecular * nDotSHR);
    // Limit overbrightening on weird normals
    anisotropicSHRSpecular = lerp(anisotropicSHRSpecular, min(anisotropicSHRSpecular, 2 * (anisoSpecLimitSmoothness + grayscale(bakedSpecColour))), _CapAnisoSpecular);

    shSpecular = lerp(shSpecular, anisotropicSHRSpecular, fragmentCommonData.anisotropy);
   
    // Should this be used?
    // 0.1 at 0.7 smoothness
    // 0.5 at 0.3 smoothness
    shSpecular = shSpecular * saturate(dot(doubleSidedNormals, viewDirection));
    //shSpecular = shSpecular * saturate(nDotSHR);
    
    
    half3 shReflectMaterialSpecularInfluence = FresnelTerm(fragmentCommonData.specColor, nDotSHR);
    
    half shToonSpecular = toonSpecularBrightness
                          //the remap gets artifacts when zoomed out when >1
                          * SpecialRemap(toonSpecularSoftness, 1, saturate(shSpecular))
                          / Luminance(shReflectMaterialSpecularInfluence);
    
    half shSpecularBase = lerp(shSpecular, shToonSpecular, isToonSpecular);
    
    half3 bakedSpecular = bakedSpecColour * // 'Light' colour and attenuation
                          shReflectMaterialSpecularInfluence * // Material specular colour influence
                          shSpecularBase * // Specular intensity
                          sampledSpecularColourMap.rgb * // Specular map property
                          _SpecularColour.rgb * // Specular colour property
                          shReflectionSpecularOn; // Optionally disable sh reflect specular
    
    //half bakedShDirectionLerp = saturate(pow(2*max(0,nDotSHL+0.5),1));
    
    sharedSpecular += max(0,max(bakedSpecular, shDirectionalSpecular));
    
#endif
    half3 finalSpecular = sharedSpecular;
    half3 sharedSpecularComponent = finalSpecular;
    
    

#if defined(Geometry)
    if (isOutline) {
      // No specular on outlines
      sharedSpecularComponent = 0;
    }
#endif
    //end specular
     
    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;
#   ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*glossyEnvironmentData.perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#   else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#   endif


    half specularKill = any(fragmentCommonData.specColor) ? 1.0 : 0.0;
    half grazingTerm = saturate(max(fragmentCommonData.smoothnessX, fragmentCommonData.smoothnessY) + (1-fragmentCommonData.oneMinusReflectivity));

    half indirectSpecularFresnelLerp = FresnelLerp(fragmentCommonData.specColor, grazingTerm, saturate(dot(fragmentCommonData.normalWorld, -fragmentCommonData.eyeVec)));
    //indirectSpecularFresnelLerp = lerp(indirectSpecularFresnelLerp, 0, isToonSpecular);

   
    half3 finalDiffuse = fragmentCommonData.diffColor * finalDiffuseLight;
    // Removes indirect lighting from reflection probes in nearly unlit to completely unlit environments
    #if defined(UNITY_PASS_FORWARDBASE)
    _LightColor0.rgb;
    // baked light seems way off?
    half indirectSpecularModifier = saturate(grayscale((bakedLightAverageComponent*100 + (vertexLightComponent + dynamicLightAverageComponent) * 10)));
    #else
    // There isn't any indirect specular anyway since we're in a forwardadd pass, but maybe this will let the compiler be even more aggressive with removing unneeded code
    half indirectSpecularModifier = 0;
    #endif
    half3 finalColor = finalDiffuse * occlusion
                       + sharedSpecularComponent * specularKill
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
    //return max(0, half4(finalColor,1) * 0.001 - 1) + lightAttenuation.shadow;
    //#else
    return half4(finalColor,1);
    //#endif
}