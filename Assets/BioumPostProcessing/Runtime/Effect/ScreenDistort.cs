using UnityEngine;

namespace BioumPostProcess
{
    public class ScreenDistort
    {
        public void Render(bool screenDistort, Material uberMat, float intensity, float speedX, float speedY, float density, Texture2D distortTex)
        {
            if (!screenDistort || !distortTex || intensity <= 0.01f)
            {
                uberMat.DisableKeyword("SCREEN_DISTORT");
                return;
            }

            uberMat.EnableKeyword("SCREEN_DISTORT");
            uberMat.SetTexture(ShaderIDs.DistortTex, distortTex);
            uberMat.SetVector(ShaderIDs.DistortParams, new Vector4(speedX, speedY, intensity * 0.05f, density));
        }
    }
}
