Shader "Hidden/BioumPost/FXAA"
{
    SubShader
    {
        Pass
        {
            Cull Off ZTest Always ZWrite Off
            
            HLSLPROGRAM

            #pragma vertex VertUVTransform
			#pragma fragment FragFXAA

            #include "ShaderLibrary/StdLib.hlsl"
            #include "ShaderLibrary/Colors.hlsl"
            #include "ShaderLibrary/Sampling.hlsl"

            #define FXAA_PC 1
            #define FXAA_GREEN_AS_LUMA 0

            #define FXAA_QUALITY__PRESET 12
            #define FXAA_QUALITY_SUBPIX 1.0
            #define FXAA_QUALITY_EDGE_THRESHOLD 0.166
            #define FXAA_QUALITY_EDGE_THRESHOLD_MIN 0.0625

            #include "ShaderLibrary/FXAA.hlsl"

            TEXTURE2D_SAMPLER2D(_CameraColorTex, sampler_CameraColorTex);
            float4 _CameraColorTex_TexelSize;

            half4 FragFXAA(VaryingsDefault i) : SV_Target
            {
                half4 color = 0.0;

                #if FXAA_HLSL_4 || FXAA_HLSL_5
                    FxaaTex mainTex;
                    mainTex.tex = _CameraColorTex;
                    mainTex.smpl = sampler_CameraColorTex;
                #else
                    FxaaTex mainTex = _CameraColorTex;
                #endif

                color = FxaaPixelShader(
                    i.texcoord,                 // pos
                    0.0,                        // fxaaConsolePosPos (unused)
                    mainTex,                    // tex
                    mainTex,                    // fxaaConsole360TexExpBiasNegOne (unused)
                    mainTex,                    // fxaaConsole360TexExpBiasNegTwo (unused)
                    _CameraColorTex_TexelSize.xy,      // fxaaQualityRcpFrame
                    0.0,                        // fxaaConsoleRcpFrameOpt (unused)
                    0.0,                        // fxaaConsoleRcpFrameOpt2 (unused)
                    0.0,                        // fxaaConsole360RcpFrameOpt2 (unused)
                    FXAA_QUALITY_SUBPIX,
                    FXAA_QUALITY_EDGE_THRESHOLD,
                    FXAA_QUALITY_EDGE_THRESHOLD_MIN,
                    0.0,                        // fxaaConsoleEdgeSharpness (unused)
                    0.0,                        // fxaaConsoleEdgeThreshold (unused)
                    0.0,                        // fxaaConsoleEdgeThresholdMin (unused)
                    0.0                         // fxaaConsole360ConstDir (unused)
                );

                return color;
            }
            ENDHLSL
        }
    }
}
