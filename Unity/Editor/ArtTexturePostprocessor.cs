// ArtTexturePostprocessor.cs — настройки импорта текстур T_* из 3ds Max (Docs/ASSET_RULES.md, Docs/UNITY_SHOWCASE_CHECKLIST.md п.3).
// Срабатывает только при ПЕРВОМ импорте файла в Assets/Art, Assets/NPC или Assets/Weapons (importSettingsMissing): ручные правки в инспекторе не перетираются.
// Assets/NPC и Assets/Weapons добавлены 19.11.2026: там лежат боты (Bot#N) и оружие.
//   T_*_Normal                      -> Texture Type = Normal map
//   T_*_Roughness / _Metallic / _AO / _Height / _Mask / _Opacity -> sRGB выключен (это данные, а не цвет)
using UnityEditor;

public class ArtTexturePostprocessor : AssetPostprocessor
{
    static readonly string[] LinearSuffixes = { "_roughness", "_metallic", "_metalness", "_ao", "_height", "_mask", "_opacity" };
    static readonly string[] Roots = { "Assets/Art/", "Assets/NPC/", "Assets/Weapons/" };

    static bool InRoots(string path)
    {
        foreach (var r in Roots)
            if (path.StartsWith(r)) return true;
        return false;
    }

    void OnPreprocessTexture()
    {
        if (!InRoots(assetPath) || !assetImporter.importSettingsMissing) return;
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
