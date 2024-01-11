Shader "Custom/TemplatePBR"
{
    Properties
    {
		_MainTex				("Texture",			2D) = "white" {}
		_Normal					("Normal",			2D) = "bump" {}
		/*[Gamma] */_Metallic		("Metallic",		2D) = "black" {} //金属度要经过伽马校正
		///*[Gamma] */_Roughness		("Roughness",		2D) = "black" {} //粗糙度要经过伽马校正
		_LUT					("LUT",				2D) = "white" {}
    }

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Tags {
				"LightMode" = "ForwardBase"
			}
			CGPROGRAM


			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityStandardBRDF.cginc" 

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				half4 tangent		: TANGENT;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 tangentToWorldAndPackedData[3]	: TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Normal;
			sampler2D _Metallic;
			sampler2D _Roughness;
			sampler2D _LUT;

			half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)
			{
				// For odd-negative scale transforms we need to flip the sign
				half sign = tangentSign * unity_WorldTransformParams.w;
				half3 binormal = cross(normal, tangent) * sign;
				return half3x3(tangent, binormal, normal);
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				float3 posWorld = mul(unity_ObjectToWorld, v.vertex);

				float3 normalWorld = UnityObjectToWorldNormal(v.normal);
				normalWorld = normalize(normalWorld);

				float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
				float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
				o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];	// tangentWorld
				o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];	// binormalWorld
				o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];	// normalWorld

				o.tangentToWorldAndPackedData[0].w = posWorld.x;
				o.tangentToWorldAndPackedData[1].w = posWorld.y;
				o.tangentToWorldAndPackedData[2].w = posWorld.z;

				return o;
			}

			half3 UnpackScaleNormal(half4 packednormal, half bumpScale)
			{
				half3 normal = packednormal.xyz * 2 - 1;
				normal.xy *= bumpScale;
				return normal;
			}

			half3 NormalInTangentSpace(float2 uv, float bumpScale)
			{
				half4 packednormal = tex2D(_Normal, uv);

				// This do the trick
				packednormal.x *= packednormal.w;

				half3 normal;
				normal.xy = packednormal.xy * 2 - 1;
				normal.xy *= bumpScale;
				normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));

				return normal;
			}

			float3 NormalInWorldSpace(float2 uv, float4 tangentToWorld[3])
			{
				half3 tangent = tangentToWorld[0].xyz;
				half3 binormal = tangentToWorld[1].xyz;
				half3 normal = tangentToWorld[2].xyz;

				half3 normalTangent = NormalInTangentSpace(uv, 1.0);
				float3 normalWorld = float3(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z);
				normalWorld = normalize(normalWorld);

				//float3 normalWorld = normalize(tangentToWorld[2].xyz);

				return normalWorld;
			}

			float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			{
				return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = NormalInWorldSpace(i.uv, i.tangentToWorldAndPackedData);
				float3 posWorld = float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);

				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - posWorld);
				float3 lightColor = _LightColor0.rgb;
				float3 halfVector = normalize(lightDir + viewDir);  //半角向量

				float metallic = tex2D(_Metallic, i.uv).r;
				float perceptualRoughness = 1 - tex2D(_Metallic, i.uv).a;// tex2D(_Roughness, i.uv).r;

				float roughness = perceptualRoughness * perceptualRoughness;
				float squareRoughness = roughness * roughness;

				float nl = max(saturate(dot(normal, lightDir)), 0.000001);//防止除0
				float nv = max(saturate(dot(normal, viewDir)), 0.000001);
				float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
				float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);
				float nh = max(saturate(dot(normal, halfVector)), 0.000001);

				float3 Albedo = tex2D(_MainTex, i.uv);

				float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2);//Unity把roughness lerp到了0.002
				float D = lerpSquareRoughness / (pow((pow(nh, 2) * (lerpSquareRoughness - 1) + 1), 2) * UNITY_PI);

				float kInDirectLight = pow(squareRoughness + 1, 2) / 8;
				float kInIBL = pow(squareRoughness, 2) / 8;
				float GLeft = nl / lerp(nl, 1, kInDirectLight);
				float GRight = nv / lerp(nv, 1, kInDirectLight);
				float G = GLeft * GRight;

				float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, metallic);
				float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);

				float3 SpecularResult = (D * G * F * 0.25) / (nv * nl);

				//漫反射系数
				float3 kd = (1 - F) * (1 - metallic);

				//直接光照部分结果
				float3 specColor = SpecularResult * lightColor * nl * UNITY_PI;
				float3 diffColor = kd * Albedo * lightColor * nl;
				float3 DirectLightResult = diffColor + specColor;

				half3 ambient_contrib = ShadeSH9(float4(normal, 1));

				float3 ambient = 0.03 * Albedo;

				float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);

				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				float3 reflectVec = reflect(-viewDir, normal);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVec, mip); //根据粗糙度生成lod级别对贴图进行三线性采样

				float3 iblSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);

				float2 envBDRF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg; // LUT采样

				float3 Flast = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);
				float kdLast = (1 - Flast) * (1 - metallic);

				float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;
				float3 iblSpecularResult = iblSpecular * (Flast * envBDRF.r + envBDRF.g);
				float3 IndirectResult = iblDiffuseResult + iblSpecularResult;

				float4 result = float4(DirectLightResult + IndirectResult, 1);

				return result;
			}

			ENDCG
		}
	}
}