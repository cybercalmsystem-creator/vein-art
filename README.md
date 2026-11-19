# vein-art — арт-пайплайн 3ds Max → Unity, проект Vein VR («Vein: Zeroing out»)

Crocos · отдел Games · ПМ — Диас · 3D-модельер — Гриб Виктор · ведущий — Иван Г.
Стандарт: Games — 3D-арт. Задачи — portal.crocos.kz, проект VEIN.
Репозиторий временно на GitHub: доступа к GitLab Crocos пока нет. Когда появится — перенос с историей и LFS.
История до 19.11.2026 перенесена из `cybercalmsystem-creator/Scripts` (папка `3dsMax/Claude Environment/Project/3D-Assistant`).

## Быстрый старт (новая машина)

```
git config --global core.longpaths true      # путь одной Meshy-текстуры длиннее 260 символов
git lfs install
git clone https://github.com/cybercalmsystem-creator/vein-art.git
```

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
git lfs lock "Source/Bot6/Bot6.max"     # перед работой со сценой
git lfs unlock "Source/Bot6/Bot6.max"   # после коммита
```
Файл всегда один (без `_v3_final2`), версии — коммиты и теги `art-ГГГГ-WНН`.
Пятница 20:00 — автоснимок `Tools/weekly_snapshot.ps1` (задача Windows «Art weekly snapshot»).
Раз в месяц — пробное восстановление на чистой папке, журнал в `Export/_logs/restore_test_*.txt`.
