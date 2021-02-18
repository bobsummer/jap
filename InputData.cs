using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Jap
{
    [ExecuteInEditMode]
    public class InputData : MonoBehaviour
    {
        // Update is called once per frame
        void Update()
        {
            Camera camNow = Camera.main;
            Shader.SetGlobalVector("cur_cameraRight", camNow.transform.right);
            Shader.SetGlobalVector("cur_cameraForward", camNow.transform.forward);
            Shader.SetGlobalVector("cur_cameraUp", camNow.transform.up);
        }
    }
}
