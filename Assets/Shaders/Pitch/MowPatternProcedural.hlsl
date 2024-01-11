#ifndef _MOW_PATTERN_PROCEDURAL_
#define _MOW_PATTERN_PROCEDURAL_

const static float2 AROUND_AREA = float2(0.035, 0.04);
const static float4 AROUND_AREA_RECT = float4(AROUND_AREA.x, AROUND_AREA.y, 1 - AROUND_AREA.x, 1 - AROUND_AREA.y);
const static float3 MOW_PATTERN_3_GRAY = float3(0.05, 0.15, 0.4);

const static float MOW_PATTERN_3_TILE = 19.5;
const static float MOW_PATTERN_3_OFFSET = 0.7;

float2 MowPattern_3(float2 uv)
{
    float around = step(uv.x, AROUND_AREA_RECT.x) + step(AROUND_AREA_RECT.z, uv.x) + step(uv.y, AROUND_AREA_RECT.y) + step(AROUND_AREA_RECT.w, uv.y);
    around = step(0.5, around);

    float pattern = smoothstep(0.45, 0.55, sin(uv.y * PI * MOW_PATTERN_3_TILE + MOW_PATTERN_3_OFFSET) * 0.5 + 0.5);
    //pattern = step(0.5, pattern);
    pattern = lerp(MOW_PATTERN_3_GRAY.x, MOW_PATTERN_3_GRAY.z, pattern);

    // noise
    float noise0 = Noise(uv * float2(150, 150));
    float2 noiseXY = float2(Noise(uv * float2(150, 1)), Noise(uv * float2(1, 150)));
    noise0 = lerp(0.4, 0.8, noise0);
    noiseXY = lerp(0.6, 0.8, noiseXY) + noise0;

    float2 mow = float2(lerp(MOW_PATTERN_3_GRAY.y, MOW_PATTERN_3_GRAY.z, 1 - around), lerp(MOW_PATTERN_3_GRAY.y, pattern, 1 - around));

    return mow * noiseXY;
}

float2 MowPattern_3AA(float2 uv)
{
    float2 intensity = 0.0;

    float2 ddxUV = ddx(uv);
    float2 ddyUV = ddy(uv);

    for (uint i = 0; i < AA2; i++)
    {
        //float2 offset = ANTI_ALIASING_OFFSETS16[i];
        float2 offset = float2(i % AA, i / AA) - float2(0.5, 0.5);
        offset /= float2(AA, AA);

        offset = offset.x * ddxUV + offset.y * ddyUV;

        intensity += MowPattern_3(uv + offset);
    }
    intensity /= float(AA2);

    return intensity;
}

#endif
