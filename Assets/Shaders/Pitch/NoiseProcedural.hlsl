#ifndef _NOISE_PROCEDURAL_
#define _NOISE_PROCEDURAL_

#include "Assets/Shaders/NoiseShader/Common.hlsl"

#define HASHSCALE1 .1031
#define HASHSCALE3 float3(.1031, .1030, .0973)

float2 hash(float2 p) // replace this by something better
{
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
}
float Noise(float2 p)
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

    float2  i = floor(p + (p.x + p.y) * K1);
    float2  a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    float2  o = float2(m, 1.0 - m);
    float2  b = a - o + K2;
    float2  c = a - 1.0 + 2.0 * K2;
    float3  h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3  n = h * h * h * h * float3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, 70.0);
}

float Noise2(float2 uv)
{
    float2x2 m = float2x2(1.6, 1.2, -1.2, 1.6);
    float f = 0.5000 * Noise(uv); uv = mul(m, uv);
    f += 0.2500 * Noise(uv); uv = mul(m, uv);
    f += 0.1250 * Noise(uv); uv = mul(m, uv);
    f += 0.0625 * Noise(uv); uv = mul(m, uv);
    return f;
}

float NoiseAA(float2 uv)
{
    float intensity = 0.0;

    float2 ddxUV = ddx(uv);
    float2 ddyUV = ddy(uv);

    for (uint i = 0; i < AA2; i++)
    {
        float2 offset = ANTI_ALIASING_OFFSETS16[i];
        offset = offset.x * ddxUV + offset.y * ddyUV;

        //intensity += ClassicNoise(uv + offset);
        intensity += Noise(uv + offset);
    }
    intensity /= float(AA2);

    return intensity;
}

float Noise2AA(float2 uv)
{
    float intensity = 0.0;

    float2 ddxUV = ddx(uv);
    float2 ddyUV = ddy(uv);

    for (uint i = 0; i < AA2; i++)
    {
        float2 offset = ANTI_ALIASING_OFFSETS16[i];
        offset = offset.x * ddxUV + offset.y * ddyUV;

        //intensity += ClassicNoise(uv + offset);
        intensity += Noise2(uv + offset);
    }
    intensity /= float(AA2);

    return intensity;
}

#endif
