using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace BioumPostProcess
{
    public static class RuntimeUtilities
    {
        public static Mesh fullScreenTriangle;
        public static Material copyColorMat;
        public static Material copyDepthMat;
        public static void InitializeStatic()
        {
            if (fullScreenTriangle)
                return;

            //构建一个覆盖全屏幕的三角形, 替代默认的矩形, 性能会更好
            fullScreenTriangle = new Mesh
            {
                name = "Post Process FullScreen Triangle",
                vertices = new Vector3[] //坐标为Clip Space
                {
                    new Vector3(-1f, -1f, 0f),
                    new Vector3(-1f, 3f, 0f),
                    new Vector3(3f, -1f, 0f)
                },
            };
            fullScreenTriangle.SetIndices(new[] { 0, 1, 2 }, MeshTopology.Triangles, 0, false);
            fullScreenTriangle.UploadMeshData(true);
        }

        public static void UpdateMat(Shader copyColorShader, Shader copyDepthShader)
        {
            if (!copyColorMat)
            {
                copyColorMat = new Material(copyColorShader)
                {
                    name = "Post Process Copy Color Material",
                    hideFlags = HideFlags.HideAndDontSave,
                };
            }
            if (!copyDepthMat)
            {
                copyDepthMat = new Material(copyDepthShader)
                {
                    name = "Post Process Copy Depth Material",
                    hideFlags = HideFlags.HideAndDontSave,
                };
            }
        }

        public static void BlitColorWithFullScreenTriangle(this CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier dest, Material mat, int pass = 0, bool clear = false)
        {
            cmd.SetGlobalTexture(ShaderIDs.CameraColorTex, source);
            cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            if (clear)
            {
                cmd.ClearRenderTarget(true, true, Color.clear);
            }
            cmd.DrawMesh(fullScreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void CopyColorTexture(this CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier dest, Material mat, int pass = 0, bool clear = false)
        {
            cmd.SetGlobalTexture(ShaderIDs.CameraColorBuffer, source);
            cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            if (clear)
            {
                cmd.ClearRenderTarget(true, true, Color.clear);
            }
            cmd.DrawMesh(fullScreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void CopyDepthTexture(this CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier dest, Material mat, int pass = 0, bool clear = false)
        {
            cmd.SetGlobalTexture(ShaderIDs.CameraDepthBuffer, source);
            cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            if (clear)
            {
                cmd.ClearRenderTarget(true, true, Color.clear);
            }
            cmd.DrawMesh(fullScreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }


        public static void Destroy(Object obj)
        {
            if (obj != null)
            {
#if UNITY_EDITOR
                if (Application.isPlaying)
                    Object.Destroy(obj);
                else
                    Object.DestroyImmediate(obj);
#else
                Object.Destroy(obj);
#endif
            }
        }


        /// <summary>
        /// Returns the base-2 exponential function of <paramref name="x"/>, which is <c>2</c>
        /// raised to the power <paramref name="x"/>.
        /// </summary>
        /// <param name="x">Value of the exponent</param>
        /// <returns>The base-2 exponential function of <paramref name="x"/></returns>
        public static float Exp2(float x)
        {
            return Mathf.Exp(x * 0.69314718055994530941723212145818f);
        }
    }
}
