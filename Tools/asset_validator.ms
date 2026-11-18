/*
	asset_validator.ms -- проверка сцены по Docs/ASSET_RULES.md перед экспортом (3ds Max 2027).
	Художник запускает перед каждым экспортом: Scripting > Run Script... или  fileIn "<repo>/Tools/asset_validator.ms"
	Без UI (из batch_export.ms):  AV_validate writeReport:true  -> #(fails, warns, reportPath)

	FAIL -- экспорт запрещён. WARN -- решает ведущий.
	Отчёт: Export/_logs/validate_<сцена>_<ГГГГ-ММ-ДД_ЧЧммсс>.txt
*/
fileIn ((getFilenamePath (getThisScriptFilename())) + "asset_rules.ms")

global AV_lines, AV_fails, AV_warns
fn AV_add kind node msg =
(
	local s = "[" + kind + "] " + (if node != undefined then node.name + ": " else "") + msg
	append AV_lines s
	if kind == "FAIL" do AV_fails += 1
	if kind == "WARN" do AV_warns += 1
)

fn AV_checkName n =
(
	if not (AR_NAME_RX.IsMatch n.name) then AV_add "FAIL" n "имя не латиница/цифры/_"
	else if AR_BAD_SUFFIX_RX.IsMatch n.name then AV_add "FAIL" n "автосуффикс или версия в имени (.001, 001, _final, _v2...)"
	else if not (AR_hasPrefix n.name AR_EXPORT_PREFIXES) then AV_add "FAIL" n ("нет префикса " + (AR_EXPORT_PREFIXES as string))
	else AV_add "OK" n "имя"
)

fn AV_checkTransform n =
(
	local s = n.scale
	if (abs (s.x - 1) > 0.001) or (abs (s.y - 1) > 0.001) or (abs (s.z - 1) > 0.001) then AV_add "FAIL" n ("scale " + (s as string) + " != 1 -- Reset XForm")
	else AV_add "OK" n "scale 1"
	local bmin = n.min; local bmax = n.max
	local h = bmax.z - bmin.z
	if abs (n.pivot.z - bmin.z) > 1.0 then AV_add "WARN" n ("pivot не на низу (pivot.z=" + (formattedPrint n.pivot.z format:".1f") + ", низ=" + (formattedPrint bmin.z format:".1f") + " см)")
	else AV_add "OK" n "pivot на низу"
	local c = (bmin + bmax) / 2.0
	if (abs (n.pivot.x - c.x) > 1.0) or (abs (n.pivot.y - c.y) > 1.0) do AV_add "WARN" n "pivot не по центру XY"
	if abs bmin.z > 1.0 do AV_add "WARN" n ("не стоит на Z=0 (низ " + (formattedPrint bmin.z format:".1f") + " см)")
	if h < 1.0 or h > 5000.0 do AV_add "FAIL" n ("подозрительный размер: высота " + (formattedPrint h format:".1f") + " см")
	AV_add "INFO" n ("габариты, см: " + (formattedPrint (bmax.x - bmin.x) format:".1f") + " x " + (formattedPrint (bmax.y - bmin.y) format:".1f") + " x " + (formattedPrint h format:".1f"))
)

fn AV_checkMesh n =
(
	local m = snapshotAsMesh n
	local t = m.numfaces
	local hasUV = meshop.getMapSupport m 1
	delete m
	local cl = AR_triLimitFor n
	if t > cl[2] then AV_add "FAIL" n ("треугольников " + t as string + " > лимита " + cl[2] as string + " (" + cl[1] + ")")
	else AV_add "OK" n ("треугольников " + t as string + " / " + cl[2] as string + " (" + cl[1] + ")")
	if not hasUV then AV_add "FAIL" n "нет UV в канале 1" else AV_add "OK" n "UV канал 1"
	t
)

fn AV_checkTexture n b =
(
	local f = b.filename
	if f == undefined or f == "" or not (doesFileExist f) then (AV_add "FAIL" n ("missing-текстура: " + (f as string)); return false)
	local nm = getFilenameFile f
	if not (matchPattern nm pattern:"T_*") do AV_add "FAIL" n ("текстура без префикса T_: " + nm)
	local okCh = false
	for c in AR_TEX_CHANNELS where (matchPattern nm pattern:("*" + c)) do okCh = true
	if not okCh do AV_add "WARN" n ("у текстуры нет суффикса канала: " + nm)
	if (toLower (getFilenameType f)) != ".png" do AV_add "WARN" n ("не PNG: " + filenameFromPath f)
	local w = 0; local h = 0
	try (local bi = getBitmapInfo f; w = bi[3]; h = bi[4]) catch ()
	if w == 0 then AV_add "WARN" n ("не удалось прочитать размер: " + nm)
	else if (w > AR_MAX_TEXTURE or h > AR_MAX_TEXTURE) then AV_add "FAIL" n (nm + " " + w as string + "x" + h as string + " > " + AR_MAX_TEXTURE as string)
	else if not ((AR_isPow2 w) and (AR_isPow2 h)) then AV_add "FAIL" n (nm + " " + w as string + "x" + h as string + " -- не степень двойки")
	else AV_add "OK" n (nm + " " + w as string + "x" + h as string)
	true
)

fn AV_checkMaterial n =
(
	local mat = n.material
	if mat == undefined then (AV_add "FAIL" n "нет материала"; return false)
	local mats = if classof mat == Multimaterial then (for s in mat.materialList where s != undefined collect s) else #(mat)
	if mats.count > AR_MAX_MATERIALS do AV_add "FAIL" n ("материалов " + mats.count as string + " > " + AR_MAX_MATERIALS as string)
	for m in mats do
	(
		if not (matchPattern m.name pattern:"M_*") or not (AR_NAME_RX.IsMatch m.name) or (AR_BAD_SUFFIX_RX.IsMatch m.name) then AV_add "FAIL" n ("имя материала: " + m.name)
		else AV_add "OK" n ("материал " + m.name)
		local bms = getClassInstances BitmapTexture target:m
		if bms.count == 0 do AV_add "WARN" n ("у " + m.name + " нет текстур")
		for b in bms do AV_checkTexture n b
	)
	true
)

fn AV_validate writeReport:true =
(
	AV_lines = #(); AV_fails = 0; AV_warns = 0
	local scene = if maxFileName == "" then "untitled" else getFilenameFile maxFileName
	append AV_lines ("asset_validator.ms  правила " + AR_VERSION + "  сцена: " + maxFilePath + maxFileName)
	append AV_lines ("время: " + ((dotNetClass "System.DateTime").Now.ToString "yyyy-MM-dd HH:mm:ss"))
	if units.SystemType != #centimeters or units.SystemScale != 1.0 then AV_add "FAIL" undefined ("системные единицы " + units.SystemType as string + " x" + units.SystemScale as string + " (нужны сантиметры x1)")
	else AV_add "OK" undefined "системные единицы: сантиметры"
	local nodes = AR_exportNodes()
	if nodes.count == 0 do AV_add "FAIL" undefined ("в слое " + AR_EXPORT_LAYER + " нет геометрии для экспорта")
	for n in nodes do
	(
		AV_checkName n
		AV_checkTransform n
		AV_checkMesh n
		if not (matchPattern n.name pattern:"UCX_*") do AV_checkMaterial n
	)
	-- служебные узлы не должны попасть в Export
	local l = LayerManager.getLayerFromName AR_EXPORT_LAYER
	if l != undefined do
	(
		local all = #(); l.nodes &all
		for n in all where AR_hasPrefix n.name AR_SKIP_PREFIXES do AV_add "FAIL" n ("служебный узел в слое " + AR_EXPORT_LAYER)
	)
	local verdict = if AV_fails > 0 then "FAIL -- экспорт запрещён" else if AV_warns > 0 then "OK с предупреждениями" else "OK"
	append AV_lines ("=== ИТОГ: " + verdict + "  (FAIL " + AV_fails as string + ", WARN " + AV_warns as string + ", узлов " + nodes.count as string + ") ===")
	local rp = ""
	if writeReport and maxFilePath != "" do
	(
		-- maxFilePath = <repo>Source<Asset> (с хвостовым ) -> <repo>xport_logs
		local repo = pathConfig.removePathLeaf (pathConfig.removePathLeaf maxFilePath)
		local dir = repo + "\\Export\\_logs"
		makeDir dir all:true
		rp = dir + "\\validate_" + scene + "_" + ((dotNetClass "System.DateTime").Now.ToString "yyyy-MM-dd_HHmmss") + ".txt"
		local f = createFile rp encoding:#utf8
		for s in AV_lines do format "%\n" s to:f
		close f
	)
	for s in AV_lines do format "%\n" s
	#(AV_fails, AV_warns, rp)
)

-- запуск как скрипта художником: проверка + окно с итогом
if not (isKindOf AV_SILENT BooleanClass and AV_SILENT) do
(
	local r = AV_validate()
	messageBox ((AV_lines[AV_lines.count]) + "\n\nОтчёт: " + r[3]) title:"Asset Validator"
)
