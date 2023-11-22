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
    float3 specColor, 
    float perceptualRoughness,
    float metallic,
    float3 normal, 
    float3 viewDir,
    float3 lightDir)
{
    float roughness = perceptualRoughness * perceptualRoughness;
    roughness = max(roughness, 0.002);
    float3 h = normalize(lightDir + viewDir);

    float nv = saturate(dot(normal, viewDir)); 

    float nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, h));

    float lv = saturate(dot(lightDir, viewDir));
    float lh = saturate(dot(lightDir, h));

    float vh = saturate(dot(viewDir, h));

    float3 directLightDiffuse = DirectLightDiffuse(albedo, perceptualRoughness, nv, nl, lh);
    float3 directLightSpecular = 0;// DirectLightSpecular(albedo, metallic, roughness, nv, nl, nh, vh);
    float3 indirectLightDiffuse = IndirectLightDiffuse(albedo, normal, roughness, metallic, nv, specColor);
    float3 indirectLightSpecular = IndirectLightSpecular(normal, viewDir, perceptualRoughness, roughness, nv);

    float3 directLight = (directLightDiffuse + directLightSpecular) * _DirectionalLightColor * nl;
    float3 indirectLight = indirectLightDiffuse + indirectLightSpecular;
    float3 brdf = directLight + indirectLight;
    brdf = indirectLightSpecular;

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
    float metallic = tex2D(_MetallicTex, i.tex).r;
    float perceptualRoughness = tex2D(_RoughnessTex, i.tex).r/* * _RoughnessScale*/;
    float3 specColor = lerp(LinearColorSpaceDielectricSpec.rgb, albedo, metallic);
    float oneMinusReflectivity = LinearColorSpaceDielectricSpec.a - metallic * LinearColorSpaceDielectricSpec.a;
    float3 diffColor = albedo * oneMinusReflectivity;
    float3 normalWorld = GetNormal(i.tex, i.tangentToWorldAndPackedData);
    float3 eyeVec = normalize(i.eyeVec);
    float3 posWorld = float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);

    float4 finalColor = 0;
    finalColor.rgb = BRDF(albedo, specColor, perceptualRoughness, metallic, normalWorld, -eyeVec, -_DirectionalLightWorldSpace);
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

