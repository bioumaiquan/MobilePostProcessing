using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Assertions;
using System;

[CustomEditor(typeof(PostProcessController))]
public class PostProcessControllerEditor : Editor
{
    static class Styles
    {
        public static GUIContent bloomEnable = new GUIContent("辉光");
        public static GUIContent bloomDiffusion = new GUIContent("扩散范围(越高越耗)");
        public static GUIContent bloomIntensity = new GUIContent("强度");
        public static GUIContent bloomThreshold = new GUIContent("阈值");
        public static GUIContent bloomSoftKnee = new GUIContent("散射");

        public static GUIContent ColorLutEnable = new GUIContent("色彩调整");
        public static GUIContent ColorLutTex = new GUIContent("LUT");
        public static GUIContent ToneMapping = new GUIContent("TongMapping(色调映射)");

        public static GUIContent DistortEnable = new GUIContent("场景扭曲(水下/火焰场景)");
        public static GUIContent DistortIntensity = new GUIContent("扭曲强度");
        public static GUIContent DistortSpeedX = new GUIContent("速度 X");
        public static GUIContent DistortSpeedY = new GUIContent("速度 Y");
        public static GUIContent DistortDensity = new GUIContent("扭曲密度");

        public static GUIContent DepthTexture = new GUIContent("抓取深度图");
        public static GUIContent ColorTexture = new GUIContent("抓取颜色图");

        public static GUIContent FXAA = new GUIContent("抗锯齿");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.Space();

        EditorGUILayout.PropertyField(serializedObject.FindProperty("useFXAA"), Styles.FXAA);
        EditorGUILayout.Space();

        BloomGUI();
        EditorGUILayout.Space();

        EditorGUILayout.PropertyField(serializedObject.FindProperty("useToneMapping"), Styles.ToneMapping);
        EditorGUILayout.Space();

        ColorGradingGUI();
        EditorGUILayout.Space();

        DistortGUI();
        EditorGUILayout.Space();

        EditorGUILayout.PropertyField(serializedObject.FindProperty("useDepthTexture"), Styles.DepthTexture);
        EditorGUILayout.Space();
        EditorGUILayout.PropertyField(serializedObject.FindProperty("useColorTexture"), Styles.ColorTexture);
        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }

    void BloomGUI()
    {
        SerializedProperty bloomToggle = serializedObject.FindProperty("useBloom");
        EditorGUILayout.PropertyField(bloomToggle, Styles.bloomEnable);

        EditorGUI.indentLevel++;
        if (bloomToggle.boolValue)
        {
            EditorGUILayout.PropertyField(serializedObject.FindProperty("bloomDiffusion"), Styles.bloomDiffusion);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("bloomIntensity"), Styles.bloomIntensity);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("bloomThreshold"), Styles.bloomThreshold);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("bloomSoftKnee"), Styles.bloomSoftKnee);
        }
        EditorGUI.indentLevel--;
    }

    void DistortGUI()
    {
        SerializedProperty distortToggle = serializedObject.FindProperty("useScreenDistort");
        EditorGUILayout.PropertyField(distortToggle, Styles.DistortEnable);

        EditorGUI.indentLevel++;
        if (distortToggle.boolValue)
        {
            EditorGUILayout.PropertyField(serializedObject.FindProperty("distortIntensity"), Styles.DistortIntensity);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("distortDensity"), Styles.DistortDensity);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("distortSpeedX"), Styles.DistortSpeedX);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("distortSpeedY"), Styles.DistortSpeedY);
        }
        EditorGUI.indentLevel--;
    }

    void ColorGradingGUI()
    {
        SerializedProperty colorLutToggle = serializedObject.FindProperty("useColorGrading");
        EditorGUILayout.PropertyField(colorLutToggle, Styles.ColorLutEnable);

        EditorGUI.indentLevel++;
        if (colorLutToggle.boolValue)
        {
            SerializedProperty Lut2DTex = serializedObject.FindProperty("LutTex2D");
            EditorGUILayout.PropertyField(Lut2DTex, Styles.ColorLutTex);

            if (Lut2DTex.objectReferenceValue != null)
            {
                var importer = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(Lut2DTex.objectReferenceValue)) as TextureImporter;

                // Fails when using an internal texture as you can't change import settings on
                // builtin resources, thus the check for null
                if (importer != null)
                {
                    bool valid = importer.anisoLevel == 0
                        && importer.mipmapEnabled == false
                        && importer.sRGBTexture == false
                        && importer.textureCompression == TextureImporterCompression.Uncompressed
                        && importer.wrapMode == TextureWrapMode.Clamp;

                    if (!valid)
                        DrawFixMeBox("贴图导入设置不正确", () => SetLutImportSettings(importer));
                }

                //if (lut.width != lut.height * lut.height)
                //{
                //    EditorGUILayout.HelpBox("The Lookup Texture size is invalid. Width should be Height * Height.", MessageType.Error);
                //}
            }
        }
        EditorGUI.indentLevel--;
    }
    public static void DrawFixMeBox(string text, Action action)
    {
        Assert.IsNotNull(action);

        EditorGUILayout.HelpBox(text, MessageType.Warning);

        GUILayout.Space(-32);
        using (new EditorGUILayout.HorizontalScope())
        {
            GUILayout.FlexibleSpace();

            if (GUILayout.Button("修复", GUILayout.Width(60)))
                action();

            GUILayout.Space(8);
        }
        GUILayout.Space(11);
    }

    void SetLutImportSettings(TextureImporter importer)
    {
        importer.textureType = TextureImporterType.Default;
        importer.mipmapEnabled = false;
        importer.anisoLevel = 0;
        importer.sRGBTexture = false;
        importer.npotScale = TextureImporterNPOTScale.None;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.alphaSource = TextureImporterAlphaSource.None;
        importer.wrapMode = TextureWrapMode.Clamp;
        importer.SaveAndReimport();
        AssetDatabase.Refresh();
    }
}
