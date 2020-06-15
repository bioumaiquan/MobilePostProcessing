Shader "Maple/Water" 
{
	Properties 
	{
		_DeepColor ("水颜色", COLOR)  = (0.18, 0.32, 0.44, 1)
		_NormalScale("法线强度", Range(0,4)) = 1
		_FresnelPower ("菲涅尔强度", Range(0, 4))  = 2
		_Transparent ("透明度", Range(0, 1))  = 0.8
		_WaveSpeed ("水流速度", Vector) = (1,1,1,1)
		_SpecPower ("高光范围", Range(0.1,10)) = 5
		_SpecIntensity ("高光强度", range(0,5)) = 1
		
		_DistortIntensity ("反射扭曲强度", Range(0,10)) = 1
		_ReflIntensity ("反射亮度", Range(0,2)) = 1

		_FogFactor ("雾强度", range(0,2)) = 1

		
		[Space]
		_NormalTex ("法线贴图 ", 2D) = "bump" {}
		[NoScaleOffset]_ReflectionTex ("反射贴图 ", 2D) = "white" {}

		[Toggle(SOFT_EDGE)] _EnableDepthTex ("柔边", float) = 0
		_SoftRange ("柔边范围", range(0.01, 5)) = 1
		_ShallowRange ("浅水区范围", range(0,5)) = 2
		_ShallowColor ("浅水区颜色", COLOR)  = (0.41, 0.93, 0.86, 1)
	}

	SubShader 
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		Cull Back ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		
		Pass 
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature ENABLE_REFLECTIVE
			#pragma shader_feature __ BIOU_FOG_SIMPLE
			#pragma shader_feature __ BIOU_FOG_HEIGHT
			#pragma shader_feature __ BIOU_FOG_SCATTERING
			#pragma shader_feature SOFT_EDGE
			#pragma multi_compile __ CAMERA_DEPTH_TEXTURE
			#include "Biou_Maple_Core.hlsl"		
			
			half4 _WaveSpeed;
			half4 _DeepColor;
			sampler2D _NormalTex; half4 _NormalTex_ST;
			sampler2D _ReflectionTex; 
			half _NormalScale;
			half _FresnelPower;
			half _Transparent;
			
			#if ENABLE_REFLECTIVE
				sampler2D _RealReflectionTex; 
				half _RealDistortIntensity;
			#endif

			#if SOFT_EDGE && CAMERA_DEPTH_TEXTURE
				sampler2D_float _CameraDepthTex;
				half _SoftRange, _ShallowRange;
				half4 _ShallowColor;
			#endif
			
			half _SpecIntensity;
			half _SpecPower;
			
			half _ReflIntensity;
			half _DistortIntensity;
			half4 _FogDistance;
			
			struct appdata 
			{
				half4 vertex : POSITION;
				half3 normal : NORMAL;
				half2 uv : TEXCOORD0;
			};

			struct v2f 
			{
				half4 pos : SV_POSITION;
				half4 uv : TEXCOORD0;
				half3 viewDir : TEXCOORD1;
				half3 normal : NORMAL;
				half4 color : COLOR;
				float4 projPos : TEXCOORD2;
				half4 worldPosAndFog : TEXCOORD3;
			};
			
			v2f vert(appdata v)
			{
				v2f o = (v2f)0;

				half4 positionWS = mul(UNITY_MATRIX_M, v.vertex);
				half4 positionVS = mul(UNITY_MATRIX_V, positionWS);
				half4 positionCS = mul(UNITY_MATRIX_P, positionVS);
				
				o.pos = positionCS;
				o.projPos = ComputeScreenPos (o.pos);
				o.projPos.z = -positionVS.z;
				
				half2 nuv = TRANSFORM_TEX(v.uv, _NormalTex);
				half4 waveScale = half4(nuv, nuv.x * 0.4, nuv.y * 0.45);
				half4 waveOffset = _WaveSpeed * _Time.y * 0.05;
				o.uv = waveScale + frac(waveOffset);
				
				o.worldPosAndFog.xyz = positionWS.xyz;
				o.worldPosAndFog.w = ComputeFogFactor(positionWS.xyz);
				
				o.viewDir = normalize(_WorldSpaceCameraPos.xyz - positionWS.xyz);

				return o;
			}

			half4 frag( v2f i ) : SV_Target
			{
				half3 bump1 = UnpackNormal(tex2D( _NormalTex, i.uv.xy )).rgb;
				half3 bump2 = UnpackNormal(tex2D( _NormalTex, i.uv.zw )).rgb;
				half3 normal = bump1 + bump2;
				normal.xy *= -_NormalScale;
				normal = normalize(normal.xzy);
				
				half3 viewDir = i.viewDir;
				half fresnelFac = 1 - dot(viewDir, normal);
				fresnelFac = saturate(pow(fresnelFac, _FresnelPower) + 0.02);
				
				//reflect
				half4 reflUV = i.projPos;
				half3 reflection;
				half4 color;
				
				#if !ENABLE_REFLECTIVE
					reflUV.xy += normal.xz * _DistortIntensity;
					reflection = tex2Dproj(_ReflectionTex, reflUV).rgb;
				#else
					reflUV.xy += normal.xz * _RealDistortIntensity;
					reflection = tex2Dproj(_RealReflectionTex, UNITY_PROJ_COORD(reflUV)).rgb;
				#endif	
				reflection *= _ReflIntensity;

				color.rgb = lerp(_DeepColor, reflection, fresnelFac);
				color.a = max(_Transparent, fresnelFac);

				//specular
				half3 lightDir = g_MainLightDir.xyz;
				half3 halfDir = normalize(lightDir + viewDir);
				half spec = pow(saturate(dot(halfDir,normal)), _SpecPower * 256) * _SpecIntensity;
				half3 specColor = spec * g_MainLightColor.rgb;
				color.rgb += specColor;
				//color.a = max(color.a, saturate(spec));

				//soft
				#if SOFT_EDGE && CAMERA_DEPTH_TEXTURE
					half depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTex, UNITY_PROJ_COORD(i.projPos));
					half sceneZ = LinearEyeDepth (depth);
					half thisZ = i.projPos.z;
					half edge = sceneZ - thisZ;

					half fade = saturate(rcp(_SoftRange) * edge);
					half shallow = saturate(rcp(_ShallowRange) * edge);

					color.rgb = lerp(_ShallowColor.rgb, color.rgb, shallow); 
					color.a *= fade;
				#endif

				//fog
				color.rgb = ComputeFogColorWithSun(color.rgb, i.worldPosAndFog.w, lightDir, viewDir);
				
				return half4(color);
			}
			ENDCG
		}
	}
}
