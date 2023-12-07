using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PBRObject : MonoBehaviour
{
    Material[] mats;
    // Start is called before the first frame update
    IEnumerator Start()
    {
        mats = GetComponent<Renderer>().materials;

        while (RenderFramework.Instance() == null)
            yield return null;

        foreach(Material mat in mats)
        {
            mat.SetTexture("_CubeTex", RenderFramework.Instance().Cubemap);
            mat.SetTexture("_BRDFTex", RenderFramework.Instance().BRDF);
        }
    }

    // Update is called once per frame
    void Update()
    {
        foreach (Material mat in mats)
        {
            mat.SetMatrix("_ObjectToWorld", transform.localToWorldMatrix);
            mat.SetMatrix("_WorldToObject", transform.worldToLocalMatrix);
        }
    }
}
