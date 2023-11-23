using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PBRObject : MonoBehaviour
{
    Material mat;
    // Start is called before the first frame update
    IEnumerator Start()
    {
        mat = GetComponent<Renderer>().material;

        while (RenderFramework.Instance() == null)
            yield return null;

        mat.SetTexture("_CubeTex", RenderFramework.Instance().Cubemap);
        mat.SetTexture("_BRDFTex", RenderFramework.Instance().BRDF);
        
    }

    // Update is called once per frame
    void Update()
    {
        mat.SetMatrix("_ObjectToWorld", transform.localToWorldMatrix);
        mat.SetMatrix("_WorldToObject", transform.worldToLocalMatrix);
    }
}
