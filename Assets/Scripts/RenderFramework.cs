using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

public class RenderFramework : MonoBehaviour
{
    [Header("SH9")]

    [SerializeField]
    ComputeShader sh9GeneratorCS;
    [SerializeField]
    ComputeShader sh9ReconstructorCS;

    [SerializeField]
    Cubemap cubemap;
    [SerializeField]
    RenderTexture sh9Cubemap;

    [SerializeField]
    List<Vector4> sh9;

    [SerializeField]
    int sampleSize = 512;

    const int threadCount = 8;
    const int shcCount = 9;

    [Header("Scene Setup")]

    [SerializeField]
    Light directionalLight;

    Camera cam;

    // Start is called before the first frame update
    void Start()
    {
        InitCamera();
        InitCubemap();
    }

    //void OnEnable()
    //{
    //    InitCamera();
    //    InitCubemap();
    //}

    // Update is called once per frame
    void Update()
    {
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(cam.projectionMatrix, true);
        Shader.SetGlobalMatrix("_ViewToProjection", projectionMatrix * cam.worldToCameraMatrix);
        Shader.SetGlobalVector("_CameraWorldSpace", cam.transform.position);
        Shader.SetGlobalVector("_DirectionalLightWorldSpace", directionalLight.transform.forward);
        Shader.SetGlobalVector("_DirectionalLightColor", directionalLight.color * directionalLight.intensity);
    }

    void InitCamera()
    {
        cam = GetComponent<Camera>();
    }

    void InitCubemap()
    {
        Sh9GeneratorAsync(cubemap, _sh9 => 
        {
            sh9 = new List<Vector4>(_sh9);
            Shader.SetGlobalVectorArray("_SH9", sh9);

            // display low frequency cubemap
            Sh9ReconstructorAsync(_sh9, _rt => 
            {
                sh9Cubemap = _rt;
                Debug.Log("Sh9 ReconstructorAsync is done!");
            });
        });
    }

    public AsyncGPUReadbackRequest Sh9GeneratorAsync(Cubemap cubemap, System.Action<Vector4[]> callback)
    {
        int groupCount = sampleSize / threadCount;
        ComputeBuffer shcBuffer = new ComputeBuffer(groupCount * groupCount * shcCount, 16);
        sh9GeneratorCS.SetTexture(0, "_Cubemap", cubemap);
        sh9GeneratorCS.SetBuffer(0, "_ShcBuffer", shcBuffer);
        sh9GeneratorCS.SetInts("_SampleSize", sampleSize, sampleSize);
        sh9GeneratorCS.Dispatch(0, groupCount, groupCount, 1);
        return AsyncGPUReadback.Request(shcBuffer, req => 
        {
            if (req.hasError)
            {
                Debug.LogError("sh project with gpu error");
                shcBuffer.Release();
                callback(null);
                return;
            }

            Unity.Collections.NativeArray<Vector4> shcArray = req.GetData<Vector4>();
            int count = shcArray.Length / shcCount;
            Vector4[] shcs = new Vector4[shcCount];
            for (var i = 0; i < count; i++)
            {
                for (var offset = 0; offset < shcCount; offset++)
                {
                    shcs[offset] += shcArray[i * shcCount + offset];
                }
            }
            shcBuffer.Release();
            callback(shcs);
        });
    }

    AsyncGPUReadbackRequest Sh9ReconstructorAsync(Vector4[] sh9, System.Action<RenderTexture> callback)
    {
        // sRGB color space
        RenderTexture rt = new RenderTexture(sampleSize * 4, sampleSize * 3, 0, RenderTextureFormat.ARGB32);
        rt.enableRandomWrite = true;
        rt.Create();

        int groupCount = sampleSize / threadCount;

        sh9ReconstructorCS.SetVectorArray("_SH9", sh9);
        sh9ReconstructorCS.SetTexture(0, "_Cubemap", rt);
        sh9ReconstructorCS.SetInt("_FaceSize", sampleSize);
        sh9ReconstructorCS.Dispatch(0, groupCount, groupCount, 6);
        return AsyncGPUReadback.Request(rt, 0, 0, rt.width, 0, rt.height, 0, 1, res => 
        {
            if (res.hasError)
            {
                Debug.LogError("sh9 reconstruct with gpu error");
            }
            callback(rt);
        });
    }
}
