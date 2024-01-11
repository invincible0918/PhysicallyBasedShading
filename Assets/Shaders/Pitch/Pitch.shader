Shader "Custom/Pitch"
{
    Properties
    {
        _GrassColor1            ("_GrassColor1",            Color) = (1,1,1,1)
        _GrassColor2            ("_GrassColor2",            Color) = (1,1,1,1)
        _ColorTex               ("_ColorTex",               2D) = "white" {}
        _CommonTex              ("_CommonTex",              2D) = "white" {}
        _MowpatternTex          ("_MowpatternTex",          2D) = "white" {}
        _LineTex                ("_LineTex",                2D) = "white" {}
        _Bumpiness              ("_Bumpiness",              Range(0,1)) = 0.5
        _NoiseTile              ("_NoiseTile",              Range(0,100)) = 10
        _Multiple               ("_Multiple",              Range(1,10)) = 3
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

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
                float4 tangentToWorldAndPackedData[3]   : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
                float3 posWorld                         : TEXCOORD5;
            };

            sampler2D _ColorTex;
            sampler2D _CommonTex;
            sampler2D _MowpatternTex;
            sampler2D _LineTex;
            float4 _ColorTex_ST;

            fixed4 _GrassColor1;
            fixed4 _GrassColor2;
            float _Bumpiness;
            float _NoiseTile;
            float _Multiple;

            float3x3 TangentToWorld(float3 normal, float3 tangent, float tangentSign)
            {
                // For odd-negative scale transforms we need to flip the sign
                // float4 unity_WorldTransformParams; // w is usually 1.0, or -1.0 for odd-negative scale transforms
                float sign = tangentSign/* * unity_WorldTransformParams.w*/;
                float3 binormal = cross(normal, tangent) * sign;
                return float3x3(tangent, binormal, normal);
            }

            v2f vert (appdata v)
            {
                v2f o;
                float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.tangentToWorldAndPackedData[0].w = posWorld.x;
                o.tangentToWorldAndPackedData[1].w = posWorld.y;
                o.tangentToWorldAndPackedData[2].w = posWorld.z;
                o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0)));
                o.tex = v.uv0;
                o.eyeVec.xyz = normalize(posWorld.xyz - _WorldSpaceCameraPos);
                float3 normalWorld = mul((float3x3)unity_ObjectToWorld, v.normal);
                normalWorld = normalize(normalWorld);

                float4 tangentWorld = float4(mul((float3x3)unity_ObjectToWorld, v.tangent.xyz), v.tangent.w);
                float3x3 tangentToWorld = TangentToWorld(normalWorld, tangentWorld.xyz, tangentWorld.w);
                o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
                o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
                o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];

                return o;
            }

            //inline half3 GammaToLinearSpace(half3 sRGB)
            //{
            //    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
            //    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

            //    // Precise version, useful for debugging.
            //    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
            //}

            //inline half3 LinearToGammaSpace(half3 linRGB)
            //{
            //    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
            //    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
            //    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);

            //    // Exact version, useful for debugging.
            //    //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
            //}

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir = normalize(i.eyeVec);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 h = normalize(lightDir + viewDir);

                float3 mowPattern = tex2D(_MowpatternTex, i.tex).xyz;
                float3 mow = float3(mowPattern.xy * 2.0 - 1.0, 0.5);

                float mowFactor = dot(mow, h) * _Bumpiness;

                float4 finalColor = tex2D(_ColorTex, i.tex * 5);

                finalColor.rgb *= lerp(_GrassColor2.rgb, _GrassColor1.rgb, mowFactor);

                float2 uvMirrored = i.tex.xy * (float2(step(i.tex.x, 0.5), step(i.tex.y, 0.5)) * 4 - 2);
                float pitchLine = tex2D(_LineTex, uvMirrored).r;
                finalColor.rgb += pitchLine;

                float noise = tex2D(_CommonTex, i.tex * _NoiseTile).r;
                finalColor.rgb *= noise;

                finalColor.rgb *= _Multiple;
                finalColor.rgb = mowPattern.y;

                return finalColor;
            }
            ENDCG
        }
    }
}
