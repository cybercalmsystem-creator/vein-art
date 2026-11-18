/*
	batch_export.ms -- еженедельная передача в Unity (Стандарт 3D-пайплайна, раздел 2), 3ds Max 2027.
	Аналог Tools/batch_export.py из стандарта (там Blender).

	Что делает для открытой сцены Source/<Asset>/<Asset>.max:
	  1. asset_validator.ms -- при FAIL экспорт прерывается.
	  2. Каждый узел слоя Export -> Export/<Asset>/<Node>.fbx (FBX 2020, Y-up, сантиметры, сглаживание, тангенты, без камер/света),
	     узел на время экспорта ставится в начало координат (pivot = 0,0,0), затем возвращается.
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
	for n in AR_exportNodes() do
	(
		-- 2. FBX
		local oldPos = n.pos
		n.pos = [0, 0, 0]
		select n
		local fbx = outDir + "\\" + n.name + ".fbx"
		local ok = exportFile fbx #noPrompt selectedOnly:true using:FBXEXP
		n.pos = oldPos
		local m = snapshotAsMesh n; local tris = m.numfaces; delete m
		BE_w ("FBX  " + n.name + "  -> " + fbx + "  ok=" + ((ok and doesFileExist fbx) as string) + "  tris=" + tris as string + "  size=" + (((getFileSize fbx) / 1024) as integer) as string + " KB")
		if not (ok and doesFileExist fbx) do okAll = false
		if unityDir != "" and doesFileExist fbx do
		(
			BE_copy fbx (unityDir + "\\" + n.name + ".fbx")
			BE_w ("  -> Unity " + unityDir + "\\" + n.name + ".fbx")
		)
		-- 3. текстуры
		if n.material != undefined do
			for b in (getClassInstances BitmapTexture target:n.material) where doesFileExist b.filename do
			(
				local fn_ = filenameFromPath b.filename
				BE_copy b.filename (outDir + "\\Textures\\" + fn_)
				if unityDir != "" do BE_copy b.filename (unityDir + "\\Textures\\" + fn_)
				BE_w ("TEX  " + fn_ + "  " + (((getFileSize b.filename) / 1024) as integer) as string + " KB")
			)
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
