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

	return albedo / PI * lightScatter * viewScatter;
}

float3 DirectLightDiffuse(float3 albedo, float nv, float nl, float lh, float perceptualRoughness)
{
	float kd = 1;
	//float3 diffColor = kd * LambertDiffuse(albedo);
	float3 diffColor = kd * DisneyDiffuse(albedo, nv, nl, lh, perceptualRoughness);

	return diffColor/* * PI*/;
}
//// DirectLightDiffuse End

//// DirectLightSpecular Start
float TrowbridgeReitzGGX(float nh, float roughness)
{
	float a2 = roughness * roughness;
	float d = nh * nh * (a2 - 1) + 1;
	return a2 / (PI * d * d + 1e-7f);
}

float SmithJointApprox(float nv, float nl, float roughness)
{
	float a2 = roughness * roughness;

	float kDirectLight = pow(a2 + 1, 2) / 8;
	//float kIBL = pow(a2, 2) / 8;
	float GLeft = nl / lerp(nl, 1, kDirectLight);
	float GRight = nv / lerp(nv, 1, kDirectLight);
	float G = GLeft * GRight;
	return G;
}

half3 Fresnel(float3 albedo, float metallic, float vh)
{
	float3 F0 = lerp(LinearColorSpaceDielectricSpec.rgb, albedo, metallic);
	float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);

	return vh;
}

float3 DirectLightSpecular(float3 albedo, float metallic, float roughness, float nv, float nl, float nh, float vh)
{
	// https://github.com/EpicGames/UnrealEngine/blob/5ccd1d8b91c944d275d04395a037636837de2c56/Engine/Shaders/Private/BRDF.ush
    float D = TrowbridgeReitzGGX(nh, roughness);
    float G = SmithJointApprox(nv, nl, roughness);
    float3 F = Fresnel(albedo, metallic, vh);

	return D * G * F / 4 * nv * nl;
}
//// DirectLightSpecular End

//// IndirectLightDiffuse Start
uniform float4 _SH9[9];

half4 SH9(float3 dir)
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
float3 IndirectLightDiffuse(float3 normal)
{
	half3 sh9Color = SH9(float4(normal, 1));

	return sh9Color;
}
//// IndirectLightDiffuse End

float3 IndirectLightSpecular()
{
	return 0;
}