/*
	build_bot6.ms -- разовая подготовка Source/Bot6/Bot6.max под Docs/ASSET_RULES.md (2026-11-18).
	Source/Bot6/Bot6.max -- копия сцены художника E:/Борохло/3DProject/VR_Shooter/npc/bot#6/bot#6.max (оригинал не трогаем).
	Модель: Meshy AI «Twin Ring Battle Drone», 1 132 358 тр.
	Запуск в интерактивном Max (Unwrap требует UI):  fileIn "<repo>/Tools/build_bot6.ms"

	1. bot#6_HP -> HP_Bot6 (исходник для запечки, слой Source_HP, скрыт, в экспорт не идёт).
	   Текстуры HP перепривязаны к копии в Source/Bot6/Meshy/ (репозиторий самодостаточен).
	2. Прежний low-poly bot#6 (36 657 тр.) удалён: лимит пропа/NPC -- 15 000 тр. (ASSET_RULES §4). В сцене художника он остаётся.
	3. SM_Bot6: ProOptimizer с HP до ~14 500 тр., сварка, обломки < 20 граней, закрытие дыр, сглаживание 45°, Reset XForm (scale 1).
	4. UV (Flatten + Unfold3D) и запечка PBR 2048 (lowpoly_bake.ms) в Source/Bot6/Textures, материал M_Bot6.
	5. Pivot -- центр низа. Слои: Export = SM_Bot6, Source_HP = HP_Bot6. Сцена сохраняется.
*/
fileIn ((getFilenamePath (getThisScriptFilename())) + "lowpoly_bake.ms")
(
	local repo = pathConfig.removePathLeaf (getFilenamePath (getThisScriptFilename()))
	local srcDir = repo + "\\Source\\Bot6"
	local meshyDir = srcDir + "\\Meshy\\"
	local texDir = srcDir + "\\Textures"
	local logDir = repo + "\\Export\\_logs"
	makeDir logDir all:true
	local out = createFile (logDir + "\\build_bot6_" + ((dotNetClass "System.DateTime").Now.ToString "yyyy-MM-dd_HHmmss") + ".txt") encoding:#utf8
	format "build_bot6.ms  %\nscene: %\n\n" ((dotNetClass "System.DateTime").Now.ToString "yyyy-MM-dd HH:mm:ss") (maxFilePath + maxFileName) to:out

	-- 1. исходник
	local hp = getNodeByName "bot#6_HP"
	if hp == undefined do hp = getNodeByName "HP_Bot6"
	hp.name = "HP_Bot6"
	for b in (getClassInstances BitmapTexture target:hp.material) do
	(
		local f = filenameFromPath b.filename
		local cands = #(meshyDir + f, meshyDir + "Meshy_AI_Twin_Ring_Battle_Drone_20261118_texture.fbm\\" + f)
		for c in cands where doesFileExist c do (b.filename = c)
		format "HP texture: %  exists: %\n" b.filename (doesFileExist b.filename) to:out
	)
	format "HP_Bot6: % tris\n" (LB_tris hp) to:out

	-- 2. прежний low-poly
	for n in #("bot#6", "bot6_LP37k_backup") do
	(
		local o = getNodeByName n
		if o != undefined do (format "deleted old low-poly '%': % tris\n" n (LB_tris o) to:out; delete o)
	)
	local old = getNodeByName "SM_Bot6"
	if old != undefined do delete old

	-- 3. новый low-poly
	local t0 = timestamp()
	local lp = ::LB_makeLowPoly hp "SM_Bot6" 14500
	local cl = ::LB_clean lp
	ResetXForm lp; collapseStack lp; convertToPoly lp
	format "SM_Bot6: % tris, open edges %, non-manifold %, scale %, % s\n" (::LB_tris lp) cl[1] cl[2] lp.scale ((timestamp() - t0) / 1000) to:out

	-- 4. UV + запечка + материал
	local uv = ::LB_unwrap lp
	format "UV: coverage (percent) %, overlaps %\n" uv[1] uv[2] to:out
	local fbm = meshyDir + "Meshy_AI_Twin_Ring_Battle_Drone_20261118_texture.fbm\\"
	local res = ::LB_bake lp hp texDir "Bot6" baseColor:(meshyDir + "Meshy_AI_Twin_Ring_Battle_Drone_20261118_texture.png") roughness:(meshyDir + "Meshy_AI_Twin_Ring_Battle_Drone_20261118_texture_roughness.png") metallic:(meshyDir + "Meshy_AI_Twin_Ring_Battle_Drone_20261118_texture_metallic.png")
	format "bake: %\n" res to:out
	::LB_assignMaterial lp texDir "Bot6"

	-- 5. pivot и слои
	lp.pivot = [(lp.min.x + lp.max.x) / 2.0, (lp.min.y + lp.max.y) / 2.0, lp.min.z]
	local le = LayerManager.getLayerFromName "Export"
	if le == undefined do le = LayerManager.newLayerFromName "Export"
	le.addNode lp
	local ls = LayerManager.getLayerFromName "Source_HP"
	if ls == undefined do ls = LayerManager.newLayerFromName "Source_HP"
	ls.addNode hp
	hide hp
	setUserProp lp "asset_class" "npc"

	saveMaxFile (maxFilePath + maxFileName) quiet:true
	format "\nsaved: %\nobjects: %\n" (maxFilePath + maxFileName) (for o in objects collect o.name) to:out
	close out
	"build_bot6 done"
)
