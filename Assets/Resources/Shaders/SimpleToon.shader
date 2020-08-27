Shader "Unlit/SimpleToon"
{
    Properties
    {
        _LineWidth( "Line Width", Range( 0.0, 10.0 ) ) = 0.01
        _LineColor( "Line Color", Color ) = ( 0.0, 0.0, 0.0, 1.0 )

        _MainTex( "MainColor Texture", 2D ) = "white" {}
        _ShadowTex ("ShadowColor Texture", 2D) = "white" {}
        _Threshold( "Toon Threshold", Range( -1.0, 1.0 ) ) = 0.0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 100

        Pass
        {
            Name "Outline"

            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float       _LineWidth;
            float4      _LineColor;

            struct Attributes
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex   : SV_POSITION;
                float4 color    : COLOR;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( (input.vertex + float4( _LineWidth * input.normal, 0.0f )).xyz );
                output.vertex = vertexData.positionCS;

                output.color = _LineColor;
                return output;
            }

            float4 frag( Varyings input ) : SV_Target {
                return input.color;
            }
                ENDHLSL
        }

        Pass
        {
            Name "Shading"

            Tags{ "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D   _MainTex;
            float4      _MainTex_ST;
            sampler2D   _ShadowTex;
            float4      _ShadowTex_ST;
            float       _Threshold;

            struct Attributes
            {
                float4 vertex       : POSITION;
                float3 normal       : NORMAL;
                float4 tangent      : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float2 lightmapUV   : TEXCOORD1;
            };

            struct Varyings
            {
                float4 vertex       : SV_POSITION;  // 同時座標
                float3 wPosition    : POSITION1;    // ワールド空間座標
                float2 sPosition    : POSITION2;    // スクリーン座標
                float3 wNormal      : NORMAL;       // ワールド空間法線
                float3 wTangent     : TANGENT;      // ワールド空間接線
                float4 texCoord0    : TEXCOOR0;     // テクスチャ座標（xy : メインカラー、zw : シャドウカラー）
                float4 shadowCoord  : TEXCOOR2;     // シャドウ用座標
                DECLARE_LIGHTMAP_OR_SH( lightmapUV, vertexSH, 1 ); // 環境光
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex.xyz );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex       = vertexData.positionCS;
                output.wPosition    = vertexData.positionWS;
                output.sPosition    = ComputeScreenPos( output.vertex ).xy;
                output.wNormal      = normalData.normalWS.xyz;
                output.wTangent     = normalData.tangentWS.xyz;
                output.texCoord0.xy = TRANSFORM_TEX( input.texcoord.xy, _MainTex ).xy;
                output.texCoord0.zw = TRANSFORM_TEX( input.texcoord.xy, _ShadowTex ).xy;

                #if defined(_MAIN_LIGHT_SHADOWS)
                    output.shadowCoord = GetShadowCoord( vertexData );
                #else
                    output.shadowCoord = float4( 0.0, 0.0, 0.0, 0.0 );
                #endif

                OUTPUT_LIGHTMAP_UV( input.lightmapUV, unity_LightmapST, output.lightmapUV );
                OUTPUT_SH( normalData.normalWS.xyz, output.vertexSH );

                return output;
            }

            float4 frag( Varyings input ) : SV_Target
            {
                float4 mainColor    = tex2D( _MainTex, input.texCoord0.xy );
                float4 shadowColor  = tex2D( _ShadowTex, input.texCoord0.zw );

                Light mainLight = GetMainLight( input.shadowCoord );

                float toon = float( dot( mainLight.direction, input.wNormal ) > _Threshold ); // トゥーンの式

                float4 finalColor = lerp( shadowColor, mainColor, toon );   // トゥーンの値でメインカラーとシャドウカラーを塗り分ける

                finalColor.rgb *= mainLight.shadowAttenuation; // 影を適用
                finalColor.rgb += SAMPLE_GI( input.lightmapUV, input.vertexSH, input.wNormal ); // 環境光を適用

                return finalColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 5.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "AdditionalTexture"
            Tags { "LightMode" = "AdditionalTexture" }

            Cull Back
            ZWrite ON

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex   : SV_POSITION;
                float3 wNormal  : NORMAL;
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex  = vertexData.positionCS;
                output.wNormal = normalData.normalWS.xyz;

                return output;
            }

            float4 frag( Varyings input ) : SV_Target
            {
                return float4(input.wNormal, 1.0);
            }

            ENDHLSL
        }

    }
}
