// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Pitch2"
{
    Properties
    {
        _GrassColor1("_GrassColor1",            Color) = (1,1,1,1)
        _GrassColor2("_GrassColor2",            Color) = (1,1,1,1)
        _ColorTex("_ColorTex",               2D) = "white" {}
        _CommonTex("_CommonTex",              2D) = "white" {}
        _MowpatternTex("_MowpatternTex",          2D) = "white" {}
        _LineTex("_LineTex",                2D) = "white" {}
        _Bumpiness("_Bumpiness",              Range(0,1)) = 0.5
        _NoiseTile("_NoiseTile",              Vector) = (1, 1, 1, 1)
        _Multiple("_Multiple",              Range(1,10)) = 3
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #define PI 3.14159265359f

                // anti-aliasing: https://github.com/MeridianPoint/UnityShaderTools/blob/master/ShaderTools/Assets/Shader/Procedural2D/ProceduralLibrary2D.cginc
                #define AA 16  //anti-aliasing level
                #define AA2 AA * AA

                #include "UnityCG.cginc"
                #include "NoiseProcedural.hlsl"
                #include "MowPatternProcedural.hlsl"
                #include "GrassProcedural.hlsl"
                #include "PitchProcedural.hlsl"

                struct appdata
                {
                    float4 vertex   : POSITION;
                    half3 normal    : NORMAL;
                    float2 uv0      : TEXCOORD0;
                    half4 tangent   : TANGENT;
                };

                struct v2f
                {
                    float4 pos                              : SV_POSITION;
                    float2 tex                              : TEXCOORD0;
                    float4 eyeVec                           : TEXCOORD1;    // eyeVec.xyz | fogCoord
                    float4 eyeVecTS                         : TEXCOORD2;    // eye vector in tangent space
                };

                sampler2D _ColorTex;
                float4 _ColorTex_ST;

                sampler2D _CommonTex;
                sampler2D _MowpatternTex;
                sampler2D _LineTex;

                float4 _GrassColor1;
                float4 _GrassColor2;
                float _Bumpiness;
                float4 _NoiseTile;
                float _Multiple;

                v2f vert(appdata v)
                {
                    v2f o;
                    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                    o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0)));
                    o.tex = v.uv0;
                    o.eyeVec.xyz = normalize(posWorld.xyz - _WorldSpaceCameraPos);

                    float3 objectspace_eye = _WorldSpaceCameraPos.xyz - v.vertex.xyz;
                    objectspace_eye.y = _WorldSpaceCameraPos.y;
                    objectspace_eye.z = -abs(objectspace_eye.z);
                    objectspace_eye.x = -abs(objectspace_eye.x);
                    o.eyeVecTS.xyz = normalize(objectspace_eye.zxy);

                    return o;
                }

                float4 frag(v2f i) : SV_Target
                {
                    float3 viewDir = normalize(i.eyeVec);
                    float3 lightDir = _WorldSpaceLightPos0.xyz;
                    float3 h = normalize(lightDir + viewDir);

                    // Grass
                    float2 diffuseColorTiles = float2(20, 20);
                    //float diffuseColor = GrassAA(i.tex * diffuseColorTiles) * 5 + 0.5;
                    float diffuseColor = Grass(i.tex * diffuseColorTiles);
                    //diffuseColor = lerp(0.15, 0.95, diffuseColor);
                    //float diffuseColor = NoiseAA(i.tex * diffuseColorTiles);
                    //diffuseColor = lerp(0.25, 0.5, diffuseColor);
                    //float diffuseColor = tex2D(_ColorTex, i.tex * 5);

                    // Mow pattern
                    float3 mowPattern = MowPattern_3AA(i.tex).xyx * diffuseColor;
                    float3 mow = float3(mowPattern.xy * 2.0 - 1.0, 0.5) /* * diffuseColor*/;
                    float mowFactor = dot(mow, h) * _Bumpiness;
                    //mowFactor *= diffuseColor;
                    float3 mowColor = lerp(_GrassColor2.rgb, _GrassColor1.rgb, mowFactor);

                    // Pitch line
                    float pitchLine = PitchLineAA(i.tex);

                    // Noise
                    //float2 noiseTiles0 = float2(2, 2);
                    //float2 noiseTiles1 = float2(200, 200);

                    //float noise0 = NoiseAA(i.tex * noiseTiles0);
                    //noise0 = lerp(0.1, 0.2, noise0);

                    //float noise1 = NoiseAA(i.tex * noiseTiles1);
                    //noise1 = lerp(0.4, 0.5, noise1);

                    //float noise = saturate(noise0 + noise1);
                    float noise = tex2D(_CommonTex, i.tex * _NoiseTile).r;

                    // Combine
                    float4 finalColor = 1;

                    finalColor.rbg = diffuseColor;
                    finalColor.rgb *= mowColor;
                    finalColor.rgb += pitchLine;
                    finalColor.rgb *= noise;

                    finalColor.rgb *= _Multiple;
                    finalColor.rgb = PitchLine(i.tex);

                    return finalColor;
                }
                ENDCG
            }
        }
}
