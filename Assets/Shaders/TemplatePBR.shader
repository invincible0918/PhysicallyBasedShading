Shader "Custom/TemplatePBR"
{
    Properties
    {
		_MainTex				("Texture",			2D) = "white" {}
		_Normal					("Normal",			2D) = "bump" {}
		[Gamma] _Metallic		("Metallic",		2D) = "black" {} //金属度要经过伽马校正
		_LUT					("LUT",				2D) = "white" {}
    }

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Tags 
			{
				"LightMode" = "ForwardBase"
			}
			CGPROGRAM

			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityStandardBRDF.cginc" 

			struct appdata
			{
				float4 vertex		: POSITION;
				float3 normal		: NORMAL;
				float2 uv			: TEXCOORD0;
				half4 tangent		: TANGENT;
			};

			struct v2f
			{
				float4 vertex							: SV_POSITION;
				float2 uv								: TEXCOORD0;
				float4 tangentToWorldAndPackedData[3]	: TEXCOORD1;
			};

			sampler2D _MainTex;
			sampler2D _Metallic;
			sampler2D _Normal;
			float4 _MainTex_ST;
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

			// normal should be normalized, w=1.0
			half3 MyShadeSH9(half4 normal)
			{
				// SHEvalLinearL0L1
				half3 res;
				res.r = dot(unity_SHAr, normal);
				res.g = dot(unity_SHAg, normal);
				res.b = dot(unity_SHAb, normal);

				// SHEvalLinearL2
				half3 x1, x2;
				half4 vB = normal.xyzz * normal.yzzx;
				x1.r = dot(unity_SHBr, vB);
				x1.g = dot(unity_SHBg, vB);
				x1.b = dot(unity_SHBb, vB);

				half vC = normal.x*normal.x - normal.y*normal.y;
				x2 = unity_SHC.rgb * vC;

				// res
				res += (x1 + x2);
				
				return res;
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
				return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}

			float3 DirectDiffuse(float3 albedo)
			{
				float3 res = albedo;
				return res;
			}

			float3 DirectSpecular(float3 albedo, float3 metallic, float roughness, float nh, float nl, float nv, float vh)
			{
				float lerpRoughness = lerp(0.002, 1, roughness);//Unity把roughness lerp到了0.002
				float lerpSquareRoughness = pow(lerpRoughness, 2);
				float D = lerpSquareRoughness / (pow((pow(nh, 2) * (lerpSquareRoughness - 1) + 1), 2) * UNITY_PI);

				float kDirectLight = pow(lerpRoughness + 1, 2) / 8;
				float kIBL = pow(lerpSquareRoughness, 2) / 2;
				float GLeft = nl / lerp(nl, 1, kDirectLight);
				float GRight = nv / lerp(nv, 1, kIBL);
				float G = GLeft * GRight;

				float3 F0 = lerp(half3(0.04, 0.04, 0.04), albedo, metallic);
				float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);

				float3 res = (D * G * F * 0.25) / (nv * nl);

				return res;
			}

			float3 IndirectDiffuse(float3 albedo, float3 normal, float3 kdLast)
			{
				half3 ambient_contrib = MyShadeSH9(float4(normal, 1));
				float3 ambient = 0.03 * albedo;
				float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
				float3 iblDiffuseResult = iblDiffuse * kdLast * albedo;

				return iblDiffuseResult;
			}

			float3 IndirectSpecular(float perceptualRoughness, float roughness, float3 viewDir, float3 normal, float nv, float flast)
			{
				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				float3 reflectVec = reflect(-viewDir, normal);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVec, mip);
				rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVec, mip);

				float3 iblSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);

				float2 envBDRF = tex2D(_LUT, float2(lerp(0, 0.99, nv), lerp(0, 0.99, roughness))).rg;

				float3 iblSpecularResult = iblSpecular * (flast * envBDRF.r + envBDRF.g);

				return iblSpecularResult;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 normal = NormalInWorldSpace(i.uv, i.tangentToWorldAndPackedData);
				float3 posWorld = float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - posWorld);
				float3 lightColor = _LightColor0.rgb;
				float3 halfVector = normalize(lightDir + viewDir);

				float3 albedo = tex2D(_MainTex, i.uv).rgb;
				float2 mg = tex2D(_Metallic, i.uv).ra;
				float metallic = mg.x;
				float smoothness = mg.y;
				float perceptualRoughness = 1 - smoothness;
				float roughness = perceptualRoughness * perceptualRoughness;
				float squareRoughness = roughness * roughness;


				float nl = max(saturate(dot(normal, lightDir)), 0.000001);//防止除0
				float nv = max(saturate(dot(normal, viewDir)), 0.000001);
				float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
				float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);
				float nh = max(saturate(dot(normal, halfVector)), 0.000001);

				float3 F0 = lerp(half3(0.04, 0.04, 0.04), albedo, metallic);
				float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);


				float kd = (1 - F) * (1 - metallic);
				float ks = F;

				float3 directDiffuse = DirectDiffuse(albedo);
				float3 directSpecular = DirectSpecular(albedo, metallic, roughness, nh, nl, nv, vh);

				float3 directResult = (kd * directDiffuse / UNITY_PI + ks * directSpecular) * lightColor * nl;


				float3 flast = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);
				float3 kdLast = (1 - flast) * (1 - metallic);

				float3 indirectDiffuse = IndirectDiffuse(albedo, normal, kdLast);
				float3 indirectSpecular = IndirectSpecular(perceptualRoughness, roughness, viewDir, normal, nv, flast);

				float3 indirectResult = indirectDiffuse + indirectSpecular;

				float4 result = float4(directResult + indirectResult, 1);
				result.rgb = indirectDiffuse;

				return result;
			}

			ENDCG
		}
	}
}
