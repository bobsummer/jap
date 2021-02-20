using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Jap
{
    [ExecuteInEditMode]
    public class InputData : MonoBehaviour
    {
        void OnWillRenderObject()
        {
            Camera camNow = Camera.current;
            Shader.SetGlobalVector("cur_cameraRight", camNow.transform.right);
            Shader.SetGlobalVector("cur_cameraForward", camNow.transform.forward);
            Shader.SetGlobalVector("cur_cameraUp", camNow.transform.up);

            float fov = camNow.fieldOfView;
            fov = fov * 0.5f * Mathf.Deg2Rad;
            float focal_len = 1.0f/Mathf.Tan(fov);

            Shader.SetGlobalFloat("cur_camFocalLen", focal_len);
        }
    }
}
