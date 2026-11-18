# Чек-лист Showcase.unity (четверг днём)

Основание: Стандарт 3D-пайплайна, раздел 2. Сцена: `Assets/Art/Showcase/Showcase.unity`.
Автоматически проверяет `Assets/Art/Editor/ShowcaseBuilder.cs` (меню **Art > Build Showcase** или пакетно, см. ниже);
отчёт — `Export/_logs/unity_showcase_<Asset>_<дата>.txt` + скриншот `.png`.

| # | Пункт | Норма |
|---|---|---|
| 1 | Масштаб | Scale (1,1,1) у всех узлов; 1 единица = 1 м; ассет стоит на Y = 0; рядом эталон `REF_Human_180` (1,8 м) |
| 2 | Меш | треугольников не больше лимита класса (NPC — 15 000) |
| 3 | Материалы | URP/Lit, без Default/Error-шейдера; BaseColor/Emission — sRGB, Normal — Normal map, Roughness/Metallic/MS — линейные; ≤ 2048² |
| 4 | LOD | LODGroup, если меш выше лимита LOD0 класса; иначе один уровень (фиксируется в отчёте) |
| 5 | Анимации | у `SK_` — клипы на месте и проигрываются; у `SM_` — нет |
| 6 | Импорт | ноль предупреждений и ошибок импорта по `Assets/Art/` |

Пакетный запуск (Unity закрыт):

```
Unity.exe -batchmode -projectPath "D:\Unity Projects\VR\vr test\My project" ^
  -executeMethod ShowcaseBuilder.BuildBatch -asset Bot6 ^
  -report "<repo>\Export\_logs\unity_showcase_Bot6_<дата>.txt" -shot "<repo>\Export\_logs\unity_showcase_Bot6_<дата>.png"
```

URP/Lit берёт metallic и smoothness из одной карты: `ShowcaseBuilder` собирает `T_<Asset>_MetallicSmoothness.png`
(R = metallic, A = 1 − roughness) из запечённых `_Metallic` и `_Roughness`.
