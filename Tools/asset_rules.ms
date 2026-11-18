/*
	asset_rules.ms -- машинная часть Docs/ASSET_RULES.md (3ds Max 2027). Подключается из asset_validator.ms и batch_export.ms.
	Меняешь лимиты здесь -- меняй и таблицу в ASSET_RULES.md.
*/
global AR_VERSION = "1.0 (2026-11-18)"

-- префиксы узлов, которые идут в экспорт
global AR_EXPORT_PREFIXES = #("SM_", "SK_", "UCX_")
-- префиксы узлов, которые в экспорт не идут никогда
global AR_SKIP_PREFIXES = #("HP_", "REF_")
global AR_EXPORT_LAYER = "Export"

-- лимит треугольников по классу; класс узла -- user property "asset_class" (prop | npc | character | weapon | env)
global AR_TRI_LIMITS = #(#("prop", 15000), #("npc", 15000), #("character", 30000), #("weapon", 12000), #("env", 5000))
global AR_DEFAULT_CLASS = "prop"
global AR_MAX_TEXTURE = 2048
global AR_MAX_MATERIALS = 1

-- имена: латиница/цифры/_ , без автосуффиксов и "версий в имени"
global AR_NAME_RX = dotNetObject "System.Text.RegularExpressions.Regex" "^[A-Za-z][A-Za-z0-9_]*$"
global AR_BAD_SUFFIX_RX = dotNetObject "System.Text.RegularExpressions.Regex" "(\\.\\d{3}$|(?<![A-Za-z])\\d{3}$|_copy|_final|_v\\d+|_new|_old|_backup)" (dotNetClass "System.Text.RegularExpressions.RegexOptions").IgnoreCase
global AR_TEX_CHANNELS = #("_BaseColor", "_Normal", "_Roughness", "_Metallic", "_AO", "_Emission", "_Opacity", "_Height", "_Mask")

fn AR_triLimitFor node =
(
	local cls = getUserProp node "asset_class"
	if cls == undefined do cls = AR_DEFAULT_CLASS
	cls = toLower (cls as string)
	local lim = undefined
	for p in AR_TRI_LIMITS where p[1] == cls do lim = p[2]
	if lim == undefined do lim = (for p in AR_TRI_LIMITS where p[1] == AR_DEFAULT_CLASS collect p[2])[1]
	#(cls, lim)
)

fn AR_hasPrefix s prefixes = (local r = false; for p in prefixes where (matchPattern s pattern:(p + "*") ignoreCase:false) do r = true; r)

fn AR_isPow2 n = (n > 0 and (bit.and n (n - 1)) == 0)

-- узлы, которые пойдут в экспорт: геометрия слоя Export (без HP_/REF_)
fn AR_exportNodes =
(
	local l = LayerManager.getLayerFromName AR_EXPORT_LAYER
	local res = #()
	if l != undefined do
	(
		local nodes = #()
		l.nodes &nodes
		for n in nodes where (superclassof n == GeometryClass) and not (AR_hasPrefix n.name AR_SKIP_PREFIXES) do append res n
	)
	res
)
