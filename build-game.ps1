[CmdletBinding()]
param(
    [switch]$Web,
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    $candidates += 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Godot 4.7.2 was not found. Set GODOT_PATH or run build-game.ps1 -GodotPath <exe-path>.'
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -ne '' -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-GodotBuildStep {
    param([string]$Name, [string[]]$Arguments, [string]$ExecutablePath)

    Write-Host "[$Name]"
    $stdoutPath = Join-Path $logDirectory ($Name + '.stdout.log')
    $stderrPath = Join-Path $logDirectory ($Name + '.stderr.log')
    $argumentLine = ($Arguments | ForEach-Object { ConvertTo-NativeArgument -Value $_ }) -join ' '
    $runPath = if ($ExecutablePath) { $ExecutablePath } else { $enginePath }
    $process = Start-Process -FilePath $runPath -ArgumentList $argumentLine -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -Wait -PassThru
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($stderr) { Write-Host $stderr.TrimEnd() }
    if ($process.ExitCode -ne 0 -or ($stdout + "`n" + $stderr) -match '(?m)^(SCRIPT ERROR|ERROR):|Parse Error:') {
        throw "$Name failed (exit $($process.ExitCode)). See build/logs/$Name.*.log."
    }
}

$enginePath = Find-Godot -RequestedPath $GodotPath
$projectPath = Join-Path $PSScriptRoot 'game'
$versionMatch = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectPath 'project.godot') -Raw), '(?m)^config/version="([^"]+)"')
if (-not $versionMatch.Success) { throw 'Project version is missing.' }
$releaseReportDirectory = Join-Path $PSScriptRoot ('docs\verification\v' + $versionMatch.Groups[1].Value)
$windowsDirectory = Join-Path $PSScriptRoot 'build\windows'
$logDirectory = Join-Path $PSScriptRoot 'build\logs'
New-Item -ItemType Directory -Path $windowsDirectory, $logDirectory, $releaseReportDirectory -Force | Out-Null

& python -X utf8 (Join-Path $PSScriptRoot 'scripts\build_learning_content.py')
if ($LASTEXITCODE -ne 0) { throw 'Learning content build failed.' }
& (Join-Path $PSScriptRoot 'scripts\build_prologue_audio.ps1')
& uv run --with fonttools==4.61.1 python -X utf8 (Join-Path $PSScriptRoot 'scripts\build_font.py') --check
if ($LASTEXITCODE -ne 0) { throw 'Bundled font coverage failed. Run scripts/build_font.py to rebuild it.' }

Invoke-GodotBuildStep -Name 'import' -Arguments @('--headless', '--path', $projectPath, '--editor', '--import')
Invoke-GodotBuildStep -Name 'state-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_state.gd')
Invoke-GodotBuildStep -Name 'journey-state-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_journey_state.gd')
Invoke-GodotBuildStep -Name 'memory-event-sink-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_memory_event_sink.gd')
Invoke-GodotBuildStep -Name 'memory-story-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_memory_story.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'learning-art-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_learning_art_all.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'living-world-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_living_world.gd')
Invoke-GodotBuildStep -Name 'p1-actor-animation-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_p1_actor_animation.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'p1-story-animation-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_p1_story_animation.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'p1-story-specials-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_p1_story_specials.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'p1-orchard-tests' -Arguments @('--headless', '--path', $projectPath, '--script', 'res://tests/test_p1_orchard.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'journey-game-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_journey_game.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'movement-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_movement.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'school-hierarchy-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_school_hierarchy.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'blender-world-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_blender_world.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'ui-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_ui.gd', '--', '--test-harness')
Invoke-GodotBuildStep -Name 'life-ui-tests' -Arguments @('--headless', '--fixed-fps', '60', '--path', $projectPath, '--script', 'res://tests/test_life_ui.gd', '--', '--test-harness', ('--report-dir=' + $releaseReportDirectory))
Invoke-GodotBuildStep -Name 'integration-tests' -Arguments @('--headless', '--path', $projectPath, '--', '--validate')
$windowsOutput = Join-Path $windowsDirectory 'AlphabetIsland.exe'
Invoke-GodotBuildStep -Name 'windows-export' -Arguments @('--headless', '--path', $projectPath, '--export-release', 'Windows Desktop', $windowsOutput)
foreach ($requiredFile in @($windowsOutput, (Join-Path $windowsDirectory 'AlphabetIsland.pck'))) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Export did not produce the expected file: $requiredFile"
    }
}
New-Item -ItemType Directory -Path $releaseReportDirectory -Force | Out-Null
Invoke-GodotBuildStep -Name 'release-smoke' -ExecutablePath $windowsOutput -Arguments @('--headless', '--', '--test-harness', '--release-smoke', ('--smoke-report=' + (Join-Path $releaseReportDirectory 'release-smoke-report.json')))

$licenseDirectory = Join-Path $windowsDirectory 'LICENSES'
New-Item -ItemType Directory -Path $licenseDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectPath 'assets\fonts\LICENSE.txt') -Destination (Join-Path $licenseDirectory 'IslandSans-OFL.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'assets\fonts\COPYRIGHT.txt') -Destination (Join-Path $licenseDirectory 'IslandSans-COPYRIGHT.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'docs\licenses\Godot-4.7.2-notices.txt') -Destination (Join-Path $licenseDirectory 'Godot-4.7.2-notices.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'docs\Blender地图版游玩说明.md') -Destination (Join-Path $windowsDirectory '游玩说明.md') -Force

if ($Web) {
    $webDirectory = Join-Path $PSScriptRoot 'build\web'
    New-Item -ItemType Directory -Path $webDirectory -Force | Out-Null
    Invoke-GodotBuildStep -Name 'web-export' -Arguments @('--headless', '--path', $projectPath, '--export-release', 'Web Preview', (Join-Path $webDirectory 'index.html'))
    Write-Host 'Web preview exported to build/web. Serve this folder over HTTP; do not open index.html as a local file.'
}

Write-Host 'Windows build ready: build/windows/AlphabetIsland.exe'
Write-Host 'Keep AlphabetIsland.exe and AlphabetIsland.pck together when copying the game.'
