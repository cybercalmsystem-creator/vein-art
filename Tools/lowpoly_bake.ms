/*
	lowpoly_bake.ms -- игровой low-poly из AI/скан-модели (Meshy и т.п.) + запечка PBR-карт с исходника (3ds Max 2027).
	Первый ассет: Bot6 (2026-11-18, исходник -- сцена художника bot#6.max). Правила и лимиты: Docs/ASSET_RULES.md, Tools/asset_rules.ms.

	Запуск по шагам:
		fileIn "<repo>/Tools/lowpoly_bake.ms"
		lp = LB_makeLowPoly $HP "SM_Bot6" 14500       -- копия HP -> ProOptimizer до ~N треугольников
		LB_clean lp                                    -- сварка разрывов, удаление обломков, закрытие дыр, сглаживание 45°
		LB_unwrap lp                                   -- Flatten 40° -> Unfold3D Solve (только перекрытия) -> Pack, секунды
		-- внутри блока ( ... ) вызывать как ::LB_unwrap и т.п., иначе MAXScript сочтёт имя локальной переменной
		LB_bake lp $HP "<repo>/Source/Bot6/Textures" "Bot6" baseColor:"...png" roughness:"...png" metallic:"...png"

	Почему запечка устроена именно так (проверено калибровкой 2026-11-18):
	  * Сцена в OCIO (ACEScg). Render To Texture по умолчанию пишет файл через view transform
	    "ACES 1.0 SDR-video" -> тонмаппинг (16->0, 79->47, 230->196). Поэтому на время запечки
	    вывод по умолчанию переключается: цвет -> sRGB, данные (roughness/metallic) -> без конверсии.
	  * Roughness / metallic / normal читаются как Raw (правила ввода OCIO по маске имени, LB_ensureRawRules).
	  * Цвет и данные печём старым Render To Texture (DiffuseMap, свет выключен) с проекцией по клетке,
	    без фильтрации битмапа: Bake to Texture в Scanline пишет в Roughness/Metalness цвет вместо данных.
	  * Нормали печём Bake to Texture (MikkTSpace, как в Unity), зелёный канал Y+ (OpenGL, как в Unity).
	    По умолчанию Bake to Texture пишет Y- (DirectX), поэтому опция YGreen ставится явно (исправлено 19.11.2026).
	  * На время запечки нормалей bump/normal-карта материала HP выключается: иначе Bake to Texture
	    подмешивает её в результат (у Meshy это Image_2.jpg, читается как sRGB -> «мятая» поверхность).
	Сцену не сохраняет.
*/

global LB_SIZE = 2048

fn LB_tris o = (local m = snapshotAsMesh o; local n = m.numfaces; delete m; n)

-- Копия исходника, упрощённая ProOptimizer до ~targetTris (без привязки к старым UV: они рвут сетку)
fn LB_makeLowPoly hp newName targetTris =
(
	local lp = copy hp
	lp.name = newName
	unhide lp
	lp.material = undefined
	local p = ProOptimizer()
	addModifier lp p
	p.OptimizationMode = 0; p.KeepUV = false; p.LockUV = false; p.LockMat = false
	p.KeepNormals = false; p.PreventFlip = true; p.LockPoints = true
	select lp
	max modify mode
	modPanel.setCurrentObject p
	p.Calculate = true
	-- процент вершин подбираем по факту: число треугольников ~ линейно от процента
	local pct = 100.0 * targetTris / (LB_tris hp)
	for i = 1 to 3 do
	(
		p.VertexPercent = pct
		local t = LB_tris lp
		if t > 0 do pct = pct * targetTris / t
	)
	p.VertexPercent = pct * 0.99
	collapseStack lp
	convertToPoly lp
	format "[lowpoly_bake] %: % треугольников (цель %)\n" newName (LB_tris lp) targetTris
	lp
)

-- Сварка разрывов после ProOptimizer, удаление обломков (< minFaces граней), закрытие дыр, сглаживание
fn LB_clean o minFaces:20 smoothAngle:45.0 =
(
	local vs = polyop.getVertsUsingEdge o (polyop.getOpenEdges o)
	o.weldThreshold = 0.001
	polyop.weldVertsByThreshold o vs
	local nf = polyop.getNumFaces o
	local done = #{}; local junk = #{}
	for f = 1 to nf where not done[f] do
	(
		local e = polyop.getElementsUsingFace o #{f}
		done += e
		if e.numberSet < minFaces do junk += e
	)
	if junk.numberSet > 0 do polyop.deleteFaces o junk delIsoVerts:true
	polyop.capHolesByEdge o (polyop.getOpenEdges o)
	polyop.retriangulate o #all
	polyop.setFaceSelection o #all
	o.autoSmoothThreshold = smoothAngle
	o.EditablePoly.autosmooth()
	polyop.setFaceSelection o #{}
	local nm = 0
	for e = 1 to polyop.getNumEdges o do (if (polyop.getFacesUsingEdge o e).numberSet > 2 do nm += 1)
	format "[lowpoly_bake] clean: % тр., открытых рёбер %, неманифолдных %, удалено граней обломков %\n" (LB_tris o) ((polyop.getOpenEdges o).numberSet) nm junk.numberSet
	#((polyop.getOpenEdges o).numberSet, nm)
)

-- Новая UV в канале 1: Flatten по углу -> Unfold3D Solve только для островов с перекрытием -> Unfold3D Pack.
-- Секунды вместо минут: Solve/Optimize на всю модель (14 тыс. тр.) держали Max 8+ минут без отклика.
-- Нужен интерактивный Max: в 3dsmaxbatch Unwrap без командной панели падает (access violation).
fn LB_unwrap o angle:40.0 =
(
	local u = Unwrap_UVW()
	addModifier o u
	select o
	max modify mode
	modPanel.setCurrentObject u
	u.setMapChannel 1
	u.flattenMap angle #() 0.003 true 0 true true
	local nf = polyop.getNumFaces o
	u.selectFaces #{}; u.selectOverlappedFaces()
	if (u.getSelectedFaces()).numberSet > 0 do
	(
		try (u.selectElement()) catch ()
		u.Unfold3DSolve()
	)
	u.selectFaces #{1..nf}; u.Unfold3DPack()
	u.selectFaces #{}; u.selectOverlappedFaces()
	local ov = (u.getSelectedFaces()).numberSet
	u.selectFaces #{}
	collapseStack o
	local m = snapshotAsMesh o
	local a = 0.0
	for f = 1 to m.numfaces do
	(
		local tf = meshop.getMapFace m 1 f
		local p1 = meshop.getMapVert m 1 tf.x; local p2 = meshop.getMapVert m 1 tf.y; local p3 = meshop.getMapVert m 1 tf.z
		a += abs (((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y)) / 2.0)
	)
	delete m
	format "[lowpoly_bake] UV: покрытие % \%, перекрытых граней %\n" (formattedPrint (a * 100) format:".1f") ov
	#(a * 100, ov)
)

-- Правила ввода OCIO: карты-данные читаются как Raw (иначе их линеаризуют как sRGB)
fn LB_ensureRawRules =
(
	local c = ColorPipelineMgr
	local have = #()
	for i = 1 to c.InputRulesCount do
	(
		local n = ""; local s = ""; local p = ""; local e = ""; local x = ""
		c.GetInputRule i name:&n colorSpace:&s pattern:&p extension:&e regex:&x
		append have n
	)
	for r in #(#("lb_roughness_raw", "*oughness*"), #("lb_metal_raw", "*etal*"), #("lb_normal_raw", "*_Normal*")) where (findItem have r[1]) == 0 and (findItem have (substituteString r[1] "lb_" "bot6_")) == 0 do
		c.InsertInputRule 1 r[1] "Raw" pattern:r[2] extension:"png"
)

fn LB_setOutConv conv cs =
(
	local s = cs; local d = ""; local v = ""
	ColorPipelineMgr.SetDefaultOutputConversion conv colorSpace:&s display:&d viewTransform:&v fileType:#GammaEncoded
)

-- Одна карта: материал HP временно заменяется на Standard с этой текстурой в Diffuse, свет выключен
fn LB_bakeOne lp hp srcFile outFile =
(
	local orig = hp.material
	local t = Standardmaterial name:"LB_tmp_bake"
	local bm = Bitmaptexture filename:srcFile
	bm.filtering = 2                      -- без фильтрации: пирамида на раздробленном атласе тянет чёрный фон
	t.diffuseMap = bm
	t.selfIllumAmount = 100
	hp.material = t
	local bp = lp.INodeBakeProperties
	bp.removeAllBakeElements()
	bp.bakeEnabled = true; bp.bakeChannel = 1; bp.nDilations = 16
	local e = DiffuseMap()
	e.outputSzX = LB_SIZE; e.outputSzY = LB_SIZE
	e.fileType = outFile; e.fileName = filenameFromPath outFile
	e.filterOn = true; e.shadowsOn = false; e.lightingOn = false; e.enabled = true
	bp.addBakeElement e
	select lp
	render rendertype:#bakeSelected vfb:off progressBar:false outputSize:[LB_SIZE, LB_SIZE] quiet:true
	hp.material = orig
	bp.removeAllBakeElements()
	doesFileExist outFile
)

-- опция карты Bake to Texture по имени (индексы опций могут меняться между версиями Max)
fn LB_setMapOption m optName val =
(
	local done = false
	for i = 1 to m.getOptionsCount() where (m.getOptionName i) == optName do done = m.setOptionValue i val
	if not done do format "[lowpoly_bake] ВНИМАНИЕ: опция % не установлена\n" optName
	done
)

fn LB_bake lp hp outDir assetName baseColor:"" roughness:"" metallic:"" cagePush:0.6 =
(
	makeDir outDir all:true
	LB_ensureRawRules()
	local res = #()
	-- сохранить, что было
	local oldRenderer = renderers.current
	local cs = ""; local dp = ""; local vt = ""
	local oldConv = ColorPipelineMgr.GetDefaultOutputConversion colorSpace:&cs display:&dp viewTransform:&vt fileType:#GammaEncoded
	local hpHidden = hp.isHidden
	local hpBumpOn = undefined
	try
	(
		unhide hp
		renderers.current = Default_Scanline_Renderer()
		local pj = Projection()
		addModifier lp pj
		pj.addObjectNode hp
		select lp
		max modify mode
		modPanel.setCurrentObject pj
		pj.resetCage(); pj.pushCage cagePush
		local pp = lp.INodeBakeProjProperties
		pp.enabled = true; pp.projectionMod = pj; pp.useCage = true; pp.hitResolveMode = #closest
		pp.hitMatchMtlID = false; pp.warnRayMiss = false; pp.rayMissColor = (color 255 0 255)

		-- цвет: sRGB -> ACEScg -> sRGB (тождественно)
		LB_setOutConv #ColorSpaceConversion "sRGB"
		if baseColor != "" do append res #("BaseColor", LB_bakeOne lp hp baseColor (outDir + "/T_" + assetName + "_BaseColor.png"))
		-- данные: Raw на входе, без конверсии на выходе
		LB_setOutConv #NoConversion ""
		if roughness != "" do append res #("Roughness", LB_bakeOne lp hp roughness (outDir + "/T_" + assetName + "_Roughness.png"))
		if metallic != "" do append res #("Metallic", LB_bakeOne lp hp metallic (outDir + "/T_" + assetName + "_Metallic.png"))

		-- нормали: Bake to Texture, MikkTSpace, Y+ (OpenGL), без конверсии, только геометрия HP
		if hp.material != undefined and (isProperty hp.material #bump_map_on) do
		(
			hpBumpOn = hp.material.bump_map_on
			hp.material.bump_map_on = false
		)
		BakeToTexture.deleteAllMaps()
		BakeToTexture.outputPath = outDir + "/"
		BakeToTexture.alwaysOverwriteExistingFiles = true
		local m = BakeToTexture.addMapByTypeName lp "Normal"
		m.setImageSize LB_SIZE LB_SIZE; m.edgePadding = 16; m.uvChannel = 1; m.fileType = "png"
		m.projectionModifierIndex = 1; m.projectionMethod = 1; m.projectionResolveHitType = 0
		LB_setMapOption m "MikkTForTangent" true
		LB_setMapOption m "YGreen" 0
		m.fileName = "T_" + assetName + "_Normal"
		select lp
		BakeToTexture.bake()
		BakeToTexture.deleteAllMaps()
		append res #("Normal", doesFileExist (outDir + "/T_" + assetName + "_Normal.png"))
	)
	catch (append res #("exception", getCurrentException()))
	-- вернуть как было
	if hpBumpOn != undefined do hp.material.bump_map_on = hpBumpOn
	local s2 = cs; local d2 = dp; local v2 = vt
	ColorPipelineMgr.SetDefaultOutputConversion oldConv colorSpace:&s2 display:&d2 viewTransform:&v2 fileType:#GammaEncoded
	renderers.current = oldRenderer
	local pjm = lp.modifiers[#Projection]
	if pjm != undefined do deleteModifier lp pjm
	lp.INodeBakeProperties.bakeEnabled = false
	lp.INodeBakeProjProperties.enabled = false
	if hpHidden do hide hp
	format "[lowpoly_bake] bake: %\n" res
	res
)

-- PBR-материал на low-poly из запечённых карт
fn LB_assignMaterial lp texDir assetName =
(
	local m = PhysicalMaterial name:("M_" + assetName)
	local p = texDir + "/T_" + assetName
	m.base_color_map = Bitmaptexture filename:(p + "_BaseColor.png") name:("T_" + assetName + "_BaseColor")
	m.roughness_map = Bitmaptexture filename:(p + "_Roughness.png") name:("T_" + assetName + "_Roughness")
	m.metalness_map = Bitmaptexture filename:(p + "_Metallic.png") name:("T_" + assetName + "_Metallic")
	local nb = Normal_Bump()
	nb.normal_map = Bitmaptexture filename:(p + "_Normal.png") name:("T_" + assetName + "_Normal")
	m.bump_map = nb
	m.bump_map_amt = 1.0
	lp.material = m
	m
)
