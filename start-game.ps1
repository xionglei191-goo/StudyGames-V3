[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$Built,
    [string]$GodotPath,
    [string]$ProfileId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Editor -and $Built) {
    throw 'Choose either -Editor or -Built. The default runs the current local project.'
}
if ($ProfileId -and ($Editor -or $Built)) {
    throw '-ProfileId is available when running the current game. Editor and older builds have their own save entry.'
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
    Write-Host 'Alphabet Island started from the explicitly selected older Windows build. This entry does not use shared profiles; run without -Built for shared desktop/web progress.'
    return
}

$enginePath = Find-Godot -RequestedPath $GodotPath
# Prefer the graphical sibling so a playable game does not leave a console window behind.
if ($enginePath -match '_console\.exe$') {
    $graphicalPath = $enginePath -replace '_console\.exe$', '.exe'
    if (Test-Path -LiteralPath $graphicalPath -PathType Leaf) { $enginePath = $graphicalPath }
}
if ($Editor) {
    $arguments = '--path "' + $projectPath + '" --editor'
    Start-Process -FilePath $enginePath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Normal | Out-Null
    Write-Host 'Godot editor opened. Editor play uses its own development save; start-game.ps1 without -Editor uses shared profiles.'
    return
}

$pythonPath = Join-Path $PSScriptRoot '.local\web-online-venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    $pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pythonCommand) { throw 'Python 3 is required for shared profile locking. Install Python or run start-web-online.ps1 once.' }
    $pythonPath = $pythonCommand.Source
}
$statusDirectory = Join-Path $PSScriptRoot '.local\native-launches'
New-Item -ItemType Directory -Path $statusDirectory -Force | Out-Null
$statusPath = Join-Path $statusDirectory (([guid]::NewGuid().ToString('N')) + '.json')
$runner = Join-Path $PSScriptRoot 'web\native_runner.py'
$arguments = '"' + $runner + '" --godot "' + $enginePath + '" --status-file "' + $statusPath + '"'
if ($ProfileId) {
    if ($ProfileId -notmatch '^[a-f0-9]{24}$') { throw 'ProfileId must be an existing 24-character shared profile ID.' }
    $arguments += ' --profile-id ' + $ProfileId
}
$supervisor = Start-Process -FilePath $pythonPath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(12)
while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $statusPath)) {
    Start-Sleep -Milliseconds 100
    $supervisor.Refresh()
    if ($supervisor.HasExited) { break }
}
if (-not (Test-Path -LiteralPath $statusPath)) { throw "The shared-profile launcher did not report a result. Check $statusDirectory" }
$launch = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $launch.ok) { throw $launch.error }
Write-Host ('Alphabet Island started with shared profile: ' + $launch.profile_id)
