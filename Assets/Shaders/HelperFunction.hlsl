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

void UniformSampling(float2 rand, out float theta, out float phi)
{
    theta = acos(1 - 2 * rand.x);
    phi = 2.0 * PI * rand.y;
}

float3 LocalSpaceDirection(float theta, float phi)
{
    float sTheta, cTheta, sPhi, cPhi;
    sincos(theta, sTheta, cTheta);
    sincos(phi, sPhi, cPhi);

    //float3 localSpaceDir = float3(cPhi * sTheta, sPhi * sTheta, cTheta);
    float3 localSpaceDir = float3(sTheta * cPhi, cTheta, sTheta * sPhi);

    //float3 result;
    //result.y = c_theta;
    //result.x = s_theta * c_phi;
    //result.z = s_theta * s_phi;
    return localSpaceDir;
}

inline half3 GammaToLinearSpace(half3 sRGB)
{
    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

    // Precise version, useful for debugging.
    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
}

inline half3 LinearToGammaSpace(half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);

    // Exact version, useful for debugging.
    //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
}


#endif