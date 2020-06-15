Shader "Hidden/BioumPost/Bloom"
{
    HLSLINCLUDE
        
        #include "ShaderLibrary/StdLib.hlsl"
        #include "ShaderLibrary/Colors.hlsl"
        #include "ShaderLibrary/Sampling.hlsl"

        TEXTURE2D_SAMPLER2D(_CameraColorTex, sampler_CameraColorTex);
        TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);

        float4 _CameraColorTex_TexelSize;
        float  _SampleScale;
        float4 _Threshold; // x: threshold value (linear), y: threshold - knee, z: knee * 2, w: 0.25 / knee

        #define MAX_LUMINANCE 100

        // ----------------------------------------------------------------------------------------
        // Prefilter

        half4 Prefilter(half4 color, float2 uv)
        {
            color = min(MAX_LUMINANCE, color); // clamp to max
            color = QuadraticThreshold(color, _Threshold.x, _Threshold.yzw);
            return color;
        }

        half4 FragPrefilter4(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox4Tap(TEXTURE2D_PARAM(_CameraColorTex, sampler_CameraColorTex), i.texcoord, _CameraColorTex_TexelSize.xy);
            return Prefilter(color, i.texcoord);
        }

        // ----------------------------------------------------------------------------------------
        // Downsample

        half4 FragDownsample4(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox4Tap(TEXTURE2D_PARAM(_CameraColorTex, sampler_CameraColorTex), i.texcoord, _CameraColorTex_TexelSize.xy);
            return color;
        }

        // ----------------------------------------------------------------------------------------
        // Upsample & combine

        half4 Combine(half4 bloom, float2 uv)
        {
            half4 color = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, uv);
            return bloom + color;
        }

        half4 FragUpsampleBox(VaryingsDefault i) : SV_Target
        {
            half4 bloom = UpsampleBox(TEXTURE2D_PARAM(_CameraColorTex, sampler_CameraColorTex), i.texcoord, _CameraColorTex_TexelSize.xy, _SampleScale);
            return Combine(bloom, i.texcoord);
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0: Prefilter 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragPrefilter4

            ENDHLSL
        }

        // 1: Downsample 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDownsample4

            ENDHLSL
        }

        // 2: Upsample box filter
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragUpsampleBox

            ENDHLSL
        }
    }
}

