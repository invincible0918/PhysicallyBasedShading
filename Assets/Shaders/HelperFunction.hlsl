#ifndef _HELPER_FUNCTION_
#define _HELPER_FUNCTION_

float2 _pixel;
float seed;

uint rngstate;

uint RandInt()
{
    rngstate ^= rngstate << 13;
    rngstate ^= rngstate >> 17;
    rngstate ^= rngstate << 5;
    return rngstate;
}

float RandFloat()
{
    return frac(float(RandInt()) / float(1 << 32 - 5));
}

void SetSeed()
{
    rngstate = _pixel.x * _pixel.y;
    RandInt(); RandInt(); RandInt(); // Shift some bits around
}

// range: 0~1
float Rand()
{
    float result = sin(seed / 100.0f * dot(_pixel, float2(12.9898f, 78.233f))) * 43758.5453f;
    seed += 1.0f;
    rngstate += result;

    return RandFloat();
}

void UniformSampling(out float theta, out float phi)
{
    theta = acos(1 - Rand());
    phi = 2.0 * PI * Rand();
}

float3 LocalSpaceDirection(float theta, float phi)
{
    float sTheta, cTheta, sPhi, cPhi;
    sincos(theta, sTheta, cTheta);
    sincos(phi, sPhi, cPhi);

    float3 localSpaceDir = float3(cPhi * sTheta, sPhi * sTheta, cTheta);

    //float3 result;
    //result.y = c_theta;
    //result.x = s_theta * c_phi;
    //result.z = s_theta * s_phi;
    return localSpaceDir;
}

#endif