[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$metadataPath = Join-Path $PSScriptRoot '.local\web-online-service.json'
if (-not (Test-Path -LiteralPath $metadataPath)) { Write-Host 'No managed web service is recorded.'; exit 0 }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$serviceProcess = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$metadata.pid)
if (-not $serviceProcess) { Write-Host 'The local web service is already stopped.'; exit 0 }
$expectedScript = Join-Path $PSScriptRoot 'web\server.py'
if (-not $serviceProcess.CommandLine.Contains($expectedScript) -or $serviceProcess.Name -notmatch '^python') {
    throw 'The recorded process no longer matches this project. No process was stopped.'
}
# A Windows virtualenv launcher can own a child Python process that holds the port.
$children = @(Get-CimInstance Win32_Process -Filter ('ParentProcessId = ' + [int]$metadata.pid))
foreach ($child in $children) {
    if ($child.Name -match '^python' -and $child.CommandLine -and $child.CommandLine.Contains($expectedScript)) {
        Stop-Process -Id ([int]$child.ProcessId) -ErrorAction SilentlyContinue
    }
}
Stop-Process -Id ([int]$metadata.pid) -ErrorAction SilentlyContinue
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if (-not (Get-NetTCPConnection -LocalPort ([int]$metadata.port) -State Listen -ErrorAction SilentlyContinue)) { break }
    Start-Sleep -Milliseconds 100
}
if (Get-NetTCPConnection -LocalPort ([int]$metadata.port) -State Listen -ErrorAction SilentlyContinue) {
    throw 'The port is still occupied; inspect its owner before stopping any other process.'
}
Write-Host 'The local web service is stopped. Browser character saves are unchanged.'
