// ShowcaseBuilder.cs — четверг днём по Стандарту 3D-пайплайна (раздел 2): ассет из Assets/Art/<Asset> -> материал, префаб,
// сцена Assets/Art/Showcase/Showcase.unity и проверка по Docs/UNITY_SHOWCASE_CHECKLIST.md.
// Пакетно (Unity закрыт):
//   Unity.exe -batchmode -projectPath "<проект>" -executeMethod ShowcaseBuilder.BuildBatch -asset Bot6 -report <txt> -shot <png> -logFile <log>
// Вручную: меню Art > Build Showcase (Bot6).
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ShowcaseBuilder
{
    const string ArtRoot = "Assets/Art";
    const string ShowcaseScene = "Assets/Art/Showcase/Showcase.unity";
    const int MaxTris = 15000;
    const int MaxTex = 2048;

    static readonly List<string> importMessages = new List<string>();
    static StringBuilder sb;
    static int fails, warns;

    public static void BuildBatch()
    {
        string asset = Arg("-asset", "Bot6");
        string report = Arg("-report", Path.GetFullPath("AIHub_Report/showcase_" + asset + ".txt"));
        string shot = Arg("-shot", Path.ChangeExtension(report, ".png"));
        int code = 1;
        try { code = Build(asset, report, shot) ? 0 : 2; }
        catch (Exception e)
        {
            Debug.LogException(e);
            File.AppendAllText(report, "\nEXCEPTION: " + e + "\n");
        }
        EditorApplication.Exit(code);
    }

    [MenuItem("Art/Build Showcase (Bot6)")]
    static void BuildMenu()
    {
        string r = Path.GetFullPath("AIHub_Report/showcase_Bot6.txt");
        Build("Bot6", r, Path.ChangeExtension(r, ".png"));
        EditorUtility.RevealInFinder(r);
    }

    static string Arg(string name, string def)
    {
        var a = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(a, name);
        return i >= 0 && i + 1 < a.Length ? a[i + 1] : def;
    }

    static void Line(string kind, string msg)
    {
        sb.AppendLine("[" + kind + "] " + msg);
        if (kind == "FAIL") fails++;
        if (kind == "WARN") warns++;
    }

    static void OnLog(string msg, string stack, LogType type)
    {
        if (type == LogType.Warning || type == LogType.Error || type == LogType.Exception)
            importMessages.Add(type + ": " + msg.Split('\n')[0]);
    }

    public static bool Build(string asset, string reportPath, string shotPath)
    {
        sb = new StringBuilder();
        fails = 0; warns = 0;
        importMessages.Clear();
        string dir = ArtRoot + "/" + asset;
        string texDir = dir + "/Textures";
        sb.AppendLine("=== Showcase " + asset + " — Unity " + Application.unityVersion + " — " + DateTime.Now.ToString("dd.MM.yyyy HH:mm") + " ===");

        AssetDatabase.Refresh();
        string fbx = Directory.GetFiles(dir, "*.fbx").Select(p => p.Replace('\\', '/')).FirstOrDefault();
        if (fbx == null) { Line("FAIL", "нет FBX в " + dir); return Finish(reportPath); }

        // --- импорт с перехватом предупреждений
        Application.logMessageReceived += OnLog;
        try
        {
            foreach (var t in Directory.GetFiles(texDir, "T_*.png").Select(p => p.Replace('\\', '/')))
                ConfigureTexture(t, readable: IsData(t, "_roughness") || IsData(t, "_metallic"));

            var mi = (ModelImporter)AssetImporter.GetAtPath(fbx);
            mi.globalScale = 1f;
            mi.useFileScale = true;
            mi.materialImportMode = ModelImporterMaterialImportMode.None;
            mi.importCameras = false;
            mi.importLights = false;
            mi.importAnimation = false;
            mi.animationType = ModelImporterAnimationType.None;
            mi.importNormals = ModelImporterNormals.Import;
            mi.importTangents = ModelImporterTangents.CalculateMikk;
            mi.isReadable = false;
            mi.SaveAndReimport();
        }
        finally { Application.logMessageReceived -= OnLog; }

        // --- metallic (R) + smoothness = 1 - roughness (A) для URP Lit
        string ms = texDir + "/T_" + asset + "_MetallicSmoothness.png";
        var met = AssetDatabase.LoadAssetAtPath<Texture2D>(texDir + "/T_" + asset + "_Metallic.png");
        var rough = AssetDatabase.LoadAssetAtPath<Texture2D>(texDir + "/T_" + asset + "_Roughness.png");
        if (met != null && rough != null)
        {
            var a = met.GetPixels32();
            var r = rough.GetPixels32();
            var o = new Color32[a.Length];
            for (int i = 0; i < a.Length; i++) o[i] = new Color32(a[i].r, a[i].r, a[i].r, (byte)(255 - r[i].r));
            var tex = new Texture2D(met.width, met.height, TextureFormat.RGBA32, false, true);
            tex.SetPixels32(o);
            File.WriteAllBytes(ms, tex.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(tex);
            AssetDatabase.ImportAsset(ms);
            ConfigureTexture(ms, false);
            ConfigureTexture(texDir + "/T_" + asset + "_Metallic.png", false);
            ConfigureTexture(texDir + "/T_" + asset + "_Roughness.png", false);
            Line("OK", "упакована " + Path.GetFileName(ms) + " (metallic R, smoothness = 1 - roughness в A)");
        }
        else Line("FAIL", "нет T_" + asset + "_Metallic / _Roughness");

        // --- материал
        Directory.CreateDirectory(dir + "/Materials");
        string matPath = dir + "/Materials/M_" + asset + ".mat";
        var mat = AssetDatabase.LoadAssetAtPath<Material>(matPath);
        var shader = Shader.Find("Universal Render Pipeline/Lit");
        if (mat == null) { mat = new Material(shader); AssetDatabase.CreateAsset(mat, matPath); }
        mat.shader = shader;
        mat.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(texDir + "/T_" + asset + "_BaseColor.png"));
        mat.SetColor("_BaseColor", Color.white);
        mat.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(texDir + "/T_" + asset + "_Normal.png"));
        mat.SetFloat("_BumpScale", 1f);
        mat.EnableKeyword("_NORMALMAP");
        mat.SetTexture("_MetallicGlossMap", AssetDatabase.LoadAssetAtPath<Texture2D>(ms));
        mat.EnableKeyword("_METALLICSPECGLOSSMAP");
        mat.SetFloat("_Metallic", 1f);
        mat.SetFloat("_Smoothness", 1f);
        mat.SetFloat("_SmoothnessTextureChannel", 0f);
        EditorUtility.SetDirty(mat);
        AssetDatabase.SaveAssets();

        // --- префаб
        Directory.CreateDirectory(dir + "/Prefabs");
        string pfPath = dir + "/Prefabs/PF_" + asset + ".prefab";
        var model = AssetDatabase.LoadAssetAtPath<GameObject>(fbx);
        var tmp = (GameObject)PrefabUtility.InstantiatePrefab(model);
        tmp.name = "PF_" + asset;
        foreach (var rend in tmp.GetComponentsInChildren<Renderer>())
            rend.sharedMaterials = Enumerable.Repeat(mat, rend.sharedMaterials.Length).ToArray();
        PrefabUtility.SaveAsPrefabAsset(tmp, pfPath);
        UnityEngine.Object.DestroyImmediate(tmp);
        Line("OK", "префаб " + pfPath);

        // --- сцена Showcase
        Directory.CreateDirectory(Path.GetDirectoryName(ShowcaseScene));
        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name = "Ground_10m";
        var refHuman = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        refHuman.name = "REF_Human_180";
        refHuman.transform.localScale = new Vector3(0.5f, 0.9f, 0.5f);   // капсула 2 м * 0.9 = 1.8 м
        var inst = (GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(pfPath));
        inst.transform.position = Vector3.zero;
        var b = Bounds(inst);
        refHuman.transform.position = new Vector3(b.min.x - 0.6f, 0.9f, 0f);
        var cam = Camera.main;
        var center = new Bounds(b.center, b.size);
        center.Encapsulate(refHuman.GetComponent<Renderer>().bounds);
        float dist = center.extents.magnitude * 2.2f;
        cam.transform.position = center.center + new Vector3(1f, 0.6f, -1.2f).normalized * dist;
        cam.transform.LookAt(center.center);
        cam.nearClipPlane = 0.05f;
        EditorSceneManager.SaveScene(scene, ShowcaseScene);
        Line("OK", "сцена " + ShowcaseScene);

        // --- проверки по чек-листу
        // 1. масштаб
        var badScale = inst.GetComponentsInChildren<Transform>(true).Where(t => t != inst.transform && (t.localScale - Vector3.one).sqrMagnitude > 1e-6f).ToList();
        Line(badScale.Count == 0 ? "OK" : "FAIL", "Scale (1,1,1) у всех узлов" + (badScale.Count > 0 ? ": " + string.Join(", ", badScale.Select(t => t.name + "=" + t.localScale)) : ""));
        Line("INFO", string.Format("Габариты, м (X,Y,Z): {0:0.000} x {1:0.000} x {2:0.000}; низ Y={3:0.000}", b.size.x, b.size.y, b.size.z, b.min.y));
        bool sizeOk = b.size.y > 0.1f && b.size.y < 10f && Mathf.Abs(b.min.y) < 0.02f;
        Line(sizeOk ? "OK" : "FAIL", "1 единица = 1 метр, стоит на Y=0 (эталон REF_Human_180 = 1,8 м рядом)");
        // 2. меши
        var mfs = inst.GetComponentsInChildren<MeshFilter>(true);
        int tris = mfs.Where(m => m.sharedMesh != null).Sum(m => m.sharedMesh.triangles.Length / 3);
        Line(tris <= MaxTris ? "OK" : "FAIL", "треугольников " + tris + " / " + MaxTris);
        // 3. материалы
        var rends = inst.GetComponentsInChildren<Renderer>(true);
        var badMat = rends.SelectMany(r => r.sharedMaterials).Where(m => m == null || m.shader == null || m.shader.name.Contains("Error") || m.name.StartsWith("Default")).Count();
        Line(badMat == 0 ? "OK" : "FAIL", "материалы: " + string.Join(", ", rends.Select(r => r.name + "=" + string.Join("/", r.sharedMaterials.Select(m => m ? m.name + " (" + m.shader.name + ")" : "null")))));
        foreach (var t in Directory.GetFiles(texDir, "T_*.png").Select(p => p.Replace('\\', '/')))
        {
            var ti = (TextureImporter)AssetImporter.GetAtPath(t);
            var tx = AssetDatabase.LoadAssetAtPath<Texture2D>(t);
            string n = Path.GetFileNameWithoutExtension(t);
            bool wantNormal = n.ToLowerInvariant().EndsWith("_normal");
            bool wantLinear = !n.ToLowerInvariant().EndsWith("_basecolor") && !n.ToLowerInvariant().EndsWith("_emission");
            bool ok = tx.width <= MaxTex && tx.height <= MaxTex
                      && (!wantNormal || ti.textureType == TextureImporterType.NormalMap)
                      && (wantNormal || ti.sRGBTexture == !wantLinear);
            Line(ok ? "OK" : "FAIL", string.Format("Текстура {0}: {1}x{2}, тип={3}, sRGB={4}", n, tx.width, tx.height, ti.textureType, ti.sRGBTexture));
        }
        // 4. LOD
        var lod = inst.GetComponentInChildren<LODGroup>();
        if (lod != null) Line("OK", "LODGroup: " + lod.lodCount + " уровней");
        else Line(tris <= MaxTris ? "OK" : "WARN", "LOD: один уровень (" + tris + " тр. в лимите NPC 15 000 — LOD по стандарту не требуется)");
        // 5. анимации
        var clips = AssetDatabase.LoadAllAssetsAtPath(fbx).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__preview__")).ToList();
        Line("OK", "анимации: " + (clips.Count == 0 ? "нет (статический меш SM_, ожидаемо)" : string.Join(", ", clips.Select(c => c.name + " " + c.length.ToString("0.00") + " c"))));
        // 6. предупреждения импорта
        var warnImport = importMessages.Where(m => m.Contains(asset) || m.Contains("Art/")).ToList();
        Line(warnImport.Count == 0 ? "OK" : "FAIL", "предупреждений импорта: " + warnImport.Count + (warnImport.Count > 0 ? "\n   " + string.Join("\n   ", warnImport) : ""));

        // --- скриншот
        if (!string.IsNullOrEmpty(shotPath) && SystemInfo.graphicsDeviceType != UnityEngine.Rendering.GraphicsDeviceType.Null)
        {
            try
            {
                var rt = new RenderTexture(1600, 900, 24);
                cam.targetTexture = rt;
                cam.Render();
                RenderTexture.active = rt;
                var shot = new Texture2D(1600, 900, TextureFormat.RGB24, false);
                shot.ReadPixels(new Rect(0, 0, 1600, 900), 0, 0);
                shot.Apply();
                Directory.CreateDirectory(Path.GetDirectoryName(shotPath));
                File.WriteAllBytes(shotPath, shot.EncodeToPNG());
                RenderTexture.active = null;
                cam.targetTexture = null;
                UnityEngine.Object.DestroyImmediate(rt);
                sb.AppendLine("Скриншот: " + shotPath);
            }
            catch (Exception e) { Line("WARN", "скриншот не снят: " + e.Message); }
        }
        return Finish(reportPath);
    }

    static bool IsData(string path, string suffix) => Path.GetFileNameWithoutExtension(path).ToLowerInvariant().EndsWith(suffix);

    static void ConfigureTexture(string path, bool readable)
    {
        var ti = AssetImporter.GetAtPath(path) as TextureImporter;
        if (ti == null) { AssetDatabase.ImportAsset(path); ti = AssetImporter.GetAtPath(path) as TextureImporter; }
        string n = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
        ti.textureType = n.EndsWith("_normal") ? TextureImporterType.NormalMap : TextureImporterType.Default;
        ti.sRGBTexture = n.EndsWith("_basecolor") || n.EndsWith("_emission");
        ti.maxTextureSize = MaxTex;
        ti.isReadable = readable;
        ti.textureCompression = readable ? TextureImporterCompression.Uncompressed : TextureImporterCompression.Compressed;
        ti.mipmapEnabled = true;
        ti.SaveAndReimport();
    }

    static Bounds Bounds(GameObject go)
    {
        var rs = go.GetComponentsInChildren<Renderer>();
        var b = rs[0].bounds;
        foreach (var r in rs) b.Encapsulate(r.bounds);
        return b;
    }

    static bool Finish(string reportPath)
    {
        sb.AppendLine("=== ИТОГ: " + (fails == 0 ? "ОК" : "ОШИБКИ") + " (FAIL " + fails + ", WARN " + warns + ") ===");
        Directory.CreateDirectory(Path.GetDirectoryName(reportPath));
        File.WriteAllText(reportPath, sb.ToString(), new UTF8Encoding(true));
        Debug.Log(sb.ToString());
        return fails == 0;
    }
}
