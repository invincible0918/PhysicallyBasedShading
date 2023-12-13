#ifndef _PITCH_PROCEDURAL_
#define _PITCH_PROCEDURAL_

const static HALF2 ANCHOR_0 = HALF2(0.035, 0.04);
const static HALF2 ANCHOR_1 = HALF2(ANCHOR_0.x, 0.5);
const static HALF2 ANCHOR_2 = HALF2(0.5, ANCHOR_0.y);

const static HALF2 ANCHOR_3 = HALF2(ANCHOR_0.x + 0.19, ANCHOR_0.y);
const static HALF2 ANCHOR_4 = HALF2(ANCHOR_3.x, ANCHOR_3.y + 0.14);
const static HALF2 ANCHOR_5 = HALF2(0.5, ANCHOR_4.y);

const static HALF2 ANCHOR_6 = HALF2(ANCHOR_3.x + 0.15, ANCHOR_3.y);
const static HALF2 ANCHOR_7 = HALF2(ANCHOR_6.x, ANCHOR_6.y + 0.044);
const static HALF2 ANCHOR_8 = HALF2(0.5, ANCHOR_7.y);

const static HALF2 ANCHOR_9 = HALF2(0., 0.55);

// For corner arc
const static HALF2 ANCHOR_10 = HALF2(0.465, 0.69);

const static HALF RADIUS_0 = 0.23;
const static HALF RADIUS_1 = 0.025;

const static HALF LINE_WIDTH = 0.002;
const static HALF CIRCLE_WIDTH = 0.01;
const static HALF ARC_WIDTH = 0.01;
const static HALF TINY_ARC_WIDTH = 0.05;
const static HALF LINE_TRANS = 0.75;

///////////////////////////////////////////////////////////////////////////////////

HALF Line(HALF2 p1, HALF2 p2, HALF2 uv)
{
    float2 pa = uv - p1;
    float2 ba = p2 - p1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h) - LINE_WIDTH;
    return sqrt(smoothstep(1.5, -1.5, d * _ScreenParams.y));











    //// get dist between points
    //HALF d = distance(p1, p2);

    //// get dist between current pixel and p1
    //HALF duv = distance(p1, uv);

    //HALF r = distance(lerp(p1, p2, saturate(duv / d)), uv);

    //// Antialias
    //r = smoothstep(LINE_WIDTH, 0.00, r);
    //return r;
}

HALF QuarterPitchLine(HALF2 uv)
{
    HALF quarterPitchLine0 = Line(ANCHOR_0, ANCHOR_1, uv) + Line(ANCHOR_0, ANCHOR_2, uv);
    HALF quarterPitchLine1 = Line(ANCHOR_3, ANCHOR_4, uv) + Line(ANCHOR_4, ANCHOR_5, uv);
    HALF quarterPitchLine2 = Line(ANCHOR_6, ANCHOR_7, uv) + Line(ANCHOR_7, ANCHOR_8, uv);

    return quarterPitchLine0 + quarterPitchLine1 + quarterPitchLine2;
}

HALF Circle(HALF2 center, HALF radius, HALF2 uv)
{
    HALF2 uv2 = (uv - HALF2(0.5, 0.5)) * HALF2(1, 1.5) + center;
    HALF d = length(uv2) / radius;

    // Antialias
    HALF col = smoothstep(0.5 - CIRCLE_WIDTH, 0.5, d) - smoothstep(0.5, 0.5 + CIRCLE_WIDTH, d);
    return col;
}

HALF Arc(HALF2 center, HALF radius, HALF degreeStart, HALF degreeEnd, HALF2 uv, HALF width)
{
    HALF2 uv2 = (uv - HALF2(0.5, 0.5)) * HALF2(1, 1.5) + center;
    HALF d = length(uv2) / radius;
    HALF angle = atan2(uv2.x, uv2.y) / PI * 0.5 + 0.5;

    // Antialias
    HALF angleStart = smoothstep(degreeStart - width, degreeStart, angle);
    HALF angleEnd = 1 - smoothstep(degreeEnd, degreeEnd + width, angle);

    angle = angleStart * angleEnd;

    // Antialias
    HALF r = -smoothstep(0.5, 0.5 + width, d) + smoothstep(0.5 - width, 0.5, d);
    return angle * r;
}

HALF PitchLine(HALF2 uv)
{
    //uv = (uv - 0.5) * HALF2(1, 2) + 0.5;
    HALF2 uv0 = uv;
    HALF2 uv1 = HALF2(1 - uv.x, uv.y);
    HALF2 uv2 = HALF2(uv.x, 1 - uv.y);
    HALF2 uv3 = HALF2(1 - uv.x, 1 - uv.y);

    HALF pitchLine0 = QuarterPitchLine(uv0) + QuarterPitchLine(uv1) + QuarterPitchLine(uv2) + +QuarterPitchLine(uv3);
    HALF pitchLine1 = Line(HALF2(ANCHOR_0.x, 0.5), HALF2(1 - ANCHOR_0.x, 0.5), uv);

    HALF centerCircle = Circle(HALF2(0., 0.), RADIUS_0, uv0);

    HALF arc0 = Arc(ANCHOR_9, RADIUS_0, 0.36, 0.64, uv0, ARC_WIDTH);
    HALF arc1 = Arc(ANCHOR_9, RADIUS_0, 0.36, 0.64, uv2, ARC_WIDTH);

    HALF arc2 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv0, TINY_ARC_WIDTH);
    HALF arc3 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv1, TINY_ARC_WIDTH);
    HALF arc4 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv2, TINY_ARC_WIDTH);
    HALF arc5 = Arc(ANCHOR_10, RADIUS_1, 0.52, 0.7, uv3, TINY_ARC_WIDTH);

    HALF arc = arc0 + arc1 + arc2 + arc3 + arc4 + arc5;

    HALF lineColor = pitchLine0 + pitchLine1 + centerCircle + arc;
    return lineColor/* * LINE_TRANS*/;
}

#endif



