using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class RenderFramework : MonoBehaviour
{
    [SerializeField]
    int sampleSize = 512;
    [SerializeField]
    int threadCount = 8;

    [SerializeField]
    int shcCount = 9;

    [SerializeField]
    ComputeShader computeShader;

    [SerializeField]
    Light directionalLight;

    [SerializeField]
    Cubemap cubemap;

    [SerializeField]
    List<Vector4> sh9;

    Camera cam;

    // Start is called before the first frame update
    void Start()
    {
        InitCamera();
        InitCubemap();
    }

    void OnEnable()
    {
        InitCamera();
        InitCubemap();
    }

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
        FromCubeMapAsync(cubemap, _sh9 => 
        {
            sh9 = new List<Vector4>(_sh9);
            Shader.SetGlobalVectorArray("_SH9", sh9);
        });
    }

    public AsyncGPUReadbackRequest FromCubeMapAsync(Cubemap cubemap, System.Action<Vector4[]> callback)
    {
        int groupCount = sampleSize / threadCount;
        ComputeBuffer shcBuffer = new ComputeBuffer(groupCount * groupCount * shcCount, 16);
        computeShader.SetTexture(0, "_CubeMap", cubemap);
        computeShader.SetBuffer(0, "_ShcBuffer", shcBuffer);
        computeShader.SetInts("_SampleSize", sampleSize, sampleSize);
        computeShader.Dispatch(0, groupCount, groupCount, 1);
        return AsyncGPUReadback.Request(shcBuffer, (req) => 
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
}
