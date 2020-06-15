using System.Collections;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace BioumPostProcess
{
    public class MaterialFactory
    {
        readonly Dictionary<Shader, Material> m_Materials;

        public MaterialFactory()
        {
            m_Materials = new Dictionary<Shader, Material>();
        }

        public Material Get(Shader shader)
        {
            Material mat;

            if (shader == null)
                throw new ArgumentException(string.Format("Invalid shader ({0})", shader));

            if (m_Materials.TryGetValue(shader, out mat))
                return mat;

            string shaderName = shader.name;
            Material material = new Material(shader)
            {
                name = string.Format("PostProcess - {0}", shaderName.Substring(shaderName.LastIndexOf('/') + 1)),
                hideFlags = HideFlags.DontSave
            };

            m_Materials.Add(shader, material);
            return material;
        }

        public void CleanUp()
        {
            foreach (var mat in m_Materials.Values)
                RuntimeUtilities.Destroy(mat);

            m_Materials.Clear();
        }
    }
}
