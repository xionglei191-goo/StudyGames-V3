[CmdletBinding()]
param(
    [switch]$SyncOnly,
    [switch]$SkipBuild,
    [string]$BlenderPath,
    [string]$PythonPath,
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $PythonPath) {
    $candidates = @()
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $detectedPython = & py -3 -c 'import sys; print(sys.executable)'
        if ($LASTEXITCODE -eq 0 -and $detectedPython) { $candidates += $detectedPython.Trim() }
    }
    $candidates += @(
        (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'),
        'F:\Tools\BlenderMCP\tools\mcp-for-blender\Scripts\python.exe'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $PythonPath = $candidate; break }
    }
}
if (-not $PythonPath -or -not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    throw 'Python not found. Pass -PythonPath with a Python installation containing fontTools.'
}
if (-not $BlenderPath) { $BlenderPath = 'F:\Tools\Blender\blender-5.2.2-windows-x64\blender.exe' }

Push-Location $PSScriptRoot
try {
    if (-not $SyncOnly) {
        if (-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)) { throw 'Blender not found. Pass -BlenderPath.' }
        Write-Host '[Exporting saved Blender world]'
        & $PythonPath scripts\sync_blender_world.py --export --blender $BlenderPath
        if ($LASTEXITCODE -ne 0) { throw 'World export failed; game build was not replaced.' }
        Write-Host '[Exporting saved Blender rooms]'
        $exporter = Join-Path $PSScriptRoot 'assets\blender\interiors\scripts\export_existing.py'
        if (-not (Test-Path -LiteralPath $exporter -PathType Leaf)) { throw 'The Blender room exporter is missing.' }
        & $BlenderPath --background --factory-startup --python $exporter -- --all
        if ($LASTEXITCODE -ne 0) { throw 'Room export failed; game build was not replaced.' }
    } else {
        & $PythonPath scripts\sync_blender_world.py
        if ($LASTEXITCODE -ne 0) { throw 'World synchronization failed.' }
    }
    & $PythonPath scripts\sync_blender_interiors.py --require-all
    if ($LASTEXITCODE -ne 0) { throw 'Room synchronization failed.' }
    & $PythonPath scripts\build_font.py
    if ($LASTEXITCODE -ne 0) { throw 'Font update failed.' }
    if (-not $SkipBuild) {
        $buildArgs = @{}
        if ($GodotPath) { $buildArgs.GodotPath = $GodotPath }
        & (Join-Path $PSScriptRoot 'build-game.ps1') @buildArgs
    }
    Write-Host 'Blender map update completed.'
} finally {
    Pop-Location
}
