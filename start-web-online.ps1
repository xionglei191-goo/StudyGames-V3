[CmdletBinding()]
param([int]$Port = 4189, [string]$ListenAddress = '127.0.0.1', [switch]$Build, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Choose a port between 1024 and 65535.' }
if ($ListenAddress -notin @('127.0.0.1', '0.0.0.0')) { throw 'Choose 127.0.0.1 (local) or 0.0.0.0 (LAN).' }
$pythonPath = Join-Path $PSScriptRoot '.local\web-online-venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) {
    $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCommand) {
        & $uvCommand.Source venv --python 3.14 (Join-Path $PSScriptRoot '.local\web-online-venv')
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the web service environment.' }
        & $uvCommand.Source pip install --python $pythonPath -r (Join-Path $PSScriptRoot 'web\requirements.txt')
    } else {
        & py -3 -m venv (Join-Path $PSScriptRoot '.local\web-online-venv')
        if ($LASTEXITCODE -ne 0) { throw 'Install Python 3.11 or newer and retry.' }
        & $pythonPath -m pip install -r (Join-Path $PSScriptRoot 'web\requirements.txt')
    }
    if ($LASTEXITCODE -ne 0) { throw 'Could not install the web service dependencies.' }
}
if ($Build -or -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build\web-online\index.html'))) {
    & (Join-Path $PSScriptRoot 'build-web-online.ps1')
}
$url = 'http://127.0.0.1:' + $Port + '/'
$alreadyRunning = $false
try {
    $health = Invoke-RestMethod -Uri ($url + 'health') -TimeoutSec 2
    if ($health.service -ne 'alphabet-island-online') { throw 'Another service owns this port.' }
    $alreadyRunning = $true
} catch {
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
        throw ('Port ' + $Port + ' is already occupied. Choose another -Port.')
    }
}
if (-not $alreadyRunning) {
    $serviceScript = Join-Path $PSScriptRoot 'web\server.py'
    $stdoutPath = Join-Path $PSScriptRoot '.local\web-online-server.stdout.log'
    $stderrPath = Join-Path $PSScriptRoot '.local\web-online-server.stderr.log'
    $arguments = '"' + $serviceScript + '" --host "' + $ListenAddress + '" --port ' + $Port
    $serviceProcess = Start-Process -FilePath $pythonPath -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    @{pid=$serviceProcess.Id;port=$Port;host=$ListenAddress;script=$serviceScript} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.local\web-online-service.json') -Encoding UTF8
    $serviceReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($serviceProcess.HasExited) { break }
        try {
            $health = Invoke-RestMethod -Uri ($url + 'health') -TimeoutSec 1
            if ($health.service -eq 'alphabet-island-online') { $serviceReady = $true; break }
        } catch {}
        Start-Sleep -Milliseconds 250
    }
    if (-not $serviceReady) { throw ('The web service did not become ready. See ' + $stderrPath) }
}
if (-not $NoBrowser) { Start-Process $url }
Write-Host ('Alphabet Island online: ' + $url)
Write-Host 'The local service runs in the background. Use stop-web-online.ps1 to stop it.'
