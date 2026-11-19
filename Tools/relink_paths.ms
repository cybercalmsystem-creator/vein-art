/*
	relink_paths.ms -- перепривязка путей текстур в открытой сцене к текущему расположению репозитория vein-art.
	Нужен после переноса/клонирования репозитория в другую папку (пути в .max абсолютные).
	Ищет файл по хвосту пути, начиная с папки Source\ или Export\, внутри текущего репозитория.
	Запуск фоном:  3dsmaxbatch.exe Tools\relink_paths.ms -sceneFile Source\Bot6\Bot6.max
	В интерактивном Max:  fileIn "<repo>\Tools\relink_paths.ms"
*/
(
	local repo = pathConfig.removePathLeaf (pathConfig.removePathLeaf maxFilePath)   -- <repo>\Source\<Asset>\ -> <repo>
	local fixed = 0; local missing = #(); local same = 0
	for b in (getClassInstances BitmapTexture) where b.filename != undefined and b.filename != "" do
	(
		local f = b.filename
		local i = findString f "\\Source\\"
		if i == undefined do i = findString f "\\Export\\"
		if i != undefined then
		(
			local nf = repo + (substring f i -1)
			if (toLower nf) == (toLower f) then same += 1
			else if doesFileExist nf then (b.filename = nf; fixed += 1)
			else append missing f
		)
		else if not (doesFileExist f) do append missing f
	)
	local msg = "relink_paths: repo=" + repo + " fixed=" + fixed as string + " already_ok=" + same as string + " missing=" + missing.count as string
	for m in missing do msg += "\n  missing: " + m
	format "%\n" msg
	if fixed > 0 do saveMaxFile (maxFilePath + maxFileName) quiet:true
	msg
)
