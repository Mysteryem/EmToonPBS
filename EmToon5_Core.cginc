#include "EmShaderFunctionsToon5.cginc"

uniform fixed4 _Color;
uniform sampler2D _MainTex;
uniform float4 _MainTex_ST;
uniform fixed _SaturationAdjustment;

uniform sampler2D _MainRamp;
uniform half _MainRampShift;
uniform sampler2D _SpecularRamp;

uniform sampler2D _EmissionMap;
uniform float4 _EmissionMap_ST;
uniform fixed4 _Emission;

uniform half _DiffuseViewPull;
uniform fixed _DiffuseSoftness;
uniform fixed _LightOrView;
uniform half _ViewDirectionDiffuseBoost;

uniform fixed _DynamicShadowSharpness;
uniform fixed _DynamicShadowLift;

uniform sampler2D _NormalMap;
uniform float4 _NormalMap_ST;
uniform half _NormalMapStrength;

uniform fixed _Glossiness;
uniform sampler2D _GlossMap;
uniform float4 _GlossMap_ST;

uniform fixed4 _SpecularColour;
uniform sampler2D _SpecularMap;
uniform float4 _SpecularMap_ST;
uniform half _SpecularMax;
uniform fixed _Specularity;
uniform fixed _ShDirectionalSpecularOn;
uniform fixed _ShReflectionSpecularOn;
uniform fixed _ExtendSpecularRange;

uniform samplerCUBE _ReflectionCubemap;
uniform fixed _ReflectionStrength;
uniform sampler2D _ReflectionMap;
uniform float4 _ReflectionMap_ST;
uniform half _ReflectionQuality;
uniform half _ReflectionPlasticity;
uniform sampler2D _PlasticityMap;
uniform float4 _PlasticityMap_ST;
uniform fixed _ReflectionPlasticityBlend;
uniform fixed _Usecubemapinsteadofreflectionprobes;

uniform fixed _Anisotropy;
uniform fixed _AnisotropyX;
uniform fixed _AnisotropyY;

uniform half _Intensity;

#if defined(HMD_HUE)
uniform sampler2D _HueMask;
uniform float4 _HueMask_ST;
uniform fixed _HueShift;
uniform fixed _FixedHueShift;
#endif

#if defined(Geometry)
uniform half4 _OutlineColor;
uniform half _OutlineWidth;
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
            float3 outlineWidth = _OutlineWidth * .01;

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

float4 frag(
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
    
    half3x3 tangentTransform = half3x3( i.tangentDir, i.bitangentDir, i.normalDir);
    fixed3 _NormalMap_var = UnpackNormal(tex2D(_NormalMap, TRANSFORM_TEX(i.uv0, _NormalMap)));
    half3 normalLocal = half3((_NormalMapStrength * _NormalMap_var.rg), _NormalMap_var.b);
    half3 normalDirection = normalize(mul( normalLocal, tangentTransform )); // Perturbed normals
    half3 doubleSidedNormals = normalDirection;
    half3 doubleSidedTangent = cross(i.bitangentDir, doubleSidedNormals);
    half3 doubleSidedBitangent = cross(doubleSidedNormals, doubleSidedTangent);
    
    _AnisotropyX = max(0.000001, _AnisotropyX);
    _AnisotropyY = max(0.000001, _AnisotropyY);
    
    
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
    // TODO: There's probably a better way to call the light and shadow parts separately instead of calling light+shadow and light-only separately
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
    half3 rawDynamicLight = attenuation * _LightColor0.rgb;
    EM_LIGHT_ATTENUATION(attenuationNoShadows, i, i.posWorld.xyz);//gives us a float attenuationNoShadows
    dynamicLightAverageComponent = attenuationNoShadows * _LightColor0.rgb; 
    
    // Get shadows and control their strength/sharpness(xiexe style)
    half3 shadows = attenuationNoShadows - attenuation;
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
    fixed hueMask = tex2D(_HueMask, TRANSFORM_TEX(i.uv0, _HueMask)).r;
#endif 
    
    // ------- Emission
    half3 emissive = 0;
#if defined(UNITY_PASS_FORWARDBASE)
    fixed4 sampledEmissionTexture = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0, _EmissionMap));
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
    fixed4 sampledMainTexture = tex2D(_MainTex, TRANSFORM_TEX(i.uv0, _MainTex)) * _Color * half4(i.color.rgb, 1);
    
#if defined(HMD_HUE)
    fixed3 diffuseAndColour = sampledMainTexture.rgb;

                node_3045_p = lerp(float4(float4(diffuseAndColour,0.0).zy, node_3045_k.wz), float4(float4(diffuseAndColour,0.0).yz, node_3045_k.xy), step(float4(diffuseAndColour,0.0).z, float4(diffuseAndColour,0.0).y));
                node_3045_q = lerp(float4(node_3045_p.xyw, float4(diffuseAndColour,0.0).x), float4(float4(diffuseAndColour,0.0).x, node_3045_p.yzx), step(node_3045_p.x, float4(diffuseAndColour,0.0).x));
                node_3045_d = node_3045_q.x - min(node_3045_q.w, node_3045_q.y);

                node_3045 = float3(abs(node_3045_q.z + (node_3045_q.w - node_3045_q.y) / (6.0 * node_3045_d + node_3045_e)), node_3045_d / (node_3045_q.x + node_3045_e), node_3045_q.x);
                node_1294 = (lerp(float3(1,1,1),saturate(3.0*abs(1.0-2.0*frac((hueOffset+node_4111)+float3(0.0,-1.0/3.0,1.0/3.0)))-1),node_3045.g)*node_3045.b);
                
    sampledMainTexture = lerp(sampledMainTexture, fixed4(node_1294,1), hueMask);
#endif
    
    fixed3 diffuseComponent = lerp((sampledMainTexture), grayscale(sampledMainTexture.rgb), (-1 * _SaturationAdjustment));


    
    // ------- Reflections
    fixed4 sampledReflectionMap = tex2D(_ReflectionMap,TRANSFORM_TEX(i.uv0, _ReflectionMap));
    half reflectionMip = 10 - _ReflectionQuality * sampledReflectionMap.a;
    half reflectionMipAverage = 100;
    
    half3 anisotropicDirection = _AnisotropyX >= _AnisotropyY ? doubleSidedBitangent : doubleSidedTangent;
    half3 anisotropicTangent = cross(anisotropicDirection, viewDirection);
    half3 anisotropicNormal = cross(anisotropicTangent, anisotropicDirection);
    half3 bentNormal = normalize(lerp(doubleSidedNormals, anisotropicNormal, abs(_AnisotropyX - _AnisotropyY)));
    half3 anisotropicReflectionDirection = reflect(-viewDirection, bentNormal);
    
    //half3 fixedAnisotropicReflectionDirection = reflect(viewDirection, doubleSidedBitangent);
    half3 reflectionDirection = lerp(viewReflectDirection, anisotropicReflectionDirection, _Anisotropy);
    float3 reflectionFallback = texCUBElod(_ReflectionCubemap,float4(reflectionDirection,reflectionMip)).rgb;
    float3 reflectionFallbackAverage = texCUBElod(_ReflectionCubemap,float4(reflectionDirection,reflectionMipAverage)).rgb;
    
    // Sample reflection probes
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionDirection, reflectionMip);
    half4 skyDataAverage = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, half3(0,0,0), reflectionMipAverage);

    half3 probe0sample = DecodeHDR(skyData, unity_SpecCube0_HDR);
    half3 probe0sampleAverage = DecodeHDR(skyDataAverage, unity_SpecCube0_HDR);

    half3 probeReflections;
    half3 probeReflectionsAverage;
    fixed interpolator = unity_SpecCube0_BoxMin.w;
    bool usingFallbackCubemap = false;

    UNITY_BRANCH
    if (interpolator < 0.99999) {
      half4 skyData1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflectionDirection, reflectionMip);
      half4 skyData1Average = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, half3(0,0,0), reflectionMipAverage);
      half3 probe1sample = DecodeHDR(skyData1, unity_SpecCube1_HDR);
      half3 probe1sampleAverage = DecodeHDR(skyData1Average, unity_SpecCube1_HDR);
      probeReflections = lerp(probe1sample, probe0sample, interpolator);
      probeReflectionsAverage = lerp(probe1sampleAverage, probe0sampleAverage, interpolator);
    }
    else {
      probeReflections = probe0sample;
      probeReflectionsAverage = probe0sampleAverage;
    }

    //if (!any(probeReflections)) {
    if (!any(probeReflectionsAverage)) {
      probeReflections = reflectionFallback;
      probeReflectionsAverage = reflectionFallbackAverage;
      usingFallbackCubemap = true;
    }


    half3 reflectionComponent = lerp(probeReflections, reflectionFallback, _Usecubemapinsteadofreflectionprobes);
    half3 reflectionComponentAverage = lerp(probeReflectionsAverage, reflectionFallbackAverage, _Usecubemapinsteadofreflectionprobes);
    
#if defined(Geometry)
    if (isOutline) {
          // No reflections on outlines
          reflectionComponent = 0;
    }
#endif
    
    
    // ------- Specular
    fixed4 glossMap = tex2D(_GlossMap, TRANSFORM_TEX(i.uv0, _GlossMap));
    half3 specularDirection = viewReflectDirection;
    half3 darkenSource = 0;
    half3 sharedLight = 0;
    half3 sharedSpecular = 0;
    
    half tDotV = dot(viewDirection, doubleSidedTangent);
    half bDotV = dot(viewDirection, doubleSidedBitangent);
    half nDotV = abs(dot(doubleSidedNormals, viewDirection));
#if defined(POINT) || defined(SPOT) || defined(DIRECTIONAL) || defined(POINT_COOKIE) || defined(DIRECTIONAL_COOKIE) 
    
    half nDotH = dot(doubleSidedNormals, halfLightDirection);
    half tDotL = dot(doubleSidedTangent, lightDirection);
    half bDotL = dot(doubleSidedBitangent, lightDirection);
    half nDotL = dot(doubleSidedNormals, lightDirection);
    half tDotH = dot(doubleSidedTangent, halfLightDirection);
    half bDotH = dot(doubleSidedBitangent, halfLightDirection);
    half halfLightSpecular = GGXNormalDistribution(sqr(1 - (glossMap.rgb * _Glossiness)), nDotH);
    
    half anisotropicSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotL, bDotL, nDotL, _AnisotropyX, _AnisotropyY);
    anisotropicSpecularVisibility = max(0,anisotropicSpecularVisibility);
    half anisotropicSpecular = D_GGXAnisotropic(tDotH, bDotH, nDotH, _AnisotropyX, _AnisotropyY);
    anisotropicSpecular *= anisotropicSpecularVisibility;
#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSpecular = sqrt(max(1e-2h, anisotropicSpecular));
#	endif
    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSpecular = max(0, anisotropicSpecular * nDotL);
    
    halfLightSpecular = lerp(halfLightSpecular, anisotropicSpecular, _Anisotropy);
    
    halfLightSpecular = saturate(_Specularity * _SpecularMax * halfLightSpecular);
    half3 dynamicSpecular = halfLightSpecular * _LightColor0.rgb * attenuationNoShadowLift;
    // Extend range
    halfLightSpecular *= lerp(1, 0.5, _ExtendSpecularRange);
    fixed3 sampledSpecularRamp = tex2D(_SpecularRamp, float2(halfLightSpecular, halfLightSpecular)).rgb;
    // Extend range
    sampledSpecularRamp *= lerp(1, 2, _ExtendSpecularRange);
    dynamicSpecular *= sampledSpecularRamp * tex2D(_SpecularMap, TRANSFORM_TEX(i.uv0, _SpecularMap)).rgb * _SpecularColour.rgb;
    sharedSpecular += dynamicSpecular;
#endif
#if defined(UNITY_PASS_FORWARDBASE)
    // SH specular
    half3 shLightDir = calcLightDirSH(i.posWorld.xyz);
    half3 shHalfLightDirection = normalize(shLightDir + viewDirection);
    half nDotSHH = dot(doubleSidedNormals, shHalfLightDirection);
    half tDotSHH = dot(doubleSidedTangent, shHalfLightDirection);
    half bDotSHH = dot(doubleSidedBitangent, shHalfLightDirection);
    half nDotSHL = dot(doubleSidedNormals, shLightDir);
    half tDotSHL = dot(doubleSidedTangent, shLightDir);
    half bDotSHL = dot(doubleSidedBitangent, shLightDir);
    half shHalfLightSpecular = GGXNormalDistribution(sqr(1 - (glossMap.rgb * _Glossiness)), nDotSHH);
    
    half anisotropicSHSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotSHL, bDotSHL, nDotSHL, _AnisotropyX, _AnisotropyY);
    anisotropicSHSpecularVisibility = max(0,anisotropicSHSpecularVisibility);
    half anisotropicSHSpecular = D_GGXAnisotropic(tDotSHH, bDotSHH, nDotSHH, _AnisotropyX, _AnisotropyY);
    anisotropicSHSpecular *= anisotropicSHSpecularVisibility;
#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSHSpecular = sqrt(max(1e-2h, anisotropicSHSpecular));
#	endif
    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSHSpecular = max(0, anisotropicSHSpecular * nDotSHL);
    shHalfLightSpecular = lerp(shHalfLightSpecular, anisotropicSHSpecular, _Anisotropy);
    
    shHalfLightSpecular = saturate(_Specularity * _SpecularMax * shHalfLightSpecular);
    // note: was 2*shLightDir
    half3 shSpecularColour = max(0,ShadeSH9(half4(1*shLightDir, 1))-ShadeSH9(half4(0,0,0,1)));
    //half3 shSpecularColour = max(0,ShadeSH9(half4(shLightDir, 1)));
    half3 shDirectionalSpecular = shHalfLightSpecular * shSpecularColour;
    // Extend range
    shHalfLightSpecular *= lerp(1, 0.5, _ExtendSpecularRange);
    fixed3 sampledDirectionalSHSpecularRamp = tex2D(_SpecularRamp, float2(shHalfLightSpecular, shHalfLightSpecular)).rgb;
    // Extend range
    sampledDirectionalSHSpecularRamp *= lerp(1, 2, _ExtendSpecularRange);
    shDirectionalSpecular *= sampledDirectionalSHSpecularRamp * tex2D(_SpecularMap, TRANSFORM_TEX(i.uv0, _SpecularMap)).rgb * _SpecularColour.rgb;
    shDirectionalSpecular *= _ShDirectionalSpecularOn;
    
    
    // todo: multiply by the specular colour and colour map!!
    // SH specular extra
    half3 shSpecularDirection = viewReflectDirection;
    half shSpecularFresnel = saturate(0.77*pow(dot(doubleSidedNormals, normalize(doubleSidedNormals + viewDirection)),1));
    // typically lighting will be coming from above and how this works the lighting is centred around the point in the middle of the screen
    // todo: can anythign be done with view position?
    half3 shSpecularDirectionBoost = half3(0,0,0);//half3(0,-0.3,0);
    
    //half3 shReflectDirection = normalize(shSpecularDirectionBoost + lerp(normalize(doubleSidedNormals + viewDirection),viewReflectDirection,shSpecularFresnel));
    half3 shReflectDirection = normalize(doubleSidedNormals + viewDirection);
    half3 shHalfReflectDirection = normalize(shReflectDirection + viewDirection);
    half nDotSHRH = dot(doubleSidedNormals, shHalfReflectDirection);
    half tDotSHRH = dot(doubleSidedTangent, shHalfReflectDirection);
    half bDotSHRH = dot(doubleSidedBitangent, shHalfReflectDirection);
    half nDotSHR = dot(doubleSidedNormals, shReflectDirection);
    half tDotSHR = dot(doubleSidedTangent, shReflectDirection);
    half bDotSHR = dot(doubleSidedBitangent, shReflectDirection);
    
    half shSpecular = GGXNormalDistribution(sqr(1- (glossMap.rgb * _Glossiness)), nDotSHR);
    
    half anisotropicSHRSpecularVisibility = SmithJointGGXAnisotropic(tDotV, bDotV, nDotV, tDotSHR, bDotSHR, nDotSHR, _AnisotropyX, _AnisotropyY);
    anisotropicSHRSpecularVisibility = max(0,anisotropicSHRSpecularVisibility);
    half anisotropicSHRSpecular = D_GGXAnisotropic(tDotSHRH, bDotSHRH, nDotSHRH, _AnisotropyX, _AnisotropyY);
    anisotropicSHRSpecular *= anisotropicSHRSpecularVisibility;
#	ifdef UNITY_COLORSPACE_GAMMA
    anisotropicSHRSpecular = sqrt(max(1e-2h, anisotropicSHRSpecular));
#	endif
    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    anisotropicSHRSpecular = max(0, anisotropicSHRSpecular * nDotSHR);
    
    shSpecular = lerp(shSpecular, anisotropicSHRSpecular, _Anisotropy);
    
    shSpecular = saturate(_Specularity * _SpecularMax * shSpecular);
   
    // Trial and error to get nice values, it's pretty similar to just doing ShadeSH9 with unchanged normals, though doesn't seem to result in such big issues with directional baked lights
    half3 sss = max(0,ShadeSH9(half4(0.5*normalize(shSpecularDirection+doubleSidedNormals), 1))-0.4*ShadeSH9(half4(0,0,0,1)));
    // wondering what it would look like without the second sss term
    //sss = 8 * sss * sss;
    sss = 1.5 * sss;

    half3 bakedSpecColour = max(sss, 0);
    
    half3 bakedSpecular = shSpecular * bakedSpecColour;
    // Extend range
    shSpecular *= lerp(1, 0.5, _ExtendSpecularRange);
    fixed3 sampledSHSpecularRamp = tex2D(_SpecularRamp, float2(shSpecular, shSpecular)).rgb;
    // Extend range
    sampledSHSpecularRamp *= lerp(1, 2, _ExtendSpecularRange);
    bakedSpecular *= sampledSHSpecularRamp * tex2D(_SpecularMap, TRANSFORM_TEX(i.uv0, _SpecularMap)).rgb * _SpecularColour.rgb;
    bakedSpecular *= _ShReflectionSpecularOn;
    
    half bakedShDirectionLerp = saturate(pow(2*max(0,nDotSHL+0.5),1));
    
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

    // ----- Final lighting combination
    // Sum of diffuse light * (diffuse texture + reflections)
    half3 finalDiffuse = (bakedLightComponent + dynamicLightComponent + vertexLightComponent)
    * diffuseComponent;
    
    // ------- Reflection (indirect specular) and Diffuse blend
    half3 averageLight = bakedLightAverageComponent + dynamicLightAverageComponent + vertexLightComponent;
    half averageLightLuminance = grayscale(averageLight);
    half averageReflectionProbeLuminance = grayscale(reflectionComponentAverage);
    fixed3 reflectionStrength = sampledReflectionMap.rgb * _ReflectionStrength;
    fixed4 sampledPlasticity = tex2D(_PlasticityMap,TRANSFORM_TEX(i.uv0, _PlasticityMap));
    half3 reflectionPlasticity = _ReflectionPlasticity * sampledPlasticity.rgb;
    half reflectionMetallic = 1-saturate(reflectionPlasticity.r);
    //return reflectionMetallic;
    half3 reflectionFresnelPow = lerp(1, 5, reflectionMetallic);
    half plasticityBlend = _ReflectionPlasticityBlend * sampledPlasticity.a;
    // This is the lerp variable used to lerp between the diffuse component and the diffuse component linear dodge blended with the reflection component
    // Lerps between the reflection with and without the multiplied fresnel
    half3 reflectionFresnelMultiplier = pow(fresnel, reflectionFresnelPow);
    half3 reflectionDiffuseBlend = reflectionFresnelMultiplier;
    // FIXME: Detect if cubemap has no mip maps and instead multiply directly by averageLightLuminance?
    
    // When using a fallback, try adjusting the brightness of the fallback to the brightness of the light
    // Ensure that the fallback has mip maps otherwise the averageReflectionProveLuminance will have an unexpected value
    if (usingFallbackCubemap || _Usecubemapinsteadofreflectionprobes == 1) {
      half fallbackReflectionAdjust = averageReflectionProbeLuminance == 0 ? 0 : averageLightLuminance/averageReflectionProbeLuminance;
      // Limit overbrightening
      fallbackReflectionAdjust = min(2, 0.5*fallbackReflectionAdjust);
      reflectionComponent *= fallbackReflectionAdjust;
    } else {
      // Darken reflections when there is no light aside from the reflections
      if (averageLightLuminance < averageReflectionProbeLuminance) {
        reflectionComponent *= saturate(averageLightLuminance * 10);
      }
    }
    half3 metallicAndDiffuse = finalDiffuse * reflectionComponent;
    half3 metallicGrazing = reflectionComponent;
    half3 plasticGrazing = lerp(finalDiffuse, reflectionComponent, reflectionDiffuseBlend);
    half3 edgeChoice = lerp(plasticGrazing, metallicGrazing, reflectionMetallic);
    half3 reflectionComponentPostPlasticity = lerp(finalDiffuse, metallicAndDiffuse, reflectionMetallic);
    half3 reflectionAndDiffuseBlended = lerp(reflectionComponentPostPlasticity, edgeChoice, reflectionDiffuseBlend);
    //half3 reflectionAndDiffuseBlended = lerp(finalDiffuse, reflectionComponentPostPlasticity, reflectionDiffuseBlend);
    reflectionAndDiffuseBlended = lerp(finalDiffuse, reflectionAndDiffuseBlended, reflectionStrength);
    //return half4(reflectionAndDiffuseBlended, 1);
    
    
    


    
    // Add specular
    float oneMinusReflectivity;//unused
    half3 finalDiffuseAndSpecular = max(reflectionAndDiffuseBlended, sharedSpecularComponent +
        EnergyConservationBetweenDiffuseAndSpecular(reflectionAndDiffuseBlended, sharedSpecularComponent, oneMinusReflectivity));
    half3 finalColour = finalDiffuseAndSpecular * _Intensity;
    return float4(max(saturate(finalColour), emissive), 1.0);
}