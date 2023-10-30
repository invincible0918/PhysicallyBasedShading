using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RenderFramework : MonoBehaviour
{
    [SerializeField]
    Light directionalLight;
    Camera cam;
    // Start is called before the first frame update
    void Start()
    {
        Init();
    }

    void OnEnable()
    {
        Init();
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

    void Init()
    {
        cam = GetComponent<Camera>();
    }
}
