// https://www.shadertoy.com/view/WsSGWd
#ifndef _GRASS_PROCEDURAL_
#define _GRASS_PROCEDURAL_

#define BLADES_SPACING 0.002
#define JITTER_MAX 0.001
#define GRASS_WIDTH 0.0004
// depends on size of grass blades in pixels
#define LOOKUP_DIST 4
#define LOOKUP_DIST4 pow(LOOKUP_DIST, 4)

#define HASHSCALE1 .1031
#define HASHSCALE3 float3(.1031, .1030, .0973)

#define GRASS_LAYER 128

const static float height = .5;
const static float scale = 20.;

const static float wiggle = 1.;
const static float heightVariance = .3;

const static float3 healthy = float3(0., heightVariance * .5 + .2, .05);
const static float3 ded = float3(.8, .75, .4);
const static uint k = 1103515245U;

const static float2 GRASS_POS_OFFSETS16[16] = {
    float2(-2, -2),
    float2(-2, -1),
    float2(-2, 0),
    float2(-2, 1),
    float2(-1, -2),
    float2(-1, -1),
    float2(-1, 0),
    float2(-1, 1),
    float2(0, -2),
    float2(0, -1),
    float2(0, 0),
    float2(0, 1),
    float2(1, -2),
    float2(1, -1),
    float2(1, 0),
    float2(1, 1)
};

const static float2 GRASS_POS_OFFSETS64[64] = {
    float2(-4, -4),
    float2(-4, -3),
    float2(-4, -2),
    float2(-4, -1),
    float2(-4, 0),
    float2(-4, 1),
    float2(-4, 2),
    float2(-4, 3),
    float2(-3, -4),
    float2(-3, -3),
    float2(-3, -2),
    float2(-3, -1),
    float2(-3, 0),
    float2(-3, 1),
    float2(-3, 2),
    float2(-3, 3),
    float2(-2, -4),
    float2(-2, -3),
    float2(-2, -2),
    float2(-2, -1),
    float2(-2, 0),
    float2(-2, 1),
    float2(-2, 2),
    float2(-2, 3),
    float2(-1, -4),
    float2(-1, -3),
    float2(-1, -2),
    float2(-1, -1),
    float2(-1, 0),
    float2(-1, 1),
    float2(-1, 2),
    float2(-1, 3),
    float2(0, -4),
    float2(0, -3),
    float2(0, -2),
    float2(0, -1),
    float2(0, 0),
    float2(0, 1),
    float2(0, 2),
    float2(0, 3),
    float2(1, -4),
    float2(1, -3),
    float2(1, -2),
    float2(1, -1),
    float2(1, 0),
    float2(1, 1),
    float2(1, 2),
    float2(1, 3),
    float2(2, -4),
    float2(2, -3),
    float2(2, -2),
    float2(2, -1),
    float2(2, 0),
    float2(2, 1),
    float2(2, 2),
    float2(2, 3),
    float2(3, -4),
    float2(3, -3),
    float2(3, -2),
    float2(3, -1),
    float2(3, 0),
    float2(3, 1),
    float2(3, 2),
    float2(3, 3)
};

float3 hash(uint3 x)
{
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;

    return float3(x) * (1.0 / float(0xffffffffU));
}

float hash12(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
}

///  3 out, 2 in...
float3 hash32(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yxz + 19.19);
    return frac((p3.xxy + p3.yzz) * p3.zyx);
}

/// 2 out, 2 in...
float2 hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * HASHSCALE3);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy);

}

float getGrassBlade(float2 position, float2 grassPos) 
{
    // between {-1, -1, -1} and {1, 1, 1}
    float3 grassVector3 = hash32(grassPos * 12351.241) * 2.0 - 1.0;

    // keep grass z between 0 and 0.4
    grassVector3.z = grassVector3.z * 0.2 + 0.2;
    float2 grassVector2 = normalize(grassVector3.xy);

    float grassLength = hash12(grassPos * 10234.87) * 0.01 + 0.01;

    // take coordinates in grass blade frame
    float2 gv = position - grassPos;
    float gx = dot(grassVector2, gv);
    float gy = dot(float2(-grassVector2.y, grassVector2.x), gv);
    float gxn = gx / grassLength;

    // TODO make gy depends to gx
    if (gxn >= 0.0 && gxn <= 1.0 && abs(gy) <= GRASS_WIDTH * (1. - gxn * gxn))
        return grassVector3.z * gxn;
    else 
        return -1.0;
}


float Grass(float2 position) 
{
    uint ox = uint(position.x / BLADES_SPACING);
    uint oy = uint(position.y / BLADES_SPACING);

    float maxZ = 0.0;

    //for (uint i = 0; i < LOOKUP_DIST4; i++)
    //{
    //    float2 offset = GRASS_POS_OFFSETS64[i];

    //    float2 upos = float2(ox + offset.x, oy + offset.y);
    //    float2 grassPos = (upos * BLADES_SPACING + hash22(upos) * JITTER_MAX);

    //    float z = getGrassBlade(position, grassPos);
    //    maxz = max(z, maxz);
    //}

    for (int i = -LOOKUP_DIST; i < LOOKUP_DIST; ++i)
    {
        for (int j = -LOOKUP_DIST; j < LOOKUP_DIST; ++j)
        {
            float2 upos = float2(ox + i, oy + j);
            float2 grassPos = (upos * BLADES_SPACING + hash22(upos) * JITTER_MAX);

            float z = getGrassBlade(position, grassPos);

            //if (z > maxz) 
            //{
            //    maxz = z;
            //}
            maxZ = max(z, maxZ);
        }
    }

    //CalcMaxZ(0, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(1, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(2, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(3, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(4, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(5, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(6, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(7, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(8, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(9, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(10, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(11, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(12, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(13, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(14, position, ox, oy, /* inout */maxZ);
    //CalcMaxZ(15, position, ox, oy, /* inout */maxZ);


    return maxZ;
}

float4 ray(float3 o, float3 dir, float z)
{
    if (dir.z > 0.) 
        return 0;
    float t = (o.z - z) / dir.z;
    return float4(o + dir * t, -t);
}

float4 ray(float3 o, float3 dir) 
{
    return ray(o, dir, height);
}

float3 Grass2(float2 uv, float3 viewDir) // view dir is in tangent space
{
    float3 camDir = viewDir;// float3(sin(muv.x) * cos(muv.y), cos(muv.x) * cos(muv.y), sin(muv.y));
    float3 right = normalize(cross(camDir, float3(0, 0, 1)));
    float3 up = cross(right, camDir);

    float3 dir = normalize(float3(uv.x, 1, uv.y));
    dir = camDir + right * uv.x + up * uv.y;

    float3 pos, m, n, col = 0;
    float3 o = float3(1, 0, 0);
    for (float i = 1.; i > 0.; i -= 1. / float(GRASS_LAYER)) 
    {
        m = hash(uint3(uv, 0));
        float4 r = ray(o, dir, i * height + m.x / float(GRASS_LAYER));
        pos = r.xyz;
        float t = r.w;

        n = hash(uint3(fmod(float3(pos.xy, 1.) * scale, 256)));
        // Mod can be replaced with abs at the cost of grass symmetric around the axes
        // Abs causes mirroring, mod causes tiling
        // better suggestions welcome.

        float2 cellCoord = frac(pos.xy * scale) * 2. - 1. // Gives us the coordinates inside the current cell
            + n.yz * 2. - 1. // offsets the coordinate centre for off grid grass. Just comment this line to see the difference.
            + (n.xz * 2. - 1.) * sin(i * 5. / wiggle + n.y * 179.) * wiggle // and then we offset based on height so make 'em wiggly
            ; // This is put here so you can comment the above line without erroring


        if (length(cellCoord) < lerp(1., n.x, heightVariance) - i) 
        {
            col = lerp(col, float3(lerp(healthy, ded, n.x)) * i, 1.);
            break;
        }
    }
    return col;
}

float GrassAA(float2 uv)
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

        intensity += Grass(uv + offset);
    }
    intensity /= float(AA2);

    return intensity;
}

#endif
