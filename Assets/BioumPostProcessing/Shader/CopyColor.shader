Shader "Hidden/BioumPost/CopyColor"
{
    SubShader
    {
        Pass
        {
            Name "CopyColor"
            Cull Off ZTest Always ZWrite Off
            
            HLSLPROGRAM
            #pragma vertex VertDefault
			#pragma fragment CopyPassFragment

            #include "ShaderLibrary/StdLib.hlsl"
            #include "ShaderLibrary/Colors.hlsl"

            TEXTURE2D_SAMPLER2D(_CameraColorBuffer, sampler_CameraColorBuffer);

            half4 CopyPassFragment (VaryingsDefault input) : SV_TARGET
            {
                return SAMPLE_TEXTURE2D(_CameraColorBuffer, sampler_CameraColorBuffer, input.texcoord);
            }
            ENDHLSL
        }
    }
}
