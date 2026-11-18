/*
	make_template.ms -- собирает Template/Template.max (ASSET_RULES §2–3) из текущей сессии, не трогая открытую сцену:
	  * эталон REF_Human_180 (манекен 180 см, стоит на Z=0, лицом к -Y, слой REF, заморожен, не рендерится);
	  * пустые слои Export и Source_HP; системные единицы -- сантиметры.
	Запуск:  fileIn "<repo>/Tools/make_template.ms"   (функция MT_makeRefHuman доступна и отдельно)
*/
fn MT_part obj parts = (convertToMesh obj; append parts obj; obj)

fn MT_makeRefHuman name:"REF_Human_180" =
(
	local p = #()
	-- размеры в см: рост 180, ширина плеч ~44
	MT_part (Cylinder radius:6.5 height:84 sides:12 pos:[-10, 0, 0]) p        -- левая нога
	MT_part (Cylinder radius:6.5 height:84 sides:12 pos:[10, 0, 0]) p         -- правая нога
	MT_part (ChamferBox width:36 length:22 height:60 fillet:5 fillet_segments:2 pos:[0, 0, 84]) p   -- торс 84..144
	MT_part (Cylinder radius:5 height:10 sides:10 pos:[0, 0, 144]) p           -- шея
	MT_part (Sphere radius:13 segs:16 pos:[0, 0, 167]) p                       -- голова, макушка 180
	local la = Cylinder radius:4.5 height:62 sides:10 pos:[-22, 0, 82]
	MT_part la p
	local ra = Cylinder radius:4.5 height:62 sides:10 pos:[22, 0, 82]
	MT_part ra p
	MT_part (Box width:8 length:4 height:2 pos:[0, -13, 167]) p                -- «нос»: лицо смотрит в -Y (вперёд в Max = вперёд в Unity)
	local m = p[1]
	for i = 2 to p.count do meshop.attach m p[i]
	m.name = name
	m.pivot = [0, 0, 0]
	m.wirecolor = color 255 200 0
	m.renderable = false
	m.material = undefined
	setUserProp m "note" "эталон роста 180 см, в экспорт не идёт"
	local l = LayerManager.getLayerFromName "REF"
	if l == undefined do l = LayerManager.newLayerFromName "REF"
	l.addNode m
	freeze m
	m
)

fn MT_saveTemplate outFile =
(
	makeDir (getFilenamePath outFile) all:true
	local ref = MT_makeRefHuman()
	for n in #("Export", "Source_HP") where LayerManager.getLayerFromName n == undefined do LayerManager.newLayerFromName n
	local h = (ref.max.z - ref.min.z)
	saveNodes #(ref) outFile quiet:true
	delete ref
	#(outFile, h)
)

if not (isKindOf MT_NO_AUTORUN BooleanClass and MT_NO_AUTORUN) do
	MT_saveTemplate ((pathConfig.removePathLeaf (getFilenamePath (getThisScriptFilename()))) + "\\Template\\Template.max")
