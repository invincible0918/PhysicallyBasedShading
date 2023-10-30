float3 DirectLightDiffuse(float3 albedo, float nl)
{
	float kd = 1;
	float3 diffColor = kd * albedo * _DirectionalLightColor * nl;

	return diffColor;
}

float3 DirectLightSpecular()
{
	return 0;
}

float3 IndirectLightDiffuse()
{
	return 0;
}

float3 IndirectLightSpecular()
{
	return 0;
}