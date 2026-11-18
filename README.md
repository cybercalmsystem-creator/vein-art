# 3D-Assistant — арт-пайплайн 3ds Max → Unity (VR Shooter)

Правила: [Docs/ASSET_RULES.md](Docs/ASSET_RULES.md) · чек-лист Unity: [Docs/UNITY_SHOWCASE_CHECKLIST.md](Docs/UNITY_SHOWCASE_CHECKLIST.md) ·
журнал ИИ: [Docs/AI_LOG.md](Docs/AI_LOG.md)

| Папка | Что лежит |
|---|---|
| `Tools/` | MAXScript: `asset_rules.ms`, `asset_validator.ms` (перед экспортом), `batch_export.ms` (передача в Unity), `lowpoly_bake.ms`, `build_bot6.ms`, `make_template.ms` |
| `Template/Template.max` | шаблон сцены: сантиметры, эталон `REF_Human_180` |
| `Source/<Asset>/` | исходники `.max`, запечённые `Textures/`, AI-исходник `Meshy/` — **Git LFS** |
| `Export/<Asset>/` | FBX и текстуры, ушедшие в Unity — **Git LFS** |
| `Export/_logs/` | журналы экспорта, отчёты валидатора и проверки Showcase в Unity |
| `Unity/Editor/` | `ArtTexturePostprocessor.cs`, `ShowcaseBuilder.cs` → копируются в `Assets/Art/Editor/` |

Unity-проект: `D:\Unity Projects\VR\vr test\My project` (6000.6.8f1, URP 17) — `Assets/Art/<Asset>/`, `Assets/Art/Showcase/Showcase.unity`.

## Неделя

| Когда | Что | Чем |
|---|---|---|
| до среды 18:00 | объекты в слое `Export`, валидатор пройден | `Tools/asset_validator.ms` |
| четверг утром | FBX + T_* → `Export/` и `Assets/Art/`, журнал `export_log` | `Tools/batch_export.ms` |
| четверг днём | `Showcase.unity` по чек-листу | `ShowcaseBuilder.cs` |
| пятница | исправления, коммит `art: weekly drop ГГГГ-ММ-ДД`, тег `art-ГГГГ-WНН` | git |

## Git LFS

```
git lfs install
git lfs lock "3dsMax/Claude Environment/Project/3D-Assistant/Source/Bot6/Bot6.max"   # перед работой со сценой
git lfs unlock ...                                                                    # после коммита
```
Файл всегда один (без `_v3_final2`), версии — коммиты и теги `art-ГГГГ-WНН`.
