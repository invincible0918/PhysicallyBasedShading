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
    float oneMinusReflectivity, 
    float roughness,
    float3 normal, 
    float3 viewDir,
    float3 lightDir)
{
    float perceptualRoughness = roughness;
    float3 h = normalize(lightDir + viewDir);

    float nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact

    float nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, h));

    float lv = saturate(dot(lightDir, viewDir));
    float lh = saturate(dot(lightDir, h));

    float3 brdf = DirectLightDiffuse(albedo, nl) + DirectLightSpecular() + IndirectLightDiffuse() + IndirectLightSpecular();

    return brdf;

//    // Diffuse term
//    float diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
//
//    // Specular term
//    // HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
//    // BUT 1) that will make shader look significantly darker than Legacy ones
//    // and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
//    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
//#if UNITY_BRDF_GGX
//    // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
//    roughness = max(roughness, 0.002);
//    float V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
//    float D = GGXTerm(nh, roughness);
//#else
//    // Legacy
//    float V = SmithBeckmannVisibilityTerm(nl, nv, roughness);
//    float D = NDFBlinnPhongNormalizedTerm(nh, PerceptualRoughnessToSpecPower(perceptualRoughness));
//#endif
//
//    float specularTerm = V * D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
//
//#   ifdef UNITY_COLORSPACE_GAMMA
//    specularTerm = sqrt(max(1e-4h, specularTerm));
//#   endif
//
//    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
//    specularTerm = max(0, specularTerm * nl);
//#if defined(_SPECULARHIGHLIGHTS_OFF)
//    specularTerm = 0.0;
//#endif
//
//    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
//    float surfaceReduction;
//#   ifdef UNITY_COLORSPACE_GAMMA
//    surfaceReduction = 1.0 - 0.28 * roughness * perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
//#   else
//    surfaceReduction = 1.0 / (roughness * roughness + 1.0);           // fade \in [0.5;1]
//#   endif
//
//    // To provide true Lambert lighting, we need to be able to kill specular completely.
//    specularTerm *= any(specColor) ? 1.0 : 0.0;
//
//    float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
//    float3 color = diffColor * (gi.diffuse + light.color * diffuseTerm)
//        + specularTerm * light.color * FresnelTerm(specColor, lh)
//        + surfaceReduction * gi.specular * FresnelLerp(specColor, grazingTerm, nv);
//
//    return float4(color, 1);
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
    float roughness = tex2D(_RoughnessTex, i.tex).r;

    float3 specColor = lerp(LinearColorSpaceDielectricSpec.rgb, albedo, metallic);
    float oneMinusReflectivity = LinearColorSpaceDielectricSpec.a - metallic * LinearColorSpaceDielectricSpec.a;
    float3 diffColor = albedo * oneMinusReflectivity;
    float3 normalWorld = GetNormal(i.tex, i.tangentToWorldAndPackedData);
    float3 eyeVec = normalize(i.eyeVec);
    float3 posWorld = float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);

    float4 finalColor = 0;
    finalColor.rgb = BRDF(albedo, specColor, oneMinusReflectivity, roughness, normalWorld, -eyeVec, -_DirectionalLightWorldSpace);
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

