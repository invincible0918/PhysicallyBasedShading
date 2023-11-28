// https://learnopengl.com/PBR/Theory

inline half Pow5(half x)
{
	return x * x * x * x * x;
}
//// DirectLightDiffuse Start
float3 LambertDiffuse(float3 albedo)
{
	return albedo / PI;
}

float3 DisneyDiffuse(float3 albedo, half nv, half nl, half lh, half perceptualRoughness)
{
	half fd90 = 0.5 + 2 * lh * lh * perceptualRoughness;
	// Two schlick fresnel term
	half lightScatter = (1 + (fd90 - 1) * Pow5(1 - nl));
	half viewScatter = (1 + (fd90 - 1) * Pow5(1 - nv));

	//return albedo / PI * lightScatter * viewScatter;
	return albedo / PI;
}

float3 DirectLightDiffuse(float3 albedo, float nv, float nl, float lh, float perceptualRoughness)
{
	float kd = 1;
	//float3 diffColor = kd * LambertDiffuse(albedo);
	float3 diffColor = kd * DisneyDiffuse(albedo, nv, nl, lh, perceptualRoughness);

	return diffColor;
}
//// DirectLightDiffuse End

//// DirectLightSpecular Start
float TrowbridgeReitzGGX(float nh, float roughness)
{
	float a2 = roughness * roughness;
	float d = nh * nh * (a2 - 1) + 1;
	return a2 / (PI * d * d + 1e-7f);
}

float GeometrySchlickGGX(float nv, float k)
{
	float nom = nv;
	float denom = nv * (1.0 - k) + k;

	return nom / denom;
}

float GeometrySmith(float nv, float nl, float roughness)
{
	float a2 = roughness * roughness;

	float kDirectLight = pow(a2 + 1, 2) / 8;
	float kIBL = pow(a2, 2) / 8;
	float GLeft = nl / lerp(nl, 1, kDirectLight);
	float GRight = nv / lerp(nv, 1, kDirectLight);
	float G = GLeft * GRight;

	float ggx1 = GeometrySchlickGGX(nv, kDirectLight);
	float ggx2 = GeometrySchlickGGX(nl, kDirectLight);

	return ggx1 * ggx2;
}

float FresnelSchlick(float cosTheta, float3 f0)
{
	//return f0 + (1.0 - f0) * exp2((-5.55473 * cosTheta - 6.98316) * cosTheta);
	// note the clamp here to prevent black spots
	return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 DirectLightSpecular(float roughness, float nv, float nl, float nh, float vh, float3 f0, out float3 F)
{
    float D = TrowbridgeReitzGGX(nh, roughness);
    float G = GeometrySmith(nv, nl, roughness);
	F = FresnelSchlick(vh, f0);
	//F = FresnelSchlick(nh, f0);

	return D * G * F * 0.25 / (nv * nl);
}
//// DirectLightSpecular End

//// IndirectLightDiffuse Start
uniform float4 _SH9[9];

float4 SH9(float3 dir)
{
    float3 d = float3(dir.x,dir.z,dir.y);
    float4 color = 
    _SH9[0] * GetY00(d) + 
    _SH9[1] * GetY1n1(d) + 
    _SH9[2] * GetY10(d) + 
    _SH9[3] * GetY1p1(d) + 
    _SH9[4] * GetY2n2(d) + 
    _SH9[5] * GetY2n1(d) + 
    _SH9[6] * GetY20(d) + 
    _SH9[7] * GetY2p1(d) + 
    _SH9[8] * GetY2p2(d);
    return color;
}

float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
	return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

float3 IndirectLightDiffuse(float3 albedo, float3 normal, float metallic, float3 fLast)
{
	float3 kdLast = (1 - fLast) * (1 - metallic);

	float3 sh9Color = SH9(float4(normal, 1));
#if defined(_HDR)
	float3 color = GammaToLinearSpace(sh9Color);
#else
	float3 color = sh9Color.rgb;
#endif
	float3 ambient = 0.03 * albedo;
	float3 iblDiffuse = (ambient + color) * kdLast * albedo;
	//iblDiffuse = sh9Color;

	return GammaToLinearSpace(sh9Color);
}
//// IndirectLightDiffuse End

//// IndirectLightSpecular Start
float3 IndirectLightSpecular(float3 normal, float3 viewDir, float perceptualRoughness, float roughness, float nv, float3 fLast)
{
	float mipRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
	float mip = mipRoughness * SpecCubeLodSteps;
	float3 reflectVec = reflect(-viewDir, normal);

	//float4 rgbm = _Cubemap.SampleLevel(Sampler_PointClamp, reflectVec, 0);
	float4 rgbm = texCUBElod(_CubeTex, float4(reflectVec, mip));
	//float4 color = pow(rgbm.rgba, 2.2);
	float4 color = rgbm.rgba;
	float3 iblSpecular = color.rgb;

	float2 uv = float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness));
	float2 envBDRF = tex2D(_BRDFTex, uv).rg;

	float3 iblSpecularResult = iblSpecular * (fLast * envBDRF.r + envBDRF.g);
	return iblSpecularResult;
//	float4 rgbm = texCUBE(_Cubemap, float4(reflectVec, 0));
//	//rgbm.rgb = DecodeHDR(rgbm, _Cubemap_HDR);
//
//	half alpha = _Cubemap_HDR.w * (rgbm.a - 1.0) + 1.0;
//#   if defined(UNITY_USE_NATIVE_HDR)
//	return _Cubemap_HDR.x * rgbm.rgb; // Multiplier for future HDRI relative to absolute conversion.
//#   else
//	return (_Cubemap_HDR.x * pow(alpha, _Cubemap_HDR.y)) * rgbm.rgb;
//#   endif
//	return rgbm.rgb;
}
//// IndirectLightSpecular End