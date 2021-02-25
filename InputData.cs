using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Jap
{
    [ExecuteInEditMode]
    public class InputData : MonoBehaviour
    {
        public Transform m_Jaw = null;

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
            //Matrix4x4 mtx_root = transform.localToWorldMatrix;

            if(m_Jaw!=null)
			{                
                Matrix4x4 mtx_jaw = m_Jaw.worldToLocalMatrix;
				Shader.SetGlobalMatrix("_JawTransform", mtx_jaw);
			}
        }
    }
}
