Shader "Em/Toon/6.0/Opaque(HMD-Hue)" {
    Properties {
        [Enum(Off,0,Front,1,Back,2)] _Culling ("Culling Mode", Int) = 2
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Main texture (RGB albedo)", 2D) = "white" {}
        
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        
        _MetallicGlossMap("Metallic/Smoothness (X)/Smoothness Y/Anisotropy map", 2D) = "white" {}
        
        [Gamma] _Metallic ("Metallic (Metallic red)", Range(0.0,1.0)) = 0
        
        _Glossiness ("Smoothness/Smoothness X (Metallic alpha)", Range(0,1)) = 0.5
        
        // New
        _SmoothnessY ("Smoothness Y (Metallic green)", Range(0,1)) = 0.5
        // New
        _Anisotropy ("Anisotropy (Metallic blue)", Range(0,1)) = 0
        // New
        [Enum(Off,0,On,1)] _CapAnisoSpecular ("Cap Anisotropic Specular (leave off unless weird normals on your model cause overbrightening)", Float) = 0
        //_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        // TODO
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("(NYI)Smoothness texture channel", Float) = 0
        
        _SaturationAdjustment ("Saturation Adjustment", Range(-1, 2)) = 0
        
        _DiffuseControlMap("Diffuse Control", 2D) = "white" {}
        _DiffuseSoftness ("Diffuse Smoothness (R)", Range(0, 1)) = 0
        _LightOrView ("Diffuse Light(0)/View(1) Direction Blend (G)", Range(0, 1)) = 0.5
        _DiffuseViewPull ("View Direction Pull (B)", Range(0, 1)) = 0.27
        _ViewDirectionDiffuseBoost ("Velvet Boost (A)", Range(0,1)) = 0
        _DynamicShadowSharpness ("Dynamic Shadow Sharpness", Range(0, 1)) = 1
        _DynamicShadowLift ("Dynamic Shadow Lift", Range(0, 1)) = 0.3
        [HDR]_SpecularColour ("Specular Colour", Color) = (1,1,1,1)
        _ToonSpecular ("Toon Specular (Multiplied by Specular Colour alpha)", Range(0, 1)) = 0
        _SpecularMap ("Specular Colour Map", 2D) = "white" {}
        [Enum(Off,0,On,1,If no dynamic,2)] _ShDirectionalSpecularOn ("Directional Baked Specular", Int) = 1
        [Enum(Off,0,On,1,If no directional or dynamic,2)] _ShReflectionSpecularOn ("Approximate Baked Specular", Int) = 1
        //_NormalMap ("DEPRECIATED_Normal Map", 2D) = "bump" {}
        //_NormalMapStrength ("DEPRECIATED_Normal Map Strength", Float ) = 1
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Map Strength", Float ) = 1
        
        _OcclusionMap("Occlusion Strength (G)", 2D) = "white" {}
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        
        _DetailMask("Detail Mask", 2D) = "white" {}
        
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}
        
        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0
        
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR]_Emission ("DEPRECIATED Emission", Color) = (0,0,0,1)
        [HDR]_EmissionColor ("Emission", Color) = (0,0,0,1)
        _ReflectionCubemap ("Reflection Cubemap (fallback)", Cube) = "_Skybox" {}
        [Enum(Off,0,On,1)] _Usecubemapinsteadofreflectionprobes ("Use fallback instead of probes", Int) = 0
        _HueMask ("Hue Mask", 2D) = "white" {}
        _HueShift ("Hue Shift", Range(0,1)) = 0
        [Enum(Off,0,On,1)] _FixedHueShift ("Fixed Hue Shift", Int) = 0
        
        // Forward rendering options
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        
        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }
    SubShader {
        Tags {
            "RenderType"="Opaque" "Queue"="Geometry"
        }
        Cull [_Culling]
        PASS {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
          
            CGPROGRAM
            //#define Geometry
            
            #pragma target 3.0
            
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
            
            #pragma vertex vert
            #pragma fragment frag
            //#pragma geometry geom
            
            // Testing/WIP
            //#pragma multi_compile _ VERTEXLIGHT_ON
            //#pragma multi_compile LIGHTPROBE_SH
            //#pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
            //#pragma multi_compile _ SHADOWS_SCREEN
            //#pragma multi_compile DIRECTIONAL
            
            // From Xiexe
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase 
            
            //#pragma multi_compile _ VERTEXLIGHT_ON
            //#pragma multi_compile_fwdbase_fullshadows
            
            //#define _GLOSSYENV 1
            
            #ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif
            #ifndef HMD_HUE
                #define HMD_HUE
            #endif
            
            #include "EmToon6PBS_Core.cginc"
            
            ENDCG
        }
      
        PASS {
            Name "FORWARD_ADD"
            Tags {
                "LightMode"="ForwardAdd"
            }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual
            
            CGPROGRAM
            //#define Geometry
            #pragma target 3.0
            
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            
            #pragma vertex vert
            #pragma fragment frag
            //#pragma geometry geom
            //#pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #pragma multi_compile_fwdadd_fullshadows
            
            //#define _GLOSSYENV 1
            
            #ifndef UNITY_PASS_FORWARDADD
                 #define UNITY_PASS_FORWARDADD
            #endif
            #ifndef HMD_HUE
                #define HMD_HUE
            #endif
            
            #include "EmToon6PBS_Core.cginc"
            
            ENDCG
        }
      
        Pass {
            Name "ShadowCaster"
            Tags {
                "LightMode"="ShadowCaster"
            }
            //Offset 1, 1
            ZWrite On ZTest LEqual
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            //#include "Lighting.cginc"
            //#include "UnityPBSLighting.cginc"
            //#include "UnityStandardBRDF.cginc"
            //#include "EmShaderLighting.cginc"
            //#pragma fragmentoption ARB_precision_hint_fastest
            #pragma multi_compile_shadowcaster
            //#pragma only_renderers d3d9 d3d11 glcore gles 
            #pragma target 3.0
            
            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif
            
            struct VertexInput {
                float4 vertex : POSITION;
            };
            struct VertexOutput {
                V2F_SHADOW_CASTER;
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.pos = UnityObjectToClipPos( v.vertex );
                TRANSFER_SHADOW_CASTER(o)
                return o;
            }
            float4 frag(VertexOutput i, float facing : VFACE) : COLOR {
                float isFrontFace = ( facing >= 0 ? 1 : 0 );
                float faceSign = ( facing >= 0 ? 1 : -1 );
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
    CustomEditor "EmToon6PBSShaderGUI"
}