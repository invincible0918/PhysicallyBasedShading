#ifndef _MOW_PATTERN_
#define _MOW_PATTERN_

const static HALF2 AROUND_AREA = HALF2(0.035, 0.04);
const static HALF4 AROUND_AREA_RECT = HALF4(AROUND_AREA.x, AROUND_AREA.y, 1 - AROUND_AREA.x, 1 - AROUND_AREA.y);
const static HALF4 GRAY = HALF4(0.2, 0.4, 0.6, 0.8);

const static HALF MOW_PATTERN_3_TILE = 20;
const static HALF MOW_PATTERN_3_OFFSET = 0.6;

HALF2 MowPattern_3(HALF2 uv)
{
    HALF around = step(uv.x, AROUND_AREA_RECT.x) + step(AROUND_AREA_RECT.z, uv.x) + step(uv.y, AROUND_AREA_RECT.y) + step(AROUND_AREA_RECT.w, uv.y);
    around = step(0.5, around);

    HALF pattern = smoothstep(0.45, 0.55, sin(uv.y * PI * MOW_PATTERN_3_TILE + MOW_PATTERN_3_OFFSET) * 0.5 + 0.5);
    //pattern = step(0.5, pattern);
    pattern = lerp(GRAY.x, GRAY.z, pattern);

    return lerp(GRAY.y, pattern, 1 - around);
}

#endif
