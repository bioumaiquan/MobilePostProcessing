using UnityEngine;
using BioumPostProcess;
#if UNITY_EDITOR
using UnityEditor;
#endif

[DisallowMultipleComponent, ExecuteAlways]
public class PostProcessController : MonoBehaviour
{
    #region post config
    /// <summary>
    /// FXAA抗锯齿
    /// </summary>
    public bool useFXAA = false;

    /// <summary>
    /// bloom
    /// </summary>
    public bool useBloom = false;
    [SerializeField, Range(0,30)]
    float bloomIntensity = 1;
    [SerializeField, Range(1, 8)]
    float bloomDiffusion = 5;
    [SerializeField, Range(0, 4)]
    float bloomThreshold = 1;
    [SerializeField, Range(0, 1)]
    float bloomSoftKnee = 0.6f;

    /// <summary>
    /// 色彩调整
    /// </summary>
    public bool useColorGrading = false;
    [SerializeField]
    Texture2D LutTex2D = null;

    /// <summary>
    /// 色调映射
    /// </summary>
    public bool useToneMapping = false;

    /// <summary>
    /// 用于海底或火焰场景的屏幕扭曲
    /// </summary>
    public bool useScreenDistort = false;
    [SerializeField, Range(0, 1)]
    float distortIntensity = 0.1f;
    [SerializeField, Range(0, 1)]
    float distortSpeedX = 0.0f;
    [SerializeField, Range(0, 1)]
    float distortSpeedY = 0.1f;
    [SerializeField, Min(0)]
    float distortDensity = 1f;

    /// <summary>
    /// 抓取深度缓冲, 用于其他需要深度图的shader. 
    /// 取代默认管线的深度图, 消耗很低.
    /// </summary>
    public bool useDepthTexture = false;
    /// <summary>
    /// 抓取颜色缓冲, 取代GrabPass, 用于折射, 屏幕扭曲等特效. 
    /// 比GrabPass消耗低
    /// </summary>
    public bool useColorTexture = false;
    #endregion

    Camera mainCamera;
    public Camera MainCamera
    {
        set
        {
            if (value != mainCamera)
            {
                mainCamera = value;
                CameraChanged(mainCamera);
            }
        }
    }

    PostProcessBehaviour behaviour;
    [SerializeField]
    PostProcessResources resource;

    bool supportDepthFormat = false;

    private void OnEnable()
    {
#if UNITY_EDITOR
        resource = FindResource();
#endif
        supportDepthFormat = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.R16);
        MainCamera = Camera.main;
        CameraChanged(mainCamera);
    }

    private void LateUpdate()
    {
        if (!resource)
        {
            return;
        }

        if (useDepthTexture && supportDepthFormat)
            Shader.EnableKeyword("CAMERA_DEPTH_TEXTURE");
        else
            Shader.DisableKeyword("CAMERA_DEPTH_TEXTURE");

        if (Check())
        {
            mainCamera.allowHDR = false;
            behaviour.enabled = true;

            behaviour.UseDepthTexture = useDepthTexture;
            behaviour.UseColorTexture = useColorTexture;

            behaviour.UseFXAA = useFXAA;

            behaviour.UseBloom = useBloom;
            behaviour.BloomIntensity = bloomIntensity;
            behaviour.BloomDiffusion = bloomDiffusion;
            behaviour.BloomThreshold = bloomThreshold;
            behaviour.BloomSoftKnee = bloomSoftKnee;

            behaviour.UseColorGrading = useColorGrading;
            behaviour.LutTex2D = LutTex2D;

            behaviour.UseToneMapping = useToneMapping;

            behaviour.UseScreenDistort = useScreenDistort;
            behaviour.DistortIntensity = distortIntensity;
            behaviour.DistortSpeedX = distortSpeedX;
            behaviour.DistortSpeedY = distortSpeedY;
            behaviour.DistortDensity = distortDensity;
        }
        else
        {
            mainCamera.allowHDR = true;
            CleanUp();
        }
    }

#if UNITY_EDITOR
    PostProcessResources FindResource()
    {
        PostProcessResources resource;
        string[] guid = AssetDatabase.FindAssets("PostProcessResource");
        //string path = "Assets/ArtScriptsAndShaders/BioumPostProcessing/PostProcessResource.asset";
        string path = AssetDatabase.GUIDToAssetPath(guid[0]);
        resource = AssetDatabase.LoadAssetAtPath<PostProcessResources>(path);
        if (!resource)
        {
            throw new System.Exception("找不到后处理资源引用文件");
        }

        return resource;
    }
#endif

    void CameraChanged(Camera camera)
    {
        behaviour = camera.GetComponent<PostProcessBehaviour>() ?? camera.gameObject.AddComponent<PostProcessBehaviour>();
        behaviour.Resource = resource;
    }

    bool Check()
    {
        bool needPost = false;

        needPost |= useBloom;
        needPost |= useColorGrading;
        needPost |= useScreenDistort;
        needPost |= useToneMapping;
        needPost |= useDepthTexture;
        needPost |= useColorTexture;
        needPost |= useFXAA;

        needPost &= mainCamera != null;

        return needPost;
    }

    void CleanUp()
    {
        if (behaviour)
        {
            behaviour.enabled = false;
        }
    }
}
