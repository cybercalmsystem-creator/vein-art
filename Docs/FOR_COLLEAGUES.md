# Пайплайн 3ds Max → Unity за 15 минут (для 3D-модельеров Games)

Автор и куратор: Гриб Виктор. Вопросы — ему. Стандарт: Games — 3D-арт (правила — `Docs/ASSET_RULES.md`).

## 1. Один раз на машине

```
git config --global core.longpaths true
git lfs install
git clone https://github.com/cybercalmsystem-creator/vein-art.git
```
3ds Max 2027, Unity 6000.6.8f1 (URP). Скопируй `Unity/Editor/*.cs` в `Assets/Art/Editor/` своего Unity-проекта.

## 2. Своя модель

1. Открой `Template/Template.max`, сохрани как `Source/<Asset>/<Asset>.max` (латиница, PascalCase, без `#` и `_v2`).
2. Экспортные меши — в слой **Export**, имена `SM_<Asset>` / `SM_<Asset>_<Часть>`; исходник высокой плотности — `HP_<Asset>` в слой `Source_HP`.
3. Если есть AI-исходник (Meshy и т.п.) — промпт в `Source/<Asset>/Meshy/prompts.md`, строка в `Docs/AI_LOG.md`.

## 3. Low-poly и запекание (если модель из Meshy / скана)

```
fileIn "<repo>/Tools/lowpoly_bake.ms"
lp = LB_makeLowPoly $HP_<Asset> "SM_<Asset>" 14500
LB_clean lp ; LB_unwrap lp
LB_bake lp $HP_<Asset> "<repo>/Source/<Asset>/Textures" "<Asset>" baseColor:"..." roughness:"..." metallic:"..."
LB_assignMaterial lp "<repo>/Source/<Asset>/Textures" "<Asset>"
```

## 4. Перед экспортом — валидатор

Scripting → Run Script → `Tools/asset_validator.ms`. FAIL — исправить, WARN — обсудить с ведущим.

## 5. Передача в Unity

Run Script → `Tools/batch_export.ms` (путь к Unity-проекту — `BE_UNITY_ASSETS` в начале файла).
Все меши слоя Export уходят одним `SM_<Asset>.fbx` в `Export/<Asset>/` и `Assets/Art/<Asset>/`, журнал — `Export/_logs/`.
В Unity: меню **Art → Build Showcase**, отчёт — `AIHub_Report/`.

## 6. Сохранить

```
git lfs lock "Source/<Asset>/<Asset>.max"     # перед работой со сценой
git add Source Export Docs
git commit -m "art: <Asset> — что сделано"
git push
git lfs unlock "Source/<Asset>/<Asset>.max"
```
Пятница 20:00 — автоснимок с тегом `art-ГГГГ-WНН` (`Tools/weekly_snapshot.ps1`, задача Windows «Art weekly snapshot»).

## Отзыв

Попробовал — напиши Виктору, что неудобно, и пришли ссылку на свой коммит или журнал из `Export/_logs/`.
