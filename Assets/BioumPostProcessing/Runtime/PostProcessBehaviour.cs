using UnityEngine;
using UnityEngine.Rendering;

namespace BioumPostProcess
{
    [ExecuteAlways, DisallowMultipleComponent, RequireComponent(typeof(Camera))]
    public class PostProcessBehaviour : MonoBehaviour
    {
        Camera m_Camera;
        int m_Width, m_Height;
        CommandBuffer beforImageEffect;
        CommandBuffer afterOpaque;
        RenderTexture cameraColorTarget;
        RenderTexture cameraDepthTarget;
        Material uberMat, fxaaMat;
        MaterialFactory materialFactory;

        bool useDepthTexture = false;
        public bool UseDepthTexture
        {
            get { return useDepthTexture; }
            set
            {
                if (useDepthTexture != value)
                {
                    useDepthTexture = value;
                    InitCameraColorTarget(useDepthTexture ? 0 : 24);
                    InitCameraDepthTarget();
                }
            }
        }

        public bool UseColorTexture { get; set; }

        public bool UseFXAA { get; set; }

        public bool UseBloom { get; set; }
        Bloom bloom;
        RenderTextureFormat hdrFormat = RenderTextureFormat.ARGB32;
        [HideInInspector]
        public float BloomIntensity = 1, BloomThreshold = 1, BloomDiffusion = 5, BloomSoftKnee = 0.5f;

        ColorGrading colorGrading;
        [HideInInspector]
        public Texture2D LutTex2D;
        public bool UseToneMapping { get; set; }
        public bool UseColorGrading { get; set; }

        ScreenDistort screenDistort;
        public bool UseScreenDistort { get; set; }
        [HideInInspector]
        public float DistortIntensity = 0.1f, DistortSpeedX = 0, DistortSpeedY = 0.1f, DistortDensity = 1;

        [HideInInspector]
        public PostProcessResources Resource;


        private void OnEnable()
        {
            if (materialFactory == null)
                materialFactory = new MaterialFactory();

            if (bloom == null)
                bloom = new Bloom();

            if (colorGrading == null)
                colorGrading = new ColorGrading();

            if (screenDistort == null)
                screenDistort = new ScreenDistort();

            Init();
        }

        private void OnDisable()
        {
            CleanUp();
        }

        private void OnPreCull()
        {
            if (m_Width != m_Camera.pixelWidth || m_Height != m_Camera.pixelHeight)
            {
                m_Width = m_Camera.pixelWidth;
                m_Height = m_Camera.pixelHeight;
                InitCameraColorTarget(useDepthTexture ? 0 : 24);
                InitCameraDepthTarget();
            }
            RuntimeUtilities.UpdateMat(Resource.copyColor, Resource.copyDepth);
        }

        private void OnPreRender()
        {
            SetRenderTarget();
            BuildCommandBuffer();
        }

        private void OnPostRender()
        {
            m_Camera.targetTexture = null;
        }

        void Init()
        {
            m_Camera = GetComponent<Camera>();
            m_Camera.allowMSAA = false;  //会和后处理冲突
            m_Width = m_Camera.pixelWidth;
            m_Height = m_Camera.pixelHeight;

            if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf))
            {
                hdrFormat = RenderTextureFormat.ARGBHalf;
            }
            else if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGB2101010))
            {
                hdrFormat = RenderTextureFormat.ARGB2101010;
            }

            InitCameraColorTarget(24);
            InitCameraDepthTarget();

            beforImageEffect = new CommandBuffer() { name = "PostProcess Before ImageEffect" };
            m_Camera.AddCommandBuffer(CameraEvent.BeforeImageEffects, beforImageEffect);

            afterOpaque = new CommandBuffer() { name = "PostProcess After Opaque" };
            m_Camera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, afterOpaque);

            RuntimeUtilities.InitializeStatic();
        }

        void SetRenderTarget()
        {
            if (useDepthTexture)
            {
                m_Camera.SetTargetBuffers(cameraColorTarget.colorBuffer, cameraDepthTarget.depthBuffer);
            }
            else
            {
                m_Camera.SetTargetBuffers(cameraColorTarget.colorBuffer, cameraColorTarget.depthBuffer);
            }
        }
        void InitCameraColorTarget(int depthBit)
        {
            RuntimeUtilities.Destroy(cameraColorTarget);

            cameraColorTarget = new RenderTexture(m_Width, m_Height, depthBit, hdrFormat)
            {
                name = "Post Process Camera Color Target",
                filterMode = FilterMode.Bilinear,
            };
            cameraColorTarget.Create();
        }
        void InitCameraDepthTarget()
        {
            RuntimeUtilities.Destroy(cameraDepthTarget);

            if (!useDepthTexture)
            {
                return;
            }

            cameraDepthTarget = new RenderTexture(m_Width, m_Height, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear)
            {
                name = "Post Process Camera Depth Target",
                filterMode = FilterMode.Point,
            };
            cameraDepthTarget.Create();
        }

        void CleanUp()
        {
            if (beforImageEffect != null)
                m_Camera.RemoveCommandBuffer(CameraEvent.BeforeImageEffects, beforImageEffect);
            if (afterOpaque != null)
                m_Camera.RemoveCommandBuffer(CameraEvent.AfterForwardOpaque, afterOpaque);

            RuntimeUtilities.Destroy(cameraColorTarget);
            RuntimeUtilities.Destroy(cameraDepthTarget);

            materialFactory?.CleanUp();
        }


        //后处理CommandBuffer
        void BuildCommandBuffer()
        {
            afterOpaque.Clear();
            //抓取深度图
            if (useDepthTexture)
            {
                afterOpaque.BeginSample("Copy Depth");
                afterOpaque.GetTemporaryRT(ShaderIDs.CameraDepthTex, m_Width, m_Height, 0, FilterMode.Point, RenderTextureFormat.R16);

                afterOpaque.CopyDepthTexture(cameraDepthTarget.depthBuffer, ShaderIDs.CameraDepthTex, RuntimeUtilities.copyDepthMat);
                afterOpaque.SetGlobalTexture(ShaderIDs.CameraDepthTex, ShaderIDs.CameraDepthTex);

                afterOpaque.ReleaseTemporaryRT(ShaderIDs.CameraDepthTex);
                afterOpaque.EndSample("Copy Depth");
            }
            //抓取颜色图
            if (UseColorTexture)
            {
                afterOpaque.BeginSample("Copy Color");
                afterOpaque.GetTemporaryRT(ShaderIDs.CameraColorTex, m_Width, m_Height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);

                afterOpaque.CopyColorTexture(cameraColorTarget.colorBuffer, ShaderIDs.CameraColorTex, RuntimeUtilities.copyColorMat);
                afterOpaque.SetGlobalTexture(ShaderIDs.CameraColorTex, ShaderIDs.CameraColorTex);

                afterOpaque.ReleaseTemporaryRT(ShaderIDs.CameraColorTex);
                afterOpaque.EndSample("Copy Color");
            }

            //后处理
            beforImageEffect.Clear();
            uberMat = materialFactory.Get(Resource.uber);

            bloom.UpdateSettings(BloomIntensity, BloomThreshold, BloomDiffusion, BloomSoftKnee);
            bloom.Render(materialFactory, Resource.bloom, UseBloom, beforImageEffect, cameraColorTarget, uberMat, m_Width, m_Height, hdrFormat);
            colorGrading.Render(UseColorGrading, uberMat, LutTex2D);
            screenDistort.Render(UseScreenDistort, uberMat, DistortIntensity, DistortSpeedX, DistortSpeedY, DistortDensity, Resource.distortTex);

            //混合后处理结果
            beforImageEffect.BeginSample("Uber");
            if (UseToneMapping)
                uberMat.EnableKeyword("ACES_TONEMAPPING");
            else
                uberMat.DisableKeyword("ACES_TONEMAPPING");

            //抗锯齿
            if (UseFXAA)
            {
                uberMat.SetFloat(ShaderIDs.UseFXAA, 1);
                fxaaMat = materialFactory.Get(Resource.fxaa);
                beforImageEffect.GetTemporaryRT(ShaderIDs.FXAASourceTex, m_Width, m_Height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
                beforImageEffect.BlitColorWithFullScreenTriangle(cameraColorTarget, ShaderIDs.FXAASourceTex, uberMat, 1);
                beforImageEffect.EndSample("Uber");

                beforImageEffect.BeginSample("FXAA");
                beforImageEffect.BlitColorWithFullScreenTriangle(ShaderIDs.FXAASourceTex, BuiltinRenderTextureType.CameraTarget, fxaaMat, 0);
                beforImageEffect.ReleaseTemporaryRT(ShaderIDs.FXAASourceTex);
                beforImageEffect.EndSample("FXAA");
            }
            else
            {
                uberMat.SetFloat(ShaderIDs.UseFXAA, 0);
                beforImageEffect.BlitColorWithFullScreenTriangle(cameraColorTarget, BuiltinRenderTextureType.CameraTarget, uberMat, 0);
                beforImageEffect.EndSample("Uber");
            }

        }
    }
}
