param([switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$config = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'docs/planning/mainline/alphabet_prologue.json') | ConvertFrom-Json
$destination = Join-Path $root 'game/assets/audio/prologue'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$speaker = New-Object -ComObject SAPI.SpVoice
$english = $speaker.GetVoices() | Where-Object { $_.GetDescription() -like '*Zira*' } | Select-Object -First 1
if (-not $english) { throw 'Microsoft Zira English voice is required for this offline generation step.' }
$speaker.Voice = $english
$speaker.Rate = -2
$records = @()
foreach ($entry in $config.letters) {
    $letter = [string]$entry.letter.uppercase
    foreach ($kind in @('letter', 'word')) {
        $output = Join-Path $destination ($kind + '_' + $letter + '.wav')
        $utterance = if ($kind -eq 'letter') { '<spell>' + $letter + '</spell>' } else { [string]$entry.anchor.canonical_word }
        if ($Force -or -not (Test-Path -LiteralPath $output)) {
            $stream = New-Object -ComObject SAPI.SpFileStream
            $stream.Format.Type = 22
            $stream.Open($output, 3, $false)
            $speaker.AudioOutputStream = $stream
            [void]$speaker.Speak($utterance, $(if ($kind -eq 'letter') { 8 } else { 16 }))
            $stream.Close()
        }
        $records += [ordered]@{ letter = $letter; kind = $kind; text = $(if ($kind -eq 'letter') { $letter } else { [string]$entry.anchor.canonical_word }); path = 'res://assets/audio/prologue/' + [IO.Path]::GetFileName($output); sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = (Get-Item -LiteralPath $output).Length }
    }
}
$manifest = [ordered]@{ schema_version = 1; voice = $english.GetDescription(); kind = 'local_synthetic_speech'; letter_names_use_spell_xml = $true; runtime_network_required = $false; human_listening_review = 'pending'; recordings = $records }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $destination 'manifest.json')
Write-Output ('Generated or reused {0} separate letter-name and landmark-name tracks.' -f $records.Count)
