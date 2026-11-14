[CmdletBinding()]
param(
    [int]$Port = 4195,
    [switch]$Foreground
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-AICompanionReady {
    param([int]$CheckPort)
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$CheckPort/health" -TimeoutSec 2 -ErrorAction Stop
        return ($null -ne $resp -and $resp.ok -eq $true)
    } catch {
        return $false
    }
}

if (Test-AICompanionReady -CheckPort $Port) {
    Write-Host "StudyGames V4 AI Safe Companion is already running on http://127.0.0.1:$Port"
    return
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
$stdoutLog = Join-Path $logDir 'uvicorn.out.log'
$stderrLog = Join-Path $logDir 'uvicorn.err.log'

$uvicornArgs = "-X utf8 -m uvicorn services.ai_companion.app:app --host 127.0.0.1 --port $Port"

if ($Foreground) {
    & $selectedPython -X utf8 -m uvicorn services.ai_companion.app:app --host 127.0.0.1 --port $Port
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
