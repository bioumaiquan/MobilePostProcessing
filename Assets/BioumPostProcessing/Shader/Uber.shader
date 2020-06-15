Shader "Hidden/BioumPost/Uber"
{   
    HLSLINCLUDE

    #pragma multi_compile __ BLOOM
    #pragma multi_compile __ COLOR_GRADING_LDR_2D
    #pragma multi_compile __ SCREEN_DISTORT
    #pragma multi_compile __ ACES_TONEMAPPING

    #include "ShaderLibrary/StdLib.hlsl"
    #include "ShaderLibrary/Colors.hlsl"
    #include "ShaderLibrary/Sampling.hlsl"

    TEXTURE2D_SAMPLER2D(_CameraColorTex, sampler_CameraColorTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthTex, sampler_CameraDepthTex);
    bool _UseFXAA;

    #if BLOOM
        TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);
        half4 _BloomTex_TexelSize;
        half _BloomIntensity;
        half  _SampleScale;
    #endif

    #if COLOR_GRADING_LDR_2D
        TEXTURE2D_SAMPLER2D(_Lut2D, sampler_Lut2D);
        half4 _Lut2D_Params;
    #endif

    #if SCREEN_DISTORT
        TEXTURE2D_SAMPLER2D(_DistortTex, sampler_DistortTex);
        half4 _DistortParams;
    #endif

    half4 FragUber(VaryingsDefault i) : SV_Target
    {
        half2 uv = i.texcoord;

        #if SCREEN_DISTORT
            half2 distortUV = frac((uv - _Time.y * _DistortParams.xy) * _DistortParams.w);
            half distortTex = SAMPLE_TEXTURE2D(_DistortTex, sampler_DistortTex, distortUV).x;
            distortTex -= 0.5;

            uv += distortTex * _DistortParams.z;
        #endif

        half4 color = SAMPLE_TEXTURE2D(_CameraColorTex, sampler_CameraColorTex, uv);
        #if UNITY_COLORSPACE_GAMMA
            color = SRGBToLinear(color);
        #endif

        #if BLOOM
            half3 bloom = UpsampleBox(TEXTURE2D_PARAM(_BloomTex, sampler_BloomTex), uv, _BloomTex_TexelSize.xy, _SampleScale).rgb;
            color.rgb += bloom * _BloomIntensity; 
        #endif

        #if ACES_TONEMAPPING
            color.rgb = unity_to_ACES(color.rgb);
            color.rgb = AcesTonemap(color.rgb);
        #endif

        #if UNITY_COLORSPACE_GAMMA
            color = LinearToSRGB(color);
        #endif

        #if COLOR_GRADING_LDR_2D
            color = saturate(color);
            color.rgb = ApplyLut2D(TEXTURE2D_PARAM(_Lut2D, sampler_Lut2D), color.rgb, _Lut2D_Params);
        #endif

        UNITY_BRANCH
        if (_UseFXAA)
        {
            // Put saturated luma in alpha for FXAA - higher quality than "green as luma" and
            // necessary as RGB values will potentially still be HDR for the FXAA pass
            color.a = Luminance(saturate(color));
        }

        return color;
    }
    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertUVTransform
            #pragma fragment FragUber
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragUber
            ENDHLSL
        }
    }
}
