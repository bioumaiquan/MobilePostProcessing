using UnityEngine;

namespace BioumPostProcess
{
    public class ColorGrading
    {
        public void Render(bool colorGrading, Material uberMat, Texture2D lut)
        {
            if (!colorGrading || !lut)
            {
                uberMat.DisableKeyword("COLOR_GRADING_LDR_2D");
                return;
            }

            uberMat.EnableKeyword("COLOR_GRADING_LDR_2D");
            uberMat.SetVector(ShaderIDs.Lut2D_Params, new Vector3(1f / lut.width, 1f / lut.height, lut.height - 1f));
            uberMat.SetTexture(ShaderIDs.Lut2D, lut);
        }
    }
}
