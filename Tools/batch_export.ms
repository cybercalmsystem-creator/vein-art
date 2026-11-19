/*
	batch_export.ms -- еженедельная передача в Unity (Стандарт 3D-пайплайна, раздел 2), 3ds Max 2027.
	Аналог Tools/batch_export.py из стандарта (там Blender).

	Что делает для открытой сцены Source/<Asset>/<Asset>.max:
	  1. asset_validator.ms -- при FAIL экспорт прерывается.
	  2. Все узлы слоя Export -> один Export/<Asset>/SM_<Asset>.fbx (SK_, если есть скин) (FBX 2020, Y-up, сантиметры,
	     сглаживание, тангенты, без камер/света). Части модели сохраняют взаимное положение; на время экспорта группа
	     сдвигается так, чтобы центр низа общих габаритов был в 0,0,0, затем возвращается (19.11.2026: Bot6 из 8 частей).
	  3. Текстуры T_* материала -> Export/<Asset>/Textures/.
	  4. Копия FBX и текстур -> <Unity>/Assets/Art/<Asset>/ (Textures/ рядом), если задан BE_UNITY_ASSETS.
	  5. Журнал Export/_logs/export_log_ГГГГ-ММ-ДД.txt (дописывается).

	Запуск:  fileIn "<repo>/Tools/batch_export.ms"      (или BE_run() после подключения)
	Пакетно по всем сценам Source/ -- BE_runAll() (открывает сцены по очереди; несохранённые изменения не теряет: спрашивает).
*/
global AV_SILENT = true
fileIn ((getFilenamePath (getThisScriptFilename())) + "asset_validator.ms")

global BE_UNITY_ASSETS = @"D:\Unity Projects\VR\vr test\My project\Assets"
global BE_log

fn BE_now fmt = ((dotNetClass "System.DateTime").Now.ToString fmt)
fn BE_w s = (format "%\n" s; if BE_log != undefined do format "%\n" s to:BE_log)

fn BE_copy src dst =
(
	makeDir (getFilenamePath dst) all:true
	if doesFileExist dst do deleteFile dst
	copyFile src dst
)

fn BE_fbxSettings =
(
	FBXExporterSetParam "ResetExport"
	FBXExporterSetParam "FileVersion" "FBX202000"
	FBXExporterSetParam "ASCII" false
	FBXExporterSetParam "UpAxis" "Y"
	FBXExporterSetParam "ConvertUnit" "cm"
	FBXExporterSetParam "ScaleFactor" 1.0
	FBXExporterSetParam "SmoothingGroups" true
	FBXExporterSetParam "NormalsPerPoly" false
	FBXExporterSetParam "TangentSpaceExport" true
	FBXExporterSetParam "Triangulate" false
	FBXExporterSetParam "PreserveInstances" false
	FBXExporterSetParam "Cameras" false
	FBXExporterSetParam "Lights" false
	FBXExporterSetParam "EmbedTextures" false
	FBXExporterSetParam "ShowWarnings" false
	FBXExporterSetParam "GenerateLog" false
)

fn BE_run =
(
	if maxFilePath == "" do (format "[batch_export] сцена не сохранена\n"; return false)
	local repo = pathConfig.removePathLeaf (pathConfig.removePathLeaf maxFilePath)
	local asset = getFilenameFile maxFileName
	local logDir = repo + "\\Export\\_logs"
	makeDir logDir all:true
	local lf = logDir + "\\export_log_" + (BE_now "yyyy-MM-dd") + ".txt"
	if not (doesFileExist lf) do close (createFile lf encoding:#utf8 writeBOM:true)
	BE_log = openFile lf mode:"a+" encoding:#utf8
	BE_w ("\n=== batch_export  " + (BE_now "yyyy-MM-dd HH:mm:ss") + "  " + maxFilePath + maxFileName + " ===")

	-- 1. валидатор
	local v = AV_validate writeReport:true
	BE_w ("validator: FAIL " + v[1] as string + ", WARN " + v[2] as string + "  отчёт: " + v[3])
	if v[1] > 0 do (BE_w "ЭКСПОРТ ПРЕРВАН: валидатор не пройден"; close BE_log; BE_log = undefined; return false)

	local outDir = repo + "\\Export\\" + asset
	local unityDir = if BE_UNITY_ASSETS != "" and doesFileExist BE_UNITY_ASSETS then BE_UNITY_ASSETS + "\\Art\\" + asset else ""
	makeDir (outDir + "\\Textures") all:true
	BE_fbxSettings()
	local okAll = true
	local oldSel = selection as array
	-- 2. FBX: все узлы слоя Export -> ОДИН файл <Prefix>_<Asset>.fbx (части модели сохраняют взаимное положение).
	--    Группа на время экспорта сдвигается так, чтобы центр низа общих габаритов был в 0,0,0, затем возвращается.
	local nodes = AR_exportNodes()
	local prefix = if (for n in nodes where matchPattern n.name pattern:"SK_*" collect n).count > 0 then "SK_" else "SM_"
	local fbx = outDir + "\\" + prefix + asset + ".fbx"
	local bmin = nodes[1].min; local bmax = nodes[1].max
	for n in nodes do (bmin = [amin #(bmin.x, n.min.x), amin #(bmin.y, n.min.y), amin #(bmin.z, n.min.z)]; bmax = [amax #(bmax.x, n.max.x), amax #(bmax.y, n.max.y), amax #(bmax.z, n.max.z)])
	local shift = -[(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, bmin.z]
	local roots = for n in nodes where (n.parent == undefined or (findItem nodes n.parent) == 0) collect n
	for n in roots do move n shift
	select nodes
	local ok = exportFile fbx #noPrompt selectedOnly:true using:FBXEXP
	for n in roots do move n (-shift)
	local tris = 0
	for n in nodes do (local m = snapshotAsMesh n; tris += m.numfaces; delete m)
	BE_w ("FBX  " + nodes.count as string + " узл. -> " + fbx + "  ok=" + ((ok and doesFileExist fbx) as string) + "  tris=" + tris as string + "  size=" + (((getFileSize fbx) / 1024) as integer) as string + " KB")
	BE_w ("     узлы: " + ((for n in nodes collect n.name) as string))
	if not (ok and doesFileExist fbx) do okAll = false
	if unityDir != "" and doesFileExist fbx do
	(
		BE_copy fbx (unityDir + "\\" + prefix + asset + ".fbx")
		BE_w ("  -> Unity " + unityDir + "\\" + prefix + asset + ".fbx")
	)
	-- 3. текстуры (без повторов)
	local done = #()
	for n in nodes where n.material != undefined do
		for b in (getClassInstances BitmapTexture target:n.material) where doesFileExist b.filename and (findItem done (toLower b.filename)) == 0 do
		(
			append done (toLower b.filename)
			local fn_ = filenameFromPath b.filename
			BE_copy b.filename (outDir + "\\Textures\\" + fn_)
			if unityDir != "" do BE_copy b.filename (unityDir + "\\Textures\\" + fn_)
			BE_w ("TEX  " + fn_ + "  " + (((getFileSize b.filename) / 1024) as integer) as string + " KB")
		)
	if oldSel.count > 0 then select oldSel else clearSelection()
	BE_w ("=== ИТОГ: " + (if okAll then "OK" else "ОШИБКИ") + "  " + (BE_now "HH:mm:ss") + " ===")
	close BE_log; BE_log = undefined
	okAll
)

-- все сцены Source/*/*.max по очереди
fn BE_runAll =
(
	local repo = pathConfig.removePathLeaf (getFilenamePath (getThisScriptFilename()))
	if not checkForSave() do return false
	local res = #()
	for d in getDirectories (repo + "\\Source\\*") do
		for f in getFiles (d + "*.max") do
		(
			loadMaxFile f quiet:true
			append res #(f, BE_run())
		)
	res
)

if not (isKindOf BE_NO_AUTORUN BooleanClass and BE_NO_AUTORUN) do BE_run()
