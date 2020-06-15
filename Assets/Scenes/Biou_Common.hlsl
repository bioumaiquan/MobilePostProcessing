#ifndef __BIOU_COMMON__
	#define __BIOU_COMMON__

	#include "UnityCG.cginc"
	#include "UnityShaderVariables.cginc"
	#include "UnityPBSLighting.cginc"
	#include "UnityStandardUtils.cginc"
	#include "UnityStandardBRDF.cginc"
	#include "AutoLight.cginc"

	half4 _Color;
	sampler2D _MainTex; half4 _MainTex_ST;

	#define Biou_TRANSFER_FOG(fogCoord, outpos) UNITY_CALC_FOG_FACTOR((outpos).z); fogCoord = unityFogFactor
	#define Biou_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_FOG_LERP_COLOR(col,fogCol,(coord).x)

	half3 g_MainLightDir;
	half4 g_MainLightColor;
	half g_BakedLightIntensity;
	half _FogFactor;
	half4 g_FogColor;
	half4 g_FogSunColor;
	// x = start distance
	// y = distance falloff
	// z = start height 
	// w = height falloff
	half4 g_FogParam;
	// x = Direction x
	// z = Direction z
	// y = speed
	// w = wave Scale
	half4 g_WindParam;
	float3 g_PlayerPos;
	float3 g_MainPlayerPos;

	struct FragmentData
	{
		half4 albedoAndAO;
		half3 worldNormal;
		half3 worldTangent;
		half3 worldView;
		half3 worldPos;
		half2 metalAndGloss;
		half4 shOrLightmapUV;
	};

	FragmentData InitFragmentData()
	{
		FragmentData o = (FragmentData)0;

		return o;
	}

	struct IndirectSpecularData
	{
		half4 cube_HDR;
		half roughness;
		half3 worldRefl;
	};

	half SRGBToLinear(half c)
	{
		return c * c;
	}

	half3 SRGBToLinear(half3 c)
	{
		return c * c;
	}

	half4 SRGBToLinear(half4 c)
	{
		return half4(SRGBToLinear(c.rgb), c.a);
	}

	half LinearToSRGB(half c)
	{
		return sqrt(c);
	}

	half3 LinearToSRGB(half3 c)
	{
		return sqrt(c);
	}

	half4 LinearToSRGB(half4 c)
	{
		return half4(LinearToSRGB(c.rgb), c.a);
	}

	//distance exp fog and height exp fog
	//http://www.iquilezles.org/www/articles/fog/fog.htm
	half ComputeFogFactor(half3 worldPos) 
	{
		float fogFactor = 0;
		#if defined(BIOU_FOG_SIMPLE) || defined(BIOU_FOG_HEIGHT)
			#ifdef BIOU_FOG_SIMPLE
				float dis = distance(_WorldSpaceCameraPos.xyz, worldPos);
				float disFogFactor = max(0, 1 - exp(-(dis - g_FogParam.x) * g_FogParam.y));
				fogFactor = disFogFactor;
			#endif

			#ifdef BIOU_FOG_HEIGHT
				float heightFogFactor = max(0, 1 - exp((worldPos.y - g_FogParam.z) * g_FogParam.w));
				fogFactor = heightFogFactor;
			#endif

			#if defined(BIOU_FOG_SIMPLE) && defined(BIOU_FOG_HEIGHT)
				fogFactor = lerp(heightFogFactor * disFogFactor, saturate(disFogFactor + heightFogFactor), disFogFactor);
			#endif

			fogFactor += _FogFactor - 1;
		#endif

		return saturate(fogFactor);
	}
	half3 ComputeFogColor(half3 fogColor, half3 color, half fogCoord)
	{
		#if defined(BIOU_FOG_SIMPLE) || defined(BIOU_FOG_HEIGHT) || defined(BIOU_FOG_SCATTERING)
			return lerp(color, fogColor, fogCoord);
		#endif
		return color;
	}
	half3 ComputeFogColor(half3 color, half fogCoord)
	{
		return ComputeFogColor(g_FogColor, color, fogCoord);
	}
	half3 ComputeFogColorWithSun(half3 fogColor, half3 color, half fogCoord, half3 lightDir, half3 viewDir)
	{
		#ifdef BIOU_FOG_SCATTERING
			half sun = max(0, dot(-lightDir, viewDir));
			half sun2 = pow(sun , 10);
			sun = sun * 0.5 + sun2;
			fogColor = lerp(fogColor, fogColor + g_FogSunColor.rgb * 2, sun);
		#endif
		return ComputeFogColor(fogColor, color, fogCoord);
	}
	half3 ComputeFogColorWithSun(half3 color, half fogCoord, half3 lightDir, half3 viewDir)
	{
		return ComputeFogColorWithSun(g_FogColor, color, fogCoord, lightDir, viewDir);
	}
	//fog end


	inline half3 UnpackNormalAndMetalGloss(sampler2D tex, half2 uv, out half2 metalAndGloss)
	{
		half4 sampleTex = tex2D(tex, uv);
		metalAndGloss = sampleTex.zw;
		half3 normalTex;
		normalTex.xy = sampleTex.xy * 2 - 1;
		normalTex.z = sqrt(1 - saturate(dot(normalTex.xy, normalTex.xy)));
		return normalTex;
	}

	inline half3 calculateWorldNormal(half3 normal, half4 tangent, half3 normalTex, half normalScale)
	{
		normal         = normalize(normal);
		tangent        = normalize(tangent);
		half3 binormal = cross(normal,tangent.xyz) * tangent.w;
		half3x3 TBN = half3x3(tangent.xyz, binormal, normal);
		
		normalTex.xy *= normalScale;
		half3 normalL = normalTex.x * TBN[0] +
		normalTex.y * TBN[1] +
		normalTex.z * TBN[2];
		half3 normalW = UnityObjectToWorldNormal(normalL);
		return normalize(normalW);
	}
	inline half3 Biou_ShadeSH9 (half4 normal)
	{
		// Linear + constant polynomial terms
		half3 res = SHEvalLinearL0L1 (normal);

		// Quadratic polynomials
		res += SHEvalLinearL2 (normal);

		return res;
	}
	inline half3 Biou_DecodeLightmap (half4 data)
	{
		half3 color = 1;

		#if defined(UNITY_LIGHTMAP_DLDR_ENCODING) || defined(UNTIY_LIGHTMAP_RGBM_ENCODING)
			#ifdef UNITY_COLORSPACE_GAMMA
				color = SRGBToLinear(data.rgb * 2);
			#else
				color = data.rgb * 4.59; // 2^2.2
			#endif
		#else
			color = data.rgb;
		#endif

		return color;
		// #ifdef UNITY_COLORSPACE_GAMMA
		// 	return SRGBToLinear(DecodeLightmap(data));
		// #else
		// 	return DecodeLightmap(data);
		// #endif
	}
	inline half3 Biou_DecodeHDR(half4 data, half4 data_hdr)
	{
		return data.rgb * data_hdr.x;
	}


	//gi start
	inline UnityGI Biou_GIBase(UnityLight light, FragmentData s)
	{
		UnityGI o_gi;
		ResetUnityGI(o_gi);

		#if LIGHTMAP_ON
			// Baked lightmaps
			half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, s.shOrLightmapUV.xy);
			half3 bakedColor = Biou_DecodeLightmap(bakedColorTex);

			#if DIRLIGHTMAP_COMBINED
				half4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, s.shOrLightmapUV.xy);
				o_gi.indirect.diffuse = DecodeDirectionalLightmap (bakedColor, bakedDirTex, s.worldNormal);
				o_gi.light.dir = normalize(bakedDirTex * 2 - 1);
				o_gi.light.color = bakedColor * g_BakedLightIntensity;
			#else // not directional lightmap
				o_gi.indirect.diffuse = bakedColor;
				o_gi.light.color = bakedColor * g_BakedLightIntensity;
				o_gi.light.dir = g_MainLightDir;
			#endif
		#else
			o_gi.light = light;
			o_gi.indirect.diffuse = s.shOrLightmapUV.rgb;
		#endif

		return o_gi;
	}
	inline half3 Biou_GIIndirectSpecular(IndirectSpecularData data)
	{
		data.roughness *= (1.7 - 0.7 * data.roughness);
		half mip = perceptualRoughnessToMipmapLevel(data.roughness);
		half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, data.worldRefl, mip);

		half3 specular = Biou_DecodeHDR(rgbm, data.cube_HDR);
		#ifdef UNITY_COLORSPACE_GAMMA
			specular = SRGBToLinear(specular);
		#endif
		return specular;
	}
	inline UnityGI Biou_GI(UnityLight light, FragmentData s, IndirectSpecularData data)
	{
		UnityGI gi = Biou_GIBase(light, s);
		gi.indirect.specular = Biou_GIIndirectSpecular(data);
		return gi;
	}
	inline UnityGI Biou_SetupGI (FragmentData s, UnityLight light)
	{
		IndirectSpecularData data;
		data.cube_HDR = unity_SpecCube0_HDR;
		data.worldRefl = reflect(-s.worldView, s.worldNormal);
		data.roughness = 1 - s.metalAndGloss.y;

		UnityGI gi;
		gi = Biou_GI(light, s, data);

		return gi;
	}
	//gi end



	half2 GrassWindAnimation(half3 vertexColor, half3 worldPos)
	{
		float2 val = float2(_Time.y * g_WindParam.y + worldPos.xz * g_WindParam.w);
		val = val % 6.2831853;
		half2 waveXZ = sin(val) * 0.5 + 0.5;
		waveXZ *= g_WindParam.xz;
		return waveXZ * vertexColor.r;
	}
	// half3 CharacterCollision(half3 worldPos)
	// {
		// 	g_CharacterPos.y += 1.5;
		// 	half3 dir = normalize(worldPos.xyz - (g_CharacterPos.xyz + half3(0,1.5,0)));
		// 	half dist = distance(g_CharacterPos.xyz, worldPos.xyz);
		// 	half strength = lerp(0.8, 0, clamp(dist, 0, 1.5) / 1.5);
		// 	return dir.xyz * strength * half3(1,1.5,1);
	// }


	// shadow
	half GetShadow(sampler2D shadowMap, float4 shadowCoord)
	{
		float2 shadowUV = shadowCoord.xy / shadowCoord.w;
		shadowUV = shadowUV * 0.5 + 0.5; //(-1, 1)-->(0, 1)

		float depth = shadowCoord.z / shadowCoord.w;
		#if defined (SHADER_TARGET_GLSL)
			depth = depth * 0.5 + 0.5; //(-1, 1)-->(0, 1)
		#elif defined (UNITY_REVERSED_Z)
			depth = 1 - depth;       //(1, 0)-->(0, 1)
		#endif

		// sample depth texture
		float4 col = tex2D(shadowMap, shadowUV);
		float sampleDepth = DecodeFloatRGBA(col);
		float shadow = sampleDepth < depth ? 0 : 1;

		return shadow;

	}


	float InterleavedGradientNoise(float2 pixCoord, int frameCount)
	{
		const float3 magic = float3(0.06711056f, 0.00583715f, 52.9829189f);
		float2 frameMagicScale = float2(2.083f, 4.867f);
		pixCoord += frameCount * frameMagicScale;
		return frac(magic.z * frac(dot(pixCoord, magic.xy)));
	}


#endif  // __BIOU_COMMON__