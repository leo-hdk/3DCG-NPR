Shader "Hidden/Custom/CameraNormalTexture"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
        }
        LOD 100

        Pass
        {
            Name "CameraNormalTexture"

            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag

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
                float3 normal  : NORMAL;
            };

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexData = GetVertexPositionInputs( input.vertex.xyz );
                VertexNormalInputs   normalData = GetVertexNormalInputs( input.normal, input.tangent );

                output.vertex  = vertexData.positionCS;
                output.normal = mul( ( float3x3 )( UNITY_MATRIX_V ), normalData.normalWS.xyz ); // View space の法線を書き出す

                return output;
            }

            float4 frag( Varyings input ) : SV_Target
            {
                return float4(input.normal, 1.0);
            }

            ENDHLSL
        }
    }
}
