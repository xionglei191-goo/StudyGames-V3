[CmdletBinding()]
param(
    [string]$GodotPath = 'F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    [ValidateSet(1, 2)][int]$MaxProcesses = 2,
    [ValidateSet('world', 'school', 'home', 'movement')]
    [string[]]$Suites = @('world', 'school', 'home', 'movement'),
    [ValidateRange(60, 7200)][int]$TimeoutSeconds = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$projectPath = Join-Path $repoRoot 'game'
$reportDirectory = Join-Path $repoRoot 'docs/verification/drive-model-sync-own16-20261027/headless'
$runDirectory = Join-Path $reportDirectory ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
New-Item -ItemType Directory -Path $runDirectory | Out-Null

function Quote-NativeArgument {
    param([string]$Value)
    if ($Value -ne '' -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

$definitions = @{
    world = @{ Script = 'test_world_refinement.gd'; Report = 'world-refinement-ABCDEFGHIJKLMNOPQRSTUVWXYZ.json' }
    school = @{ Script = 'test_school_hierarchy.gd'; Report = 'school-hierarchy-report.json' }
    home = @{ Script = 'test_home_indoor.gd'; Report = 'home-indoor-report.json' }
    movement = @{ Script = 'test_movement.gd'; Report = 'movement-report.json' }
}
$pending = [System.Collections.Generic.Queue[string]]::new()
foreach ($suiteName in ($Suites | Select-Object -Unique)) { $pending.Enqueue($suiteName) }
$running = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$startedAt = [DateTime]::UtcNow

try {
    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        while ($pending.Count -gt 0 -and $running.Count -lt $MaxProcesses) {
            $suiteName = $pending.Dequeue()
            $definition = $definitions[$suiteName]
            $arguments = @('--headless', '--fixed-fps', '60', '--path', $projectPath,
                '--script', ('res://tests/drive_model_sync/' + $definition.Script), '--', '--test-harness')
            $stdoutPath = Join-Path $runDirectory ($suiteName + '.stdout.log')
            $stderrPath = Join-Path $runDirectory ($suiteName + '.stderr.log')
            $startTime = [DateTime]::UtcNow
            $process = Start-Process -FilePath $GodotPath -ArgumentList (($arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' ') -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
            $running.Add([pscustomobject]@{ Name = $suiteName; Process = $process; Started = $startTime; Stdout = $stdoutPath; Stderr = $stderrPath; Report = $definition.Report; Arguments = $arguments })
            Write-Output ("START {0} pid={1}" -f $suiteName, $process.Id)
        }
        foreach ($item in @($running.ToArray())) {
            $item.Process.Refresh()
            $timedOut = (-not $item.Process.HasExited) -and (([DateTime]::UtcNow - $item.Started).TotalSeconds -gt $TimeoutSeconds)
            if ($timedOut) {
                Stop-Process -Id $item.Process.Id -Force
                $item.Process.WaitForExit()
            }
            if (-not $item.Process.HasExited) { continue }
            $item.Process.WaitForExit()
            $exitCode = $item.Process.ExitCode
            $reportPath = Join-Path $reportDirectory $item.Report
            $report = $null
            $reportFresh = (Test-Path -LiteralPath $reportPath -PathType Leaf) -and ((Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -ge $item.Started.AddSeconds(-1))
            $reportError = $null
            if ($reportFresh) {
                Copy-Item -LiteralPath $reportPath -Destination (Join-Path $runDirectory $item.Report)
                try { $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json }
                catch { $reportError = $_.Exception.Message }
            }
            $engineErrors = @(Select-String -LiteralPath $item.Stderr -Pattern '^SCRIPT ERROR:|^ERROR:|Parse Error:' | ForEach-Object { $_.Line })
            $passed = -not $timedOut -and $exitCode -eq 0 -and $reportFresh -and $null -ne $report -and $report.passed -and $report.complete -and $report.production_save_unchanged -and $engineErrors.Count -eq 0
            $result = [pscustomobject]@{
                suite = $item.Name
                pid = $item.Process.Id
                started_utc = $item.Started.ToString('o')
                finished_utc = [DateTime]::UtcNow.ToString('o')
                exit_code = $exitCode
                timed_out = $timedOut
                report_fresh = $reportFresh
                report_parse_error = $reportError
                passed = $passed
                report = $(if ($reportFresh) { $item.Report } else { $null })
                engine_errors = $engineErrors
                command_arguments = $item.Arguments
            }
            $results.Add($result)
            [void]$running.Remove($item)
            Write-Output ("FINISH {0} exit={1} passed={2}" -f $item.Name, $exitCode, $passed)
        }
        $summary = [ordered]@{
            started_utc = $startedAt.ToString('o')
            updated_utc = [DateTime]::UtcNow.ToString('o')
            max_processes = $MaxProcesses
            requested_suites = $Suites
            complete = $pending.Count -eq 0 -and $running.Count -eq 0
            passed = $pending.Count -eq 0 -and $running.Count -eq 0 -and @($results | Where-Object { -not $_.passed }).Count -eq 0
            running = @($running | ForEach-Object { [pscustomobject]@{ suite = $_.Name; pid = $_.Process.Id } })
            results = @($results.ToArray())
        }
        $summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Encoding utf8
        if ($running.Count -gt 0) { Start-Sleep -Milliseconds 500 }
    }
}
finally {
    foreach ($item in @($running.ToArray())) {
        $item.Process.Refresh()
        if (-not $item.Process.HasExited) { Stop-Process -Id $item.Process.Id -Force }
    }
}

Write-Output ('REPORT_DIRECTORY ' + $runDirectory)
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
