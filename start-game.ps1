[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$Built,
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Editor -and $Built) {
    throw 'Choose either -Editor or -Built. The default runs the current local project.'
}

function Find-Godot {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "Godot executable not found: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $candidates = @()
    if ($env:GODOT_PATH) { $candidates += $env:GODOT_PATH }
    $candidates += Join-Path $PSScriptRoot '.tools\godot.exe'
    $candidates += Join-Path $PSScriptRoot 'tools\godot.exe'
    foreach ($commandName in @('godot4.exe', 'godot.exe', 'godot4', 'godot')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $candidates += $command.Source }
    }
    $candidates += 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe'
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Godot 4.7.2 was not found. Set GODOT_PATH or run start-game.ps1 -GodotPath <exe-path>.'
}

$projectPath = Join-Path $PSScriptRoot 'game'
$builtGame = Join-Path $PSScriptRoot 'build\windows\AlphabetIsland.exe'
$builtPack = Join-Path $PSScriptRoot 'build\windows\AlphabetIsland.pck'

if ($Built) {
    if (-not (Test-Path -LiteralPath $builtGame -PathType Leaf) -or -not (Test-Path -LiteralPath $builtPack -PathType Leaf)) {
        throw 'The requested Windows build is missing. Run without -Built to use the current local project.'
    }
    Start-Process -FilePath $builtGame -WorkingDirectory (Split-Path -Parent $builtGame) -WindowStyle Normal | Out-Null
    Write-Host 'Alphabet Island started from the explicitly selected Windows build; it may be older than the local project.'
    return
}

$enginePath = Find-Godot -RequestedPath $GodotPath
# Prefer the graphical sibling so a playable game does not leave a console window behind.
if ($enginePath -match '_console\.exe$') {
    $graphicalPath = $enginePath -replace '_console\.exe$', '.exe'
    if (Test-Path -LiteralPath $graphicalPath -PathType Leaf) { $enginePath = $graphicalPath }
}
$arguments = '--path "' + $projectPath + '"'
if ($Editor) { $arguments += ' --editor' }
Start-Process -FilePath $enginePath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Normal | Out-Null
Write-Host $(if ($Editor) { 'Godot editor opened.' } else { 'Alphabet Island started from the project.' })
