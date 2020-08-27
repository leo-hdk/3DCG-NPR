Shader "Hidden/Custom/PfxSample"
{
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

	TEXTURE2D(_InputColorTexture);
	SAMPLER(sampler_InputColorTexture);
	float4 _InputColorTexture_TexelSize;

	TEXTURE2D(_CameraDepthTexture);
	SAMPLER(sampler_CameraDepthTexture);
	float4 _CameraDepthTexture_TexelSize;

	TEXTURE2D(_CameraNormalTexture);
	SAMPLER(sampler_CameraNormalTexture);
	float4 _CameraNormalTexture_TexelSize;

	float _Exposure;

    float4 Frag(Varyings input) : SV_Target
    {
		const float2 uv = input.uv;
		const float4 inputColor = SAMPLE_TEXTURE2D(_InputColorTexture, sampler_InputColorTexture, uv);
		const float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
		const float3 normal = SAMPLE_TEXTURE2D(_CameraNormalTexture, sampler_CameraNormalTexture, uv).xyz;
		const float linearDepth = Linear01Depth(depth, _ZBufferParams);
		const float viewZ = LinearEyeDepth(depth, _ZBufferParams);

		float4 outColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

		// Tonemap
		outColor.rgb = inputColor.rgb * _Exposure;

		return outColor;
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "PfxSample"

            ZWrite Off
            ZTest Off
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment Frag
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}