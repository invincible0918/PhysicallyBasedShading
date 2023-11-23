Shader "Custom/LitPBR"
{
	Properties
	{
		_MainTex								("Albedo",				2D)				= "white" {}
		_MetallicTex							("Metallic",			2D)				= "white" {}
		_RoughnessTex							("Roughness",			2D)				= "white" {}
		_RoughnessScale							("RoughnessScale",      Range(0, 1))	= 0
		_NormalTex								("Normal",				2D)				= "bump" {}
		[HideInInspector] _CubeTex				("Reflection Cubemap",	Cube)			= "_Skybox" { }
		[HideInInspector] _BRDFTex				("IBL Brdf LUT",		2D)				= "white" {}
		// Blending state
		[HideInInspector] _Mode					("__mode",				Float)			= 0.0
		[HideInInspector] _SrcBlend				("__src",				Float)			= 1.0
		[HideInInspector] _DstBlend				("__dst",				Float)			= 0.0
		[HideInInspector] _ZWrite				("__zw",				Float)			= 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			//Name "FORWARD"
			//Tags { "LightMode" = "ForwardBase" }

			//Blend[_SrcBlend][_DstBlend]
			//ZWrite[_ZWrite]

			CGPROGRAM
			#pragma vertex vertForward
			#pragma fragment fragForward

			#include "UnityCG.cginc"
			#include "SH9Common.hlsl"
			#include "StandardCoreForward.cginc"

			ENDCG
		}
		//// ------------------------------------------------------------------
		////  Additive forward pass (one light per pass)
		//Pass
		//{
		//	Name "FORWARD_DELTA"
		//	Tags { "LightMode" = "ForwardAdd" }
		//	Blend[_SrcBlend] One
		//	Fog { Color(0,0,0,0) } // in additive pass fog should be black
		//	ZWrite Off
		//	ZTest LEqual

		//	CGPROGRAM
		//	#pragma target 3.0
		//	// GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
		//	#pragma exclude_renderers gles

		//	// -------------------------------------


		//	#pragma shader_feature _NORMALMAP
		//	#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
		//	#pragma shader_feature _METALLICGLOSSMAP
		//	#pragma shader_feature ___ _DETAIL_MULX2
		//	#pragma shader_feature _PARALLAXMAP

		//	#pragma multi_compile_fwdadd_fullshadows
		//	#pragma multi_compile_fog

		//	#pragma vertex vertAdd
		//	#pragma fragment fragAdd
		//	#include "UnityStandardCoreForward.cginc"

		//	ENDCG
		//}
		//// ------------------------------------------------------------------
		////  Shadow rendering pass
		//Pass 
		//{
		//	Name "ShadowCaster"
		//	Tags { "LightMode" = "ShadowCaster" }

		//	ZWrite On ZTest LEqual

		//	CGPROGRAM
		//	#pragma target 3.0
		//	// TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
		//	#pragma exclude_renderers gles

		//	// -------------------------------------


		//	#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
		//	#pragma multi_compile_shadowcaster

		//	#pragma vertex vertShadowCaster
		//	#pragma fragment fragShadowCaster

		//	#include "UnityStandardShadow.cginc"

		//	ENDCG
		//}
	}
}