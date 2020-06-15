using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace BioumPostProcess
{
    public class Bloom
    {
        // [down,up]
        Level[] m_Pyramid;
        const int k_MaxPyramidSize = 6; 

        struct Level
        {
            internal int down;
            internal int up;
        }

        public Bloom()
        {
            m_Pyramid = new Level[k_MaxPyramidSize];

            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                m_Pyramid[i] = new Level
                {
                    down = Shader.PropertyToID("_BloomMipDown" + i),
                    up = Shader.PropertyToID("_BloomMipUp" + i)
                };
            }
        }


        Material bloomMat;
        float intensity, threshold, diffusion, softKnee;
        public void UpdateSettings( float intensity = 1, float threshold = 1, float diffusion = 4, float softKnee = 0.5f)
        {
            this.intensity = intensity;
            this.threshold = threshold;
            this.diffusion = diffusion;
            this.softKnee = softKnee;
        }

        public void Render(MaterialFactory materialFactory, Shader shader, bool bloom, CommandBuffer cmd, 
            RenderTargetIdentifier source, Material uberMat, int sourceWidth, int sourceHeight, RenderTextureFormat rtFormat)
        {
            if (intensity <= 0.01f || !bloom)
            {
                uberMat.DisableKeyword("BLOOM");
                return;
            }

            bloomMat = materialFactory.Get(shader);

            cmd.BeginSample("Bloom");

            // 从半分辨率RT开始
            int tw = sourceWidth >> 1;
            int th = sourceHeight >> 1;

            // 计算迭代次数
            int s = Mathf.Max(tw, th);
            float logs = Mathf.Log(s, 2f) + Mathf.Min(diffusion, 10f) - 10f;
            int logs_i = Mathf.FloorToInt(logs);
            int iterations = Mathf.Clamp(logs_i, 1, k_MaxPyramidSize);
            float sampleScale = 0.5f + logs - logs_i;
            bloomMat.SetFloat(ShaderIDs.SampleScale, sampleScale);

            // 设置预过滤参数, 用于提取画面中高于阈值的亮度
            float lthresh = Mathf.GammaToLinearSpace(threshold);
            float knee = lthresh * softKnee + 1e-5f;
            Vector4 thresholdV = new Vector4(lthresh, lthresh - knee, knee * 2f, 0.25f / knee);
            bloomMat.SetVector(ShaderIDs.Threshold, thresholdV);

            // 使用连续降采样+升采样的方式进行模糊
            // 降采样, 第一次循环为预过滤pass
            var lastDown = source;
            for (int i = 0; i < iterations; i++)
            {
                int mipDown = m_Pyramid[i].down;
                int mipUp = m_Pyramid[i].up;
                int pass = (i == 0) ? 0 : 1;

                cmd.GetTemporaryRT(mipDown, tw >> i, th >> i, 0, FilterMode.Bilinear, rtFormat);
                cmd.GetTemporaryRT(mipUp, tw >> i, th >> i, 0, FilterMode.Bilinear, rtFormat);

                cmd.BlitColorWithFullScreenTriangle(lastDown, mipDown, bloomMat, pass);

                lastDown = mipDown;
            }
            // 升采样
            int lastUp = m_Pyramid[iterations - 1].down;
            for (int i = iterations - 2; i >= 0; i--)
            {
                int mipDown = m_Pyramid[i].down;
                int mipUp = m_Pyramid[i].up;

                cmd.SetGlobalTexture(ShaderIDs.BloomTex, mipDown);
                cmd.BlitColorWithFullScreenTriangle(lastUp, mipUp, bloomMat, 2);
                lastUp = mipUp;
            }

            // 给Uber传递bloom结果
            uberMat.EnableKeyword("BLOOM");
            intensity = RuntimeUtilities.Exp2(intensity / 10f) - 1f;
            uberMat.SetFloat(ShaderIDs.BloomIntensity, intensity);
            uberMat.SetFloat(ShaderIDs.SampleScale, sampleScale);
            cmd.SetGlobalTexture(ShaderIDs.BloomTex, lastUp);

            // 释放rt
            for (int i = 0; i < iterations; i++)
            {
                if (m_Pyramid[i].down != lastUp)
                    cmd.ReleaseTemporaryRT(m_Pyramid[i].down);
                if (m_Pyramid[i].up != lastUp)
                    cmd.ReleaseTemporaryRT(m_Pyramid[i].up);
            }

            cmd.EndSample("Bloom");
        }
    }
}
