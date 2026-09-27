[CmdletBinding()]
param([Parameter(Mandatory)][string]$Version, [switch]$SkipModuleDownload)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Toolkit = Join-Path $ProjectRoot 'toolkit'
$Dist = Join-Path $ProjectRoot 'dist'
if (-not $SkipModuleDownload) { & (Join-Path $ProjectRoot 'scripts/Fetch-Modules.ps1') }

foreach ($Required in @('modules/KPA_MYuppy_Font.zip','modules/KPA_RGB_Control.zip','modules/PlayIntegrityFork.zip','modules/Shamiko.zip','modules/DolbyAtmos_RazerPhone2_v1.0.6_fix.zip')) {
    if (-not (Test-Path (Join-Path $Toolkit $Required))) { throw "Missing $Required" }
}
foreach ($Required in @('KPA.OtaBoot.ps1','tools/payload_dumper.exe','tools/PAYLOAD_DUMPER_LICENSE.txt')) {
    if (-not (Test-Path (Join-Path $Toolkit $Required))) { throw "Missing $Required" }
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$Output = Join-Path $Dist "KPA_Root_v$Version.zip"
if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
$RuntimeFiles = @('ota-cache','generated-stock-boots.json','generated-patched-boots.json')
$PackageFiles = Get-ChildItem -LiteralPath $Toolkit -Force | Where-Object {
    $_.Name -notlike '*_Log_*.txt' -and $_.Name -notin $RuntimeFiles
}
Compress-Archive -LiteralPath $PackageFiles.FullName -DestinationPath $Output -CompressionLevel Optimal
Write-Host "Built $Output"
Write-Host "SHA256=$((Get-FileHash $Output -Algorithm SHA256).Hash)"
