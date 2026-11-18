// ArtTexturePostprocessor.cs — настройки импорта текстур T_* из 3ds Max (Docs/ASSET_RULES.md, Docs/UNITY_SHOWCASE_CHECKLIST.md п.3).
// Срабатывает только при ПЕРВОМ импорте файла в Assets/Art (importSettingsMissing): ручные правки в инспекторе не перетираются.
//   T_*_Normal                      -> Texture Type = Normal map
//   T_*_Roughness / _Metallic / _AO / _Height / _Mask / _Opacity -> sRGB выключен (это данные, а не цвет)
using UnityEditor;

public class ArtTexturePostprocessor : AssetPostprocessor
{
    static readonly string[] LinearSuffixes = { "_roughness", "_metallic", "_metalness", "_ao", "_height", "_mask", "_opacity" };

    void OnPreprocessTexture()
    {
        if (!assetPath.StartsWith("Assets/Art/") || !assetImporter.importSettingsMissing) return;
        string name = System.IO.Path.GetFileNameWithoutExtension(assetPath);
        if (!name.StartsWith("T_")) return;
        string lower = name.ToLowerInvariant();
        var ti = (TextureImporter)assetImporter;

        if (lower.EndsWith("_normal"))
        {
            ti.textureType = TextureImporterType.NormalMap;
            return;
        }
        foreach (var s in LinearSuffixes)
            if (lower.EndsWith(s)) { ti.sRGBTexture = false; return; }
    }
}
