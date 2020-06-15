using UnityEngine;

namespace BioumPostProcess
{
    [CreateAssetMenu(menuName = "BioumPost/创建后处理资源引用文件")]
    public sealed class PostProcessResources : ScriptableObject
    {
        public Shader fxaa;
        public Shader bloom;
        public Shader uber;
        public Shader copyColor;
        public Shader copyDepth;

        public Texture2D distortTex;

#if UNITY_EDITOR
        /// <summary>
        /// A delegate used to track resource changes.
        /// </summary>
        public delegate void ChangeHandler();

        /// <summary>
        /// Set this callback to be notified of resource changes.
        /// </summary>
        public ChangeHandler changeHandler;

        void OnValidate()
        {
            if (changeHandler != null)
                changeHandler();
        }
#endif
    }

}
