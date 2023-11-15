using System.Collections;
using System.Linq;
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
    const int sh9Count = 9;

    Dictionary<int, int> faceCalculate = new Dictionary<int, int>();

    [Header("Scene Setup")]

    [SerializeField]
    Light directionalLight;

    Camera cam;

    //List<Vector3> debugPoints;
    List<Color> debugColors;
    [SerializeField]
    RenderTexture debugCubemap;

    // Start is called before the first frame update
    void Start()
    {
        InitCamera();
        //InitCubemap();
        InitSphericalHarmonic();
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
        ComputeBuffer shcBuffer = new ComputeBuffer(groupCount * groupCount * sh9Count, 16);
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
            int count = shcArray.Length / sh9Count;
            Vector4[] shcs = new Vector4[sh9Count];
            for (var i = 0; i < count; i++)
            {
                for (var offset = 0; offset < sh9Count; offset++)
                {
                    shcs[offset] += shcArray[i * sh9Count + offset];
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
        sh9ReconstructorCS.SetVectorArray("colors", (from color in debugColors select new Vector4(color.r, color.g, color.b, color.a)).ToArray());
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

    void InitSphericalHarmonic()
    {
        Vector4[] coefs = new Vector4[sh9Count];
        //debugPoints = new List<Vector3>();
        debugColors = new List<Color>();

        int sampleNum = 10000;
        faceCalculate.Add(0, 0);
        faceCalculate.Add(1, 0);
        faceCalculate.Add(2, 0);
        faceCalculate.Add(3, 0);
        faceCalculate.Add(4, 0);
        faceCalculate.Add(5, 0);
        for (int i = 0; i < sampleNum; i++)
        {
            var p = RandomCubePos();
            var h = HarmonicsBasis(p);
            var c = GetCubeColor(p);
            for (int t = 0; t < sh9Count; t++)
            {
                coefs[t] = coefs[t] + h[t] * c;
            }
            //debugPoints.Add(p);
            debugColors.Add(c);
        }
        for (int t = 0; t < sh9Count; t++)
        {
            coefs[t] = 4.0f * Mathf.PI * coefs[t] / (sampleNum * 1.0f);
        }

        sh9 = new List<Vector4>(coefs);

        Sh9ReconstructorAsync(coefs, _rt =>
        {
            sh9Cubemap = _rt;
            Debug.Log("Sh9 ReconstructorAsync is done!");
        });

        debugCubemap = new RenderTexture(sampleSize * 4, sampleSize * 3, 0, RenderTextureFormat.ARGB32);
        debugCubemap.enableRandomWrite = true;
        debugCubemap.Create();

        debugCubemap.
    }

    Vector3 RandomCubePos()
    {
        Vector3 pos = Random.onUnitSphere;
        return pos;
    }

    List<float> HarmonicsBasis(Vector3 pos)
    {
        Vector3 normal = pos.normalized;
        float x = normal.x;
        float y = normal.y;
        float z = normal.z;

        float[] sh = new float[sh9Count];
        sh[0] = 1.0f / 2.0f * Mathf.Sqrt(1.0f / Mathf.PI);
        sh[1] = Mathf.Sqrt(3.0f / (4.0f * Mathf.PI)) * z;
        sh[2] = Mathf.Sqrt(3.0f / (4.0f * Mathf.PI)) * y;
        sh[3] = Mathf.Sqrt(3.0f / (4.0f * Mathf.PI)) * x;
        sh[4] = 1.0f / 2.0f * Mathf.Sqrt(15.0f / Mathf.PI) * x * z;
        sh[5] = 1.0f / 2.0f * Mathf.Sqrt(15.0f / Mathf.PI) * z * y;
        sh[6] = 1.0f / 4.0f * Mathf.Sqrt(5.0f / Mathf.PI) * (-x * x - z * z + 2 * y * y);
        sh[7] = 1.0f / 2.0f * Mathf.Sqrt(15.0f / Mathf.PI) * y * x;
        sh[8] = 1.0f / 4.0f * Mathf.Sqrt(15.0f / Mathf.PI) * (x * x - z * z);

        List<float> shList = new List<float>(sh);
        return shList;
    }

    Vector4 GetCubeColor(Vector3 pos)
    {
        Color col = new Color();

        float xabs = pos.x;
        float yabs = pos.y;
        float zabs = pos.z;
        int faceIndex = -1;
        Vector2 uv = new Vector2();
        if (xabs >= yabs && xabs >= zabs)
        {
            //x
            faceIndex = pos.x > 0 ? 0 : 1;
            uv.x = pos.y / xabs;
            uv.y = pos.z / xabs;
        }
        else if (yabs >= xabs && yabs >= zabs)
        {
            //y 
            faceIndex = pos.y > 0 ? 2 : 3;
            uv.x = pos.x / yabs;
            uv.y = pos.z / yabs;
        }
        else
        {
            //z
            faceIndex = pos.z > 0 ? 4 : 5;
            uv.x = pos.x / zabs;
            uv.y = pos.y / zabs;
        }
        //[0,1.0]
        uv.x = (uv.x + 1.0f) / 2.0f;
        uv.y = (uv.y + 1.0f) / 2.0f;
        int w = cubemap.width - 1;
        int x = (int)(w * uv.x);
        int y = (int)(w * uv.y);
        //Debug.Log("random face:" + faceIndex.ToString());
        if (faceCalculate.ContainsKey(faceIndex))
        {
            faceCalculate[faceIndex]++;
        }
        col = cubemap.GetPixel((CubemapFace)faceIndex, x, y);
        Vector4 colVec4 = new Vector4(col.r, col.g, col.b, col.a);
        return colVec4;
    }

    //private void OnDrawGizmos()
    //{
    //    foreach(Vector3 point in debugPoints)
    //    {
    //        Gizmos.DrawWireSphere(point, 0.01f);
    //    }
    //}
}
