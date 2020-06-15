Shader "Hidden/BioumPost/CopyDepth"
{
    SubShader
    {
        Pass
        {
            Name "CopyDepth"
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex VertDefault
			#pragma fragment CopyPassFragment

            #include "ShaderLibrary/StdLib.hlsl"
            #include "ShaderLibrary/Colors.hlsl"

            TEXTURE2D_SAMPLER2D(_CameraDepthBuffer, sampler_CameraDepthBuffer);

            float CopyPassFragment(VaryingsDefault input) : SV_TARGET
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthBuffer, sampler_CameraDepthBuffer, input.texcoord);
                return depth;
            }
            ENDHLSL
        }
    }
}
