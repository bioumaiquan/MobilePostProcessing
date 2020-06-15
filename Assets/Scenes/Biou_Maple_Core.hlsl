#ifndef __MAPLECORE__
	#define __MAPLECORE__

	#include "Biou_Common.hlsl"

	#define Biou_DielectricSpec half4(0.025, 0.025, 0.025, 0.975) 	//gamma and linear space use the same Dielectric Color because of all other colors will transfer to linear spcae

	half3 Biou_DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
	{
		specColor = lerp (Biou_DielectricSpec.rgb, albedo, metallic);

		half oneMinusDielectricSpec = Biou_DielectricSpec.a;
		oneMinusReflectivity = oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;

		return albedo * oneMinusReflectivity;
	}

	half3 Biou_FresnelLerp(half3 specColor, half grazingTerm, half ndotv)
	{
		ndotv = smoothstep(0.1,0.3, ndotv);
		return lerp(grazingTerm, specColor, ndotv);
	}

	half3 Biou_MapleRim(half nl, half nv, half3 color, half intensity)
	{
		half3 rimColor = 0;
		#if RIM
			half rim = 1 - nv;
			rim *= rim;
			rim = smoothstep(0.5, 0.6, rim);
			rimColor = rim * nl * color * intensity;
		#endif
		return rimColor;
	}
	//rimParam.x=intensity  rimParam.y=width  rimParam.z=backIntensity
	half3 Biou_BackRim(half3 lightDir, half3 normal, half3 viewDir, half3 color, half3 rimParam)
	{
		half3 rimColor = 0;
		#if RIM
			float3 PivotWorldPos = float3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
			half3 backLightDir = lightDir * half3(-1,0,-1);
			half3 backViewDir = normalize(_WorldSpaceCameraPos.xyz - PivotWorldPos) * half3(-1,0,-1);
			backLightDir = normalize(backLightDir + backViewDir);
			half backNL = dot(backLightDir, normal) * 0.5 + 0.5;
			backNL = smoothstep(rimParam.y - 0.1, rimParam.y, backNL);

			half rim = 1 - max(0, dot(normal, viewDir));
			rim = smoothstep(rimParam.y, rimParam.y + 0.1, rim);
			rimColor = rim * backNL * color * rimParam.x;
		#endif
		return rimColor;
	}
	//specParam.x = scale specParam.y = intensity specParam.z = mask
	half3 Biou_ToonSpecular(half ndotl, UnityLight light, half3 viewDir, half3 normal, half3 specParam)
	{
		half3 halfDir = normalize(light.dir + viewDir);
		half spec = dot(normal, halfDir);
		half spec1 = smoothstep(specParam.x, specParam.x + 0.02, spec);
		//spec1 += smoothstep(0.995, 1, spec) * 2;
		half3 color = spec1 * light.color * ndotl * specParam.y * specParam.z;
		return color;
	}
	half3 ShiftTangent(half3 tangent, half3 normal, half shift)
	{
		return tangent + normal * shift;
	}
	half KajiyaKaySpec(half3 tangent, half3 viewDir, half3 lightDir, half glossness)
	{
		half3 halfDir = normalize(lightDir + viewDir);
		half tdoth = dot(tangent, halfDir);
		half sinTH = sqrt(max(0, 1 - tdoth * tdoth));
		half dirAtten = smoothstep(-1, 0, tdoth);

		half roughness = 1 - glossness;
		roughness *= roughness;
		roughness *= roughness;
		half power = 1 / max(0.002, roughness);
		sinTH = pow(sinTH, power);
		sinTH = smoothstep(0.4, 0.7, sinTH);

		return dirAtten * sinTH;
	}
	half3 Biou_ToonHairSpecular(half ndotl, UnityLight light, half3 viewDir, half3 tangent, half3 specParam)
	{
		half spec = KajiyaKaySpec(tangent, viewDir, light.dir, specParam.x) * 2;
		half3 color = spec * light.color * ndotl * specParam.y * specParam.z;
		return color;
	}

	half3 Biou_MapleLighting(FragmentData s, half3 specColor, half oneMinusReflectivity, UnityGI gi, half rimFactor)
	{
		#ifndef BIOU_FORWARDADD // forward base
			half nv = max(0, dot(s.worldNormal, s.worldView));

			// Specular term
			half perceptualRoughness = SmoothnessToPerceptualRoughness (s.metalAndGloss.y);
			half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
			
			half surfaceReduction = (0.6-0.08*perceptualRoughness);
			surfaceReduction = 1.0 - roughness*perceptualRoughness*surfaceReduction;
			half grazingTerm = saturate(s.metalAndGloss.y + (1-oneMinusReflectivity));

			half nl = saturate(dot(s.worldNormal, gi.light.dir));
			//nl = smoothstep(0.2, 0.4, nl);
			#if LIGHTMAP_ON
				//nl = saturate(nl + 0.8);
				//half3 albedo = lerp(s.albedoAndAO.rgb * s.albedoAndAO.rgb, s.albedoAndAO.rgb, nl);
				half3 color = s.albedoAndAO.rgb * gi.indirect.diffuse;
				color += surfaceReduction * gi.indirect.specular * Biou_FresnelLerp(specColor, grazingTerm, nv);
				//color *= nl;
				//color = gi.indirect.diffuse;
			#else
				//half3 albedo = lerp(s.albedoAndAO.rgb * s.albedoAndAO.rgb, s.albedoAndAO.rgb, nl);
				half3 color = (s.albedoAndAO.rgb + 0) * gi.light.color * nl;
				color += gi.indirect.diffuse * s.albedoAndAO.rgb;
				color += surfaceReduction * gi.indirect.specular * FresnelLerpFast (specColor, grazingTerm, nv);
			#endif
			color += Biou_MapleRim(nl, nv, color, rimFactor);
		#else  // forward add
			half nl = saturate(dot(s.worldNormal, gi.light.dir));
			half3 color = s.albedoAndAO.rgb * gi.light.color * nl;
		#endif

		return color;
	}

	half3 Biou_Lighting(FragmentData s, UnityGI gi, half3 emiColor, half rimFactor)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			#ifndef LIGHTMAP_ON
				gi.light.color = SRGBToLinear(gi.light.color);
			#endif
		#endif

		half oneMinusReflectivity;
		half3 specColor;
		s.albedoAndAO.rgb = Biou_DiffuseAndSpecularFromMetallic(s.albedoAndAO.rgb, s.metalAndGloss.x, /*out*/ specColor, /*out*/ oneMinusReflectivity);

		half3 c = Biou_MapleLighting(s, specColor, oneMinusReflectivity, gi, rimFactor);
		c *= s.albedoAndAO.a;
		c += emiColor;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}

	half3 Biou_LambertLighting(FragmentData s, UnityGI gi, half3 emiColor, half rimFactor)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			#ifndef LIGHTMAP_ON
				gi.light.color = SRGBToLinear(gi.light.color);
			#endif
		#endif

		half ndotl = max(0, dot(s.worldNormal, gi.light.dir));
		half ndotv = max(0, dot(s.worldNormal, s.worldView));
		half3 c = s.albedoAndAO.rgb * gi.light.color;
		#ifndef LIGHTMAP_ON
			c *= ndotl;
			c += s.albedoAndAO.rgb * gi.indirect.diffuse;
		#endif

		ndotl = min(1, ndotl + 0.6);
		c += Biou_MapleRim(ndotl, ndotv, c, rimFactor);
		c *= s.albedoAndAO.a;
		c += emiColor;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}
	half3 Biou_LambertLightingAdd(FragmentData s, UnityGI gi)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half ndotl = max(0, dot(s.worldNormal, gi.light.dir));
		half3 c = s.albedoAndAO.rgb * gi.light.color * ndotl;
		c *= s.albedoAndAO.a;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}
	half3 Biou_TerrainLighting(FragmentData s, UnityGI gi)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half3 c = s.albedoAndAO.rgb * gi.light.color;
		half ndotl = max(0, dot(s.worldNormal, gi.light.dir));
		c *= ndotl;
		c += s.albedoAndAO.rgb * gi.indirect.diffuse;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}
	//								rimParam.x=intensity  rimParam.y=width  rimParam.z=backIntensity
	//								diffParam.x=diffSmooth  diffParam.y=darkRange  diffParam.z=darkIntensity
	half3 Biou_CharacterLighting(FragmentData s, UnityGI gi, half3 emiColor, half3 rimParam, half3 diffParam, half3 specParam, half shadow) 
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half ndotl = dot(s.worldNormal, gi.light.dir);
		
		half3 c = s.albedoAndAO.rgb * gi.light.color;

		half diff = smoothstep(-diffParam.y, -diffParam.y + diffParam.x, ndotl) + diffParam.z; 
		diff = min(shadow + diffParam.z, diff);
		diff = min(s.albedoAndAO.a, diff);

		c = lerp(c * c, c, diff);
		c += s.albedoAndAO.rgb * gi.indirect.diffuse;

		c += Biou_BackRim(gi.light.dir, s.worldNormal, s.worldView, c, rimParam);
		#if SPECULAR
			#if HAIR
				c += Biou_ToonHairSpecular(saturate(ndotl), gi.light, s.worldView, s.worldTangent, specParam);
			#else
				c += Biou_ToonSpecular(saturate(ndotl), gi.light, s.worldView, s.worldNormal, specParam);
			#endif
		#endif
		c += emiColor;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}

	half3 Biou_BRDF_PBS_GGX(FragmentData s, half3 specColor, half oneMinusReflectivity, UnityGI gi, half rimFactor)
	{
		fixed3 halfDir = Unity_SafeNormalize(gi.light.dir + s.worldView);
		half nl = saturate(dot(s.worldNormal, gi.light.dir));
		float nh = saturate(dot(s.worldNormal, halfDir));
		half nv = saturate(dot(s.worldNormal, s.worldView));
		float lh = saturate(dot(gi.light.dir, halfDir));

		// Specular term
		half perceptualRoughness = SmoothnessToPerceptualRoughness (s.metalAndGloss.y);
		half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

		// GGX Distribution multiplied by combined approximation of Visibility and Fresnel
		// See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
		// https://community.arm.com/events/1155
		half a = roughness;
		float a2 = a*a;
		float d = nh * nh * (a2 - 1.0f) + 1.00001f;

		float specularTerm = a2 / (max(0.1f, lh*lh) * (roughness + 0.5f) * (d * d) * 4);
		specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
		
		half surfaceReduction = (0.6-0.08*perceptualRoughness);
		surfaceReduction = 1.0 - roughness*perceptualRoughness*surfaceReduction;
		half grazingTerm = saturate(s.metalAndGloss.y + (1-oneMinusReflectivity));

		half3 color = (s.albedoAndAO.rgb + specularTerm * specColor) * gi.light.color * nl;
		color += gi.indirect.diffuse * s.albedoAndAO.rgb;
		color += surfaceReduction * gi.indirect.specular * FresnelLerpFast (specColor, grazingTerm, nv);
		color += Biou_MapleRim(nl, nv, color, rimFactor);

		return color;
	}

	half3 Biou_CharacterLighting(FragmentData s, UnityGI gi, half3 emiColor, half rimFactor)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half oneMinusReflectivity;
		half3 specColor;
		s.albedoAndAO.rgb = Biou_DiffuseAndSpecularFromMetallic(s.albedoAndAO.rgb, s.metalAndGloss.x, /*out*/ specColor, /*out*/ oneMinusReflectivity);

		half3 c = Biou_BRDF_PBS_GGX(s, specColor, oneMinusReflectivity, gi, rimFactor);
		c += emiColor;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}

	half3 Biou_SceneLightingPBR(FragmentData s, UnityGI gi, half3 emiColor, half rimFactor)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half oneMinusReflectivity;
		half3 specColor;
		s.albedoAndAO.rgb = Biou_DiffuseAndSpecularFromMetallic(s.albedoAndAO.rgb, s.metalAndGloss.x, /*out*/ specColor, /*out*/ oneMinusReflectivity);

		half3 c = Biou_BRDF_PBS_GGX(s, specColor, oneMinusReflectivity, gi, rimFactor);
		c += emiColor;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif
		
		return c;
	}


	half3 Biou_PlantsLighting(FragmentData s, UnityGI gi)
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			s.albedoAndAO.rgb = SRGBToLinear(s.albedoAndAO.rgb);
			gi.light.color = SRGBToLinear(gi.light.color);
		#endif

		half nl = max(0, dot(s.worldNormal, gi.light.dir));
		half3 c = s.albedoAndAO.rgb * s.shOrLightmapUV.rgb;//s.albedoAndAO.rgb * gi.light.color * nl + s.albedoAndAO.rgb * s.shOrLightmapUV.rgb;

		#ifdef UNITY_COLORSPACE_GAMMA
			c = LinearToSRGB(c);
		#endif

		return c;
	}



#endif // __MAPLECORE__