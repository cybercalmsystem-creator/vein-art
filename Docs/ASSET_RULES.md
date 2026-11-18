# Правила ассетов проекта 3D-Assistant (VR Shooter)

Версия 1.0 · 2026-11-18 · пересмотр раз в квартал (следующий — до 2027-02-18)
Основание: Стандарт 3D-пайплайна Crocos, раздел 1. Стандарт написан под Blender; в проекте рабочий DCC — **3ds Max 2027**,
поэтому `Template.blend` → `Template/Template.max`, `Tools/asset_validator.py` → `Tools/asset_validator.ms`.

## 1. Имена

| Префикс | Что | Пример |
|---|---|---|
| `SM_` | статический меш (идёт в экспорт) | `SM_Bot6` |
| `SK_` | скелетный меш (скин) | `SK_Bot3_Scorpion` |
| `M_`  | материал | `M_Bot6` |
| `T_`  | текстура, суффикс — канал | `T_Bot6_BaseColor`, `_Normal`, `_Roughness`, `_Metallic`, `_AO`, `_Emission` |
| `A_`  | анимация / клип | `A_Bot6_Idle` |
| `UCX_` | коллизия (имя = `UCX_<меш>_NN`) | `UCX_SM_Bot6_01` |
| `PF_` | префаб в Unity | `PF_Bot6` |
| `HP_` | исходник высокой плотности (в экспорт **не** идёт) | `HP_Bot6` |
| `REF_` | эталон масштаба (в экспорт не идёт) | `REF_Human_180` |

* Только латиница, цифры и `_`. Без пробелов, `#`, кириллицы.
* Без автосуффиксов `.001`, `001`, `_copy`, `_final`, `_v3_final2`. Версию хранит Git, а не имя файла.
* Имя ассета — PascalCase: `Bot6`, `HoverTank`.

## 2. Папки

```
3D-Assistant/
  Source/<Asset>/          исходники: <Asset>.max, Textures/ (запечённые T_*), Meshy/ (AI-исходник)   → Git LFS
  Export/<Asset>/          только то, что уходит в Unity: <Mesh>.fbx + T_*.png                         → Git LFS
  Export/_logs/            export_log_ГГГГ-ММ-ДД.txt (журнал batch_export)
  Template/Template.max    шаблон сцены: единицы, слои, эталон REF_Human_180
  Tools/                   asset_rules.ms, asset_validator.ms, batch_export.ms, lowpoly_bake.ms
  Docs/                    правила, чек-лист Showcase, журнал ИИ-ассетов
```

Unity: `Assets/Art/<Asset>/` (FBX, Textures/, Materials/, Prefabs/), `Assets/Art/Showcase/Showcase.unity`, `Assets/Art/Editor/`.

## 3. Масштаб и оси

* 1 единица Unity = 1 метр. В 3ds Max системные единицы — **сантиметры**, FBX экспортируется в сантиметрах,
  Unity переводит (`Convert Units`, File Scale 0.01) → в сцене 1 = 1 м.
* Scale объекта = (1,1,1) (Reset XForm перед экспортом), pivot — по центру низа, объект стоит на Z = 0.
* Up axis в FBX — Y (Unity). Эталон роста — `REF_Human_180` (180 см) в `Template.max`.

## 4. Лимиты

| Класс | Треугольники на меш | Текстуры |
|---|---|---|
| Проп / NPC малый (бот, дрон) | ≤ 15 000 | ≤ 2048², один материал |
| Персонаж / крупный NPC | ≤ 30 000 | ≤ 2048², до 2 материалов |
| Оружие от 1-го лица | ≤ 12 000 | ≤ 2048² |
| Окружение (модуль) | ≤ 5 000 | атлас ≤ 2048² |

* Текстуры — PNG, сторона — степень двойки. Normal — MikkTSpace (как в Unity), OpenGL (Y+).
* Roughness / Metallic / Normal / AO — линейные данные (в Unity sRGB выключен; делает `ArtTexturePostprocessor.cs`).
* Материалов на меш — 1 (проп). Missing-текстур в сцене быть не должно.

## 5. Перед экспортом

Художник запускает `Tools/asset_validator.ms` (MAXScript → Run Script или `fileIn`). Ошибки (FAIL) блокируют экспорт,
предупреждения (WARN) — на усмотрение ведущего. Отчёт сохраняется в `Export/_logs/validate_<сцена>_<время>.txt`.

## 6. Путь до Unity (проверено на Bot6, 2026-11-18)

`HP_Bot6` (Meshy AI, 1,13 млн тр.) → `lowpoly_bake.ms` (SM_Bot6, ~14,5 тыс. тр., UV, запечка PBR 2048) →
`asset_validator.ms` (OK) → `batch_export.ms` (FBX + T_* → `Export/` и `Assets/Art/Bot6/`, журнал) →
Unity `ShowcaseBuilder` (материал, префаб `PF_Bot6`, сцена `Showcase.unity`, проверки по чек-листу).
