Shader "Em/Toon/5.0/Opaque" {
    Properties {
        [Enum(Off,0,Front,1,Back,2)] _Culling ("Culling Mode", Int) = 2
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Main texture (RGB)", 2D) = "white" {}
        _SaturationAdjustment ("Saturation Adjustment", Range(-1, 2)) = 0
        _DiffuseSoftness ("Diffuse Smoothness", Range(0, 1)) = 0
        _LightOrView ("<- Light Direction - View Direction ->", Range(0, 1)) = 0.5
        _DiffuseViewPull ("View Direction Pull", Range(0, 1.5)) = 0.4
        _ViewDirectionDiffuseBoost ("Velvet Boost", Range(0,10)) = 0
        _DynamicShadowSharpness ("Dynamic Shadow Sharpness", Range(0, 1)) = 1
        _DynamicShadowLift ("Dynamic Shadow Lift", Range(0, 1)) = 0.3
        _SpecularColour ("Specular Colour", Color) = (1,1,1,1)
        [NoScaleOffset]_SpecularRamp ("Specular Ramp", 2D) = "black" {}
        [Enum(Off,0,On,1)] _ExtendSpecularRange ("Extend Specular Ramp Range", Int) = 0
        _SpecularMap ("Specular Colour Map", 2D) = "white" {}
        _Specularity ("Specularity", Range(0, 1)) = 0
        _SpecularMax ("Specular Max", Float ) = 4
        _GlossMap ("Gloss Map", 2D) = "white" {}
        _Glossiness ("Glossiness", Range(0, 1)) = 0
        [Enum(Off,0,On,1)] _ShDirectionalSpecularOn ("Directional Baked Specular", Int) = 1
        [Enum(Off,0,On,1)] _ShReflectionSpecularOn ("Approximate Baked Specular", Int) = 1
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalMapStrength ("Normal Map Strength", Float ) = 1
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR]_Emission ("Emission", Color) = (0,0,0,1)
        _ReflectionMap ("Reflection Map (Alpha is reflection quality)", 2D) = "white" {}
        _ReflectionStrength ("Reflection Strength", Range(0, 1)) = 0
        _ReflectionQuality ("Reflection Quality", Range(0, 10)) = 10
        _PlasticityMap ("Reflection Plasticity Map (alpha is blend)", 2D) = "white" {}
        _ReflectionPlasticity ("Reflection Plasticity", Range(0, 5)) = 0
        _ReflectionPlasticityBlend ("Reflection Plasticity Blend", Range(0, 1)) = 0
        _ReflectionCubemap ("Reflection Cubemap (fallback)", Cube) = "_Skybox" {}
        [Enum(Off,0,On,1)] _Usecubemapinsteadofreflectionprobes ("Use fallback instead of probes", Int) = 0
        _Intensity ("Brightness", Range(0, 2)) = 1
        _Anisotropy ("Anisotropy", Range(0,1)) = 0
        _AnisotropyX ("Anisotropy Width", Range(0,1)) = 0
        _AnisotropyY ("Anisotropy Height", Range(0,1)) = 0

    }
    SubShader {
        Tags {
            "RenderType"="Opaque"
        }
        Cull [_Culling]
        PASS {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
          
            CGPROGRAM
            //#define Geometry
            
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
            
            #include "EmToon5_Core.cginc"
            
            ENDCG
        }
      
        PASS {
            Name "FORWARD_ADD"
            Tags {
                "LightMode"="ForwardAdd"
            }
            // Correct
            Blend One One
            
            CGPROGRAM
            //#define Geometry
            
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
            
            #include "EmToon5_Core.cginc"
            
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
            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif
            #define _GLOSSYENV 1
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardBRDF.cginc"
            #include "EmShaderLighting.cginc"
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma multi_compile_shadowcaster
            #pragma only_renderers d3d9 d3d11 glcore gles 
            #pragma target 3.0
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
}