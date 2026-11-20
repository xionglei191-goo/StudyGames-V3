[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 4195,
    [switch]$Foreground,
    [switch]$Restart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-AICompanionReady {
    param([int]$CheckPort)
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$CheckPort/health" -TimeoutSec 2 -ErrorAction Stop
        return ($null -ne $resp -and $resp.ok -eq $true -and $resp.service -eq 'studygames-v4-ai-companion')
    } catch {
        return $false
    }
}

function Test-OwnedCompanionProcess {
    param([int]$ProcessId)
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
    if ($null -eq $process -or [string]::IsNullOrWhiteSpace($process.CommandLine)) { return $false }
    $command = $process.CommandLine.Replace('\\', '\').Replace('/', '\').ToLowerInvariant()
    $projectRoot = $PSScriptRoot.Replace('/', '\').TrimEnd('\').ToLowerInvariant()
    $fromProject = $command.Contains($projectRoot + '\') -or $command.Contains($projectRoot + '"') -or $command.Contains($projectRoot + "'")
    return ($fromProject -and $command -match 'services\.ai_companion\.app(?:\W|$)')
}

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)
if ($Restart -and $listeners.Count -gt 0) {
    # A port number alone is not proof of ownership. Check every listener before
    # stopping any process, including when a different app also exposes /health.
    foreach ($listenerPid in $listeners) {
        if (-not (Test-OwnedCompanionProcess -ProcessId $listenerPid)) {
            throw "Port $Port is used by another application. Its process was left running. Choose another -Port."
        }
    }
    foreach ($listenerPid in $listeners) {
        Stop-Process -Id $listenerPid -Force -ErrorAction Stop
    }
    Start-Sleep -Milliseconds 350
}

if (Test-AICompanionReady -CheckPort $Port) {
    $info = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    $mode = if ($info -and ($info.PSObject.Properties.Name -contains 'llm_provider')) { "$($info.llm_provider) ($($info.llm_model))" } else { 'ready' }
    Write-Host "StudyGames AI Safe Companion is running on http://127.0.0.1:$Port [LLM: $mode]"
    return
}

if (@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count -gt 0) {
    throw "Port $Port is occupied and is not responding as the StudyGames companion. Choose another -Port or check that service."
}

# Find Python 3 with starlette + uvicorn (+ optional edge-tts/miniaudio/piper-tts/vosk in .local/ai-companion-venv)
$pythonCandidates = @()
$localVenvPy = Join-Path $PSScriptRoot '.local\ai-companion-venv\Scripts\python.exe'
if (Test-Path $localVenvPy) {
    $pythonCandidates += $localVenvPy
}
foreach ($cmdName in @('python.exe', 'python3.exe', 'py.exe')) {
    $cmd = Get-Command $cmdName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $pythonCandidates += $cmd.Source }
}

$selectedPython = $null
foreach ($py in $pythonCandidates) {
    try {
        $probe = & $py -c "import starlette, uvicorn; print('OK')" 2>$null
        if ($probe -match 'OK') {
            $selectedPython = $py
            break
        }
    } catch {}
}

if (-not $selectedPython) {
    Write-Warning "Python with starlette/uvicorn was not found; Godot V4 will gracefully use built-in offline companion fallback."
    return
}

$logDir = Join-Path $PSScriptRoot '.local\ai-companion'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stdoutLog = Join-Path $logDir "uvicorn-$Port.out.log"
$stderrLog = Join-Path $logDir "uvicorn-$Port.err.log"

$uvicornArgs = "-X utf8 -m uvicorn services.ai_companion.app:app --host 127.0.0.1 --port $Port"

if ($Foreground) {
    Push-Location -LiteralPath $PSScriptRoot
    try {
        & $selectedPython -X utf8 -m uvicorn services.ai_companion.app:app --host 127.0.0.1 --port $Port
    } finally {
        Pop-Location
    }
    return
}

Start-Process -FilePath $selectedPython -ArgumentList $uvicornArgs -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog | Out-Null

$deadline = [DateTime]::UtcNow.AddSeconds(8)
while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-AICompanionReady -CheckPort $Port) {
        Write-Host "StudyGames V4 AI Safe Companion started on http://127.0.0.1:$Port"
        return
    }
    Start-Sleep -Milliseconds 200
}

Write-Warning "AI Safe Companion sidecar did not respond within 8s (check $stderrLog). Godot client will use built-in fallback."
