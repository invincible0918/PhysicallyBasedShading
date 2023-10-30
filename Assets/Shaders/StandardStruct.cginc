
float4x4 _ObjectToWorld;
float4x4 _WorldToObject;
float4x4 _ViewToProjection;
float3 _CameraWorldSpace;
float3 _DirectionalLightWorldSpace;
float3 _DirectionalLightColor;

sampler2D _MainTex;
sampler2D _NormalTex;
sampler2D _MetallicTex;
sampler2D _RoughnessTex;

#define LinearColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

struct VertexInput
{
    float4 vertex   : POSITION;
    half3 normal    : NORMAL;
    float2 uv0      : TEXCOORD0;
    half4 tangent   : TANGENT;
};

struct VertexOutputForward
{
    float4 pos                              : SV_POSITION;
    float2 tex                              : TEXCOORD0;
    float4 eyeVec                           : TEXCOORD1;    // eyeVec.xyz | fogCoord
    float4 tangentToWorldAndPackedData[3]   : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    float3 posWorld                         : TEXCOORD5;
};

