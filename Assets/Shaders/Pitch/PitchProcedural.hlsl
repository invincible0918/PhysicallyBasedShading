#ifndef _PITCH_PROCEDURAL_
#define _PITCH_PROCEDURAL_

const static float2 ANCHOR_0 = float2(0.035, 0.04);
const static float2 ANCHOR_1 = float2(ANCHOR_0.x, 0.5);
const static float2 ANCHOR_2 = float2(0.5, ANCHOR_0.y);

const static float2 ANCHOR_3 = float2(ANCHOR_0.x + 0.19, ANCHOR_0.y);
const static float2 ANCHOR_4 = float2(ANCHOR_3.x, ANCHOR_3.y + 0.14);
const static float2 ANCHOR_5 = float2(0.5, ANCHOR_4.y);

const static float2 ANCHOR_6 = float2(ANCHOR_3.x + 0.15, ANCHOR_3.y);
const static float2 ANCHOR_7 = float2(ANCHOR_6.x, ANCHOR_6.y + 0.044);
const static float2 ANCHOR_8 = float2(0.5, ANCHOR_7.y);

const static float2 ANCHOR_9 = float2(0., 0.55);

// For corner arc
const static float2 ANCHOR_10 = float2(0.465, 0.69);

const static float RADIUS_0 = 0.23;
const static float RADIUS_1 = 0.025;

const static float LINE_WIDTH = 0.001;
const static float CIRCLE_WIDTH = 0.01;
const static float ARC_WIDTH = 0.01;
const static float TINY_ARC_WIDTH = 0.05;

///////////////////////////////////////////////////////////////////////////////////

float Line(float2 p1, float2 p2, float2 uv)
{
    float2 pa = uv - p1;
    float2 ba = p2 - p1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h) - LINE_WIDTH;
    return sqrt(smoothstep(1.5, -1.5, d * _ScreenParams.y));
}

float QuarterPitchLine(float2 uv)
{
    float quarterPitchLine0 = Line(ANCHOR_0, ANCHOR_1, uv) + Line(ANCHOR_0, ANCHOR_2, uv);
    float quarterPitchLine1 = Line(ANCHOR_3, ANCHOR_4, uv) + Line(ANCHOR_4, ANCHOR_5, uv);
    float quarterPitchLine2 = Line(ANCHOR_6, ANCHOR_7, uv) + Line(ANCHOR_7, ANCHOR_8, uv);

    return quarterPitchLine0 + quarterPitchLine1 + quarterPitchLine2;
}

float Circle(float2 center, float radius, float2 uv)
{
    float2 uv2 = (uv - float2(0.5, 0.5)) * float2(1, 1.5) + center;
    float d = length(uv2) / radius;

    // Antialias
    float col = smoothstep(0.5 - CIRCLE_WIDTH, 0.5, d) - smoothstep(0.5, 0.5 + CIRCLE_WIDTH, d);
    return col;
}

float Arc(float2 center, float radius, float degreeStart, float degreeEnd, float2 uv, float width)
{
    float2 uv2 = (uv - float2(0.5, 0.5)) * float2(1, 1.5) + center;
    float d = length(uv2) / radius;
    float angle = atan2(uv2.x, uv2.y) / PI * 0.5 + 0.5;

    // Antialias
    float angleStart = smoothstep(degreeStart - width, degreeStart, angle);
    float angleEnd = 1 - smoothstep(degreeEnd, degreeEnd + width, angle);

    angle = angleStart * angleEnd;

    // Antialias
    float r = -smoothstep(0.5, 0.5 + width, d) + smoothstep(0.5 - width, 0.5, d);
    return angle * r;
}

float PitchLine(float2 uv)
{
    //float2 offset = float2(i % AA, i / AA) - float2(0.5, 0.5);
    //offset /= float2(AA, AA);
    float2 ddxUV = ddx(uv);
    float2 ddyUV = ddy(uv);
    float2 offset = float2(Noise(uv * _Time.w) - 0.5, Noise(uv * _Time.z) - 0.5);
    offset /= 512;
    uv += offset;

    //uv = (uv - 0.5) * float2(1, 2) + 0.5;
    float2 uv0 = uv;
    float2 uv1 = float2(1 - uv.x, uv.y);
    float2 uv2 = float2(uv.x, 1 - uv.y);
    float2 uv3 = float2(1 - uv.x, 1 - uv.y);

    float pitchLine0 = QuarterPitchLine(uv0) + QuarterPitchLine(uv1) + QuarterPitchLine(uv2) + +QuarterPitchLine(uv3);
    float pitchLine1 = Line(float2(ANCHOR_0.x, 0.5), float2(1 - ANCHOR_0.x, 0.5), uv);

    float centerCircle = Circle(float2(0., 0.), RADIUS_0, uv0);

    float arc0 = Arc(ANCHOR_9, RADIUS_0, 0.36, 0.64, uv0, ARC_WIDTH);
    float arc1 = Arc(ANCHOR_9, RADIUS_0, 0.36, 0.64, uv2, ARC_WIDTH);

    float arc2 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv0, TINY_ARC_WIDTH);
    float arc3 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv1, TINY_ARC_WIDTH);
    float arc4 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv2, TINY_ARC_WIDTH);
    float arc5 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv3, TINY_ARC_WIDTH);

    float arc = arc0 + arc1 + arc2 + arc3 + arc4 + arc5;

    float lineColor = pitchLine0 + pitchLine1 + centerCircle + arc;
    return lineColor;
}

float PitchLineAA(float2 uv)
{
    float intensity = 0.0;

    float2 ddxUV = ddx(uv);
    float2 ddyUV = ddy(uv);

    for (uint i = 0; i < AA2; i++) 
    {
        //float2 offset = ANTI_ALIASING_OFFSETS16[i];
        float2 offset = float2(i % AA, i / AA) - float2(0.5, 0.5);
        offset /= float2(AA, AA);

        offset = offset.x * ddxUV + offset.y * ddyUV;
        
        intensity += PitchLine(uv + offset);
    }
    intensity /= float(AA2);

    return intensity;
}

#endif



