[CmdletBinding()]
param([string]$GodotPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$enginePath = $GodotPath
if (-not $enginePath) { $enginePath = $env:GODOT_PATH }
if (-not $enginePath) { $enginePath = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) { throw 'Set -GodotPath to the matching Godot executable.' }
$buildDirectory = Join-Path $PSScriptRoot 'build\web-online'
$logDirectory = Join-Path $PSScriptRoot 'build\logs'
New-Item -ItemType Directory -Path $buildDirectory, $logDirectory -Force | Out-Null
$exportLog = Join-Path $logDirectory 'web-online-export.log'
& $enginePath --headless --path (Join-Path $PSScriptRoot 'game') --export-release 'Web Online' (Join-Path $buildDirectory 'index.html') *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern '^SCRIPT ERROR:|^ERROR:|Parse Error:' -Quiet)) {
    Get-Content -LiteralPath $exportLog -Tail 50
    throw 'Web export failed. See build/logs/web-online-export.log.'
}
foreach ($name in @('lobby.js', 'lobby.css', 'shared_save.js')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('game\web\' + $name)) -Destination (Join-Path $buildDirectory $name) -Force
}
$preview = Join-Path $PSScriptRoot 'docs\verification\world-refinement\after\06\village-overview.png'
if (-not (Test-Path -LiteralPath $preview -PathType Leaf)) {
    $preview = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'docs\verification\world-refinement\after') -Filter 'village-overview.png' -Recurse | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $preview) { throw 'The verified island preview is missing.' }
Copy-Item -LiteralPath $preview -Destination (Join-Path $buildDirectory 'island-preview.png') -Force
& py -3 -X utf8 (Join-Path $PSScriptRoot 'scripts\pack_web_rooms.py')
if ($LASTEXITCODE -ne 0) { throw 'Web room packaging failed.' }
& py -3 -X utf8 (Join-Path $PSScriptRoot 'scripts\prepare_web_runtime.py')
if ($LASTEXITCODE -ne 0) { throw 'Web profile persistence setup failed.' }
Get-ChildItem -LiteralPath $buildDirectory -File | Select-Object Name, Length
Write-Host 'Web build ready. Start start-web-online.ps1 and open http://127.0.0.1:4189/.'
