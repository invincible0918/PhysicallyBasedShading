#include "StandardStruct.cginc"
#include "PBS.cginc"

float3x3 TangentToWorld(float3 normal, float3 tangent, float tangentSign)
{
    // For odd-negative scale transforms we need to flip the sign
    // float4 unity_WorldTransformParams; // w is usually 1.0, or -1.0 for odd-negative scale transforms
    float sign = tangentSign/* * unity_WorldTransformParams.w*/;
    float3 binormal = cross(normal, tangent) * sign;
    return float3x3(tangent, binormal, normal);
}

VertexOutputForward vertForward(VertexInput v)
{
    VertexOutputForward o = (VertexOutputForward)0;

    float4 posWorld = mul(_ObjectToWorld, v.vertex);
    o.tangentToWorldAndPackedData[0].w = posWorld.x;
    o.tangentToWorldAndPackedData[1].w = posWorld.y;
    o.tangentToWorldAndPackedData[2].w = posWorld.z;
    o.pos = mul(_ViewToProjection, mul(_ObjectToWorld, float4(v.vertex.xyz, 1.0)));
    o.tex = v.uv0;
    o.eyeVec.xyz = normalize(posWorld.xyz - _CameraWorldSpace);
    float3 normalWorld = mul((float3x3)_ObjectToWorld, v.normal);
    normalWorld = normalize(normalWorld);

    float4 tangentWorld = float4(mul((float3x3)_ObjectToWorld, v.tangent.xyz), v.tangent.w);
    float3x3 tangentToWorld = TangentToWorld(normalWorld, tangentWorld.xyz, tangentWorld.w);
    o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
    o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
    o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];

    return o;
}


float3 BRDF(float3 albedo,
    float3 normal,
    float metallic,
    float perceptualRoughness,
    float3 viewDir,
    float3 lightDir)
{
    float roughness = perceptualRoughness * perceptualRoughness;
    roughness = max(roughness, 0.002);
    float3 h = normalize(lightDir + viewDir);

    float nv = max(saturate(dot(normal, viewDir)), Epsilon);

    float nl = max(saturate(dot(normal, lightDir)), Epsilon);
    float nh = max(saturate(dot(normal, h)), Epsilon);

    float lv = max(saturate(dot(lightDir, viewDir)), Epsilon);
    float lh = max(saturate(dot(lightDir, h)), Epsilon);

    float vh = max(saturate(dot(viewDir, h)), Epsilon);

    float3 f0 = lerp(LinearColorSpaceDielectricSpec.rgb, albedo, metallic);
    float3 fLast = FresnelSchlickRoughness(max(nv, 0.0), f0, roughness);
    float3 f;

    float3 directLightDiffuse = DirectLightDiffuse(albedo, perceptualRoughness, nv, nl, lh);
    float3 directLightSpecular = DirectLightSpecular(roughness, nv, nl, nh, vh, f0, /*out float3*/ f);

    float kd = (1 - f) * (1 - metallic);
	float ks = f;

    float3 indirectLightDiffuse = IndirectLightDiffuse(albedo, normal, metallic, fLast);
    float3 indirectLightSpecular = IndirectLightSpecular(normal, viewDir, perceptualRoughness, roughness, nv, fLast);

    float3 directLight = (kd * directLightDiffuse + ks * directLightSpecular) * _DirectionalLightColor * nl;
    float3 indirectLight = indirectLightDiffuse + indirectLightSpecular;
    float3 brdf = directLight + indirectLight;
    brdf = indirectLightDiffuse;

    return brdf;
}

float3 GetNormal(float2 uv, float4 tangentToWorld[3])
{
    float3 tangent = tangentToWorld[0].xyz;
    float3 binormal = tangentToWorld[1].xyz;
    float3 normal = tangentToWorld[2].xyz;
    
    float3 normalTangent;
    float3 normalColor = tex2D(_NormalTex, uv).xyz;
    normalTangent = normalColor * 2 - 1;
    //normalTangent.z = sqrt(1.0 - saturate(dot(normalTangent.xy, normalTangent.xy)));
    
    float3 normalWorld = tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z;
    
    return normalize(normalWorld);
}

float4 fragForward(VertexOutputForward i) : SV_Target
{
    float3 albedo = tex2D(_MainTex, i.tex).rgb;
    float3 normalWorld = GetNormal(i.tex, i.tangentToWorldAndPackedData);
    float metallic = tex2D(_MetallicTex, i.tex).r;
    float perceptualRoughness = tex2D(_RoughnessTex, i.tex).r;
    //float perceptualRoughness = _RoughnessScale;
    float3 eyeVec = normalize(i.eyeVec);

    float4 finalColor = 0;
    finalColor.rgb = BRDF(albedo, normalWorld, metallic, perceptualRoughness, -eyeVec, -_DirectionalLightWorldSpace);
    finalColor.a = 1;

    return finalColor;
    //FRAGMENT_SETUP(s)

    //UNITY_SETUP_INSTANCE_ID(i);
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    //UnityLight mainLight = MainLight();
    //UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

    //float occlusion = Occlusion(i.tex.xy);
    //UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

    //float4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
    //c.rgb += Emission(i.tex.xy);

    //UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
    //UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
    //return OutputForward(c, s.alpha);
}

