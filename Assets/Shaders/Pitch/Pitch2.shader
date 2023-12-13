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
                #define HALF half
                #define HALF2 half2
                #define HALF3 half3
                #define HALF4 half4
                #define HALF3x3 half3x3

                #include "UnityCG.cginc"
                #include "Assets/Shaders/NoiseShader/ClassicNoise2D.hlsl"
                #include "Assets/Shaders/NoiseShader/ClassicNoise3D.hlsl"
                #include "Assets/Shaders/NoiseShader/SimplexNoise2D.hlsl"
                #include "Assets/Shaders/NoiseShader/SimplexNoise3D.hlsl"
                #include "Mowpattern.hlsl"
                #include "PitchProcedural.hlsl"

                struct appdata
                {
                    HALF4 vertex   : POSITION;
                    half3 normal    : NORMAL;
                    HALF2 uv0      : TEXCOORD0;
                    half4 tangent   : TANGENT;
                };

                struct v2f
                {
                    HALF4 pos                              : SV_POSITION;
                    HALF2 tex                              : TEXCOORD0;
                    HALF4 eyeVec                           : TEXCOORD1;    // eyeVec.xyz | fogCoord
                };

                sampler2D _ColorTex;
                HALF4 _ColorTex_ST;

                sampler2D _CommonTex;
                sampler2D _MowpatternTex;
                sampler2D _LineTex;

                HALF4 _GrassColor1;
                HALF4 _GrassColor2;
                HALF _Bumpiness;
                HALF4 _NoiseTile;
                HALF _Multiple;

                v2f vert(appdata v)
                {
                    v2f o;
                    HALF4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                    o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, HALF4(v.vertex.xyz, 1.0)));
                    o.tex = v.uv0;
                    o.eyeVec.xyz = normalize(posWorld.xyz - _WorldSpaceCameraPos);

                    return o;
                }

                HALF4 frag(v2f i) : SV_Target
                {
                    HALF3 viewDir = normalize(i.eyeVec);
                    HALF3 lightDir = _WorldSpaceLightPos0.xyz;
                    HALF3 h = normalize(lightDir + viewDir);

                    HALF3 mowPattern = tex2D(_MowpatternTex, i.tex).xyz;
                    HALF3 mow = HALF3((MowPattern_3(i.tex).xy * 2.0) - 1.0, 0.5);

                    HALF mowFactor = dot(mow, h) * _Bumpiness;

                    HALF4 finalColor = 1;

                    HALF2 diffuseColorTiles = HALF2(200, 300);
                    HALF diffuseColor = HALF(ClassicNoise(i.tex * diffuseColorTiles));
                    diffuseColor = lerp(0.3, 0.4, diffuseColor);
                    finalColor.rbg = diffuseColor;

                    finalColor.rgb *= lerp(_GrassColor2.rgb, _GrassColor1.rgb, mowFactor);

                    HALF pitchLine = PitchLine(i.tex);

                    finalColor.rgb += pitchLine;

                    HALF2 noiseTiles = HALF2(600, 300);
                    HALF noise = ClassicNoise(i.tex * noiseTiles);
                    noise  = lerp(0.8, 0.95, noise);

                    finalColor.rgb *= noise;

                    finalColor.rgb *= _Multiple;
                    finalColor.rgb = pitchLine;

                    return finalColor;
                }
                ENDCG
            }
        }
}
