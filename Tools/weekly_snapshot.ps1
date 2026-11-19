# weekly_snapshot.ps1 — пятничный снимок исходников (Стандарт 3D-пайплайна, раздел 3).
# Коммитит изменения в Source/ и Export/ проекта 3D-Assistant и ставит тег art-ГГГГ-WНН (ISO-неделя), пушит в origin.
# Расписание: задача Windows «Art weekly snapshot», пятница 20:00 (Register-ScheduledTask, см. Docs/ASSET_RULES.md).
# Защита: любая ошибка git — стоп без коммита; в снимок попадают только Source/ и Export/,
# удаление файлов вне них — стоп. Журнал: Export/_logs/snapshot_log.txt (ошибки — в %LOCALAPPDATA%\art_snapshot_error.log).
param([string]$Repo = (Resolve-Path "$PSScriptRoot\..\..\..\..\..").Path)

$ErrorActionPreference = "Stop"
$proj = "3dsMax/Claude Environment/Project/3D-Assistant"
$now = Get-Date
# ISO-неделя (работает и в Windows PowerShell 5.1, где нет [ISOWeek]): берём четверг этой недели
$thu = $now.Date.AddDays(3 - (([int]$now.DayOfWeek + 6) % 7))
$week = [int][math]::Floor(($thu.DayOfYear - 1) / 7) + 1
$tag = "art-{0}-W{1:D2}" -f $thu.Year, $week
$errLog = Join-Path $env:LOCALAPPDATA "art_snapshot_error.log"

function Git-Run {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    # в PowerShell 5.1 stderr git (предупреждения LF/CRLF) при Stop превращается в исключение — здесь судим только по коду выхода
    $ErrorActionPreference = "Continue"
    $out = & git @GitArgs 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') -> код $LASTEXITCODE`n$($out -join "`n")" }
    $out
}

try {
    Set-Location $Repo
    $branch = (Git-Run rev-parse --abbrev-ref HEAD | Select-Object -Last 1).ToString().Trim()
    Git-Run pull --quiet --ff-only origin $branch | Out-Null

    $logFile = "$proj/Export/_logs/snapshot_log.txt"
    Add-Content -Path $logFile -Encoding UTF8 -Value ("{0:yyyy-MM-dd HH:mm}  {1}  ветка {2}" -f $now, $tag, $branch)

    Git-Run add -- "$proj/Source" "$proj/Export" | Out-Null
    # в индексе не должно быть ничего вне Source/ и Export/ и никаких удалений вне них
    $staged = Git-Run diff --cached --name-status -M
    $bad = $staged | Where-Object { $_ -and ($_ -notmatch [regex]::Escape("$proj/Source/")) -and ($_ -notmatch [regex]::Escape("$proj/Export/")) }
    if ($bad) { Git-Run reset --quiet | Out-Null; throw "в снимок попали файлы вне Source/ и Export/ — стоп:`n$($bad -join "`n")" }
    # удаление исходника автоснимком недопустимо (часто это сбой checkout, например путь > 260 символов); удалять — руками отдельным коммитом
    $del = $staged | Where-Object { $_ -match '^D\s' }
    if ($del) { Git-Run reset --quiet | Out-Null; throw "в снимке есть удалённые файлы — стоп, удалите их отдельным коммитом вручную:`n$($del -join "`n")" }

    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { Git-Run commit --quiet -m ("art: snapshot {0:yyyy-MM-dd} ({1})" -f $now, $tag) | Out-Null }
    if (-not (& git tag --list $tag)) { Git-Run tag -a $tag -m ("Art snapshot {0} ({1:yyyy-MM-dd HH:mm})" -f $tag, $now) | Out-Null }
    Git-Run push --quiet origin $branch | Out-Null
    Git-Run push --quiet origin $tag | Out-Null
    $msg = "snapshot: $tag -> $((Git-Run rev-parse --short $tag | Select-Object -Last 1).ToString().Trim())"
    Write-Output $msg
} catch {
    Add-Content -Path $errLog -Encoding UTF8 -Value ("{0:yyyy-MM-dd HH:mm}  ОШИБКА  {1}" -f (Get-Date), $_)
    Write-Error $_
    exit 1
}
