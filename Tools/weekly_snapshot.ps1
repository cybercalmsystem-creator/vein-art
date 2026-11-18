# weekly_snapshot.ps1 — пятничный снимок исходников (Стандарт 3D-пайплайна, раздел 3).
# Коммитит изменения в Source/ и Export/ проекта 3D-Assistant и ставит тег art-ГГГГ-WНН (ISO-неделя), пушит в origin.
# Расписание (пятница 20:00), регистрируется один раз:
#   schtasks /Create /SC WEEKLY /D FRI /ST 20:00 /TN "Art weekly snapshot" /TR "powershell -NoProfile -File \"<путь>\weekly_snapshot.ps1\""
param([string]$Repo = (Resolve-Path "$PSScriptRoot\..\..\..\..\..").Path)

$ErrorActionPreference = "Stop"
$proj = "3dsMax/Claude Environment/Project/3D-Assistant"
$now = Get-Date
# ISO-неделя (работает и в Windows PowerShell 5.1, где нет [ISOWeek]): берём четверг этой недели
$thu = $now.Date.AddDays(3 - (([int]$now.DayOfWeek + 6) % 7))
$week = [int][math]::Floor(($thu.DayOfYear - 1) / 7) + 1
$year = $thu.Year
$tag = "art-{0}-W{1:D2}" -f $year, $week

Set-Location $Repo
$branch = (git rev-parse --abbrev-ref HEAD)
git pull --quiet origin $branch
git add -- "$proj/Source" "$proj/Export"
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { git commit --quiet -m ("art: snapshot {0:yyyy-MM-dd} ({1})" -f $now, $tag) }
if (-not (git tag --list $tag)) { git tag -a $tag -m ("Art snapshot {0} ({1:yyyy-MM-dd HH:mm})" -f $tag, $now) }
git push --quiet origin $branch
git push --quiet origin $tag
Write-Output "snapshot: $tag -> $(git rev-parse --short $tag)"
