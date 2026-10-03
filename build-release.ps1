[CmdletBinding()]
param([Parameter(Mandatory)][string]$Version, [switch]$SkipModuleDownload)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Toolkit = Join-Path $ProjectRoot 'toolkit'
. (Join-Path $ProjectRoot 'scripts/Prepare-BootAssets.ps1')
$Dist = Join-Path $ProjectRoot 'dist'
if (-not $SkipModuleDownload) { & (Join-Path $ProjectRoot 'scripts/Fetch-Modules.ps1') }

foreach ($Required in @('packages/modules/KPA_MYuppy_Font.zip','packages/modules/KPA_RGB_Control.zip','packages/modules/PlayIntegrityFork.zip','packages/modules/Shamiko.zip','packages/modules/DolbyAtmos_RazerPhone2_v1.0.6_fix.zip')) {
    if (-not (Test-Path (Join-Path $Toolkit $Required))) { throw "Missing $Required" }
}
foreach ($Required in @('scripts/OtaBoot.ps1','tools/ota/payload_dumper.exe','tools/ota/PAYLOAD_DUMPER_LICENSE.txt')) {
    if (-not (Test-Path (Join-Path $Toolkit $Required))) { throw "Missing $Required" }
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$Output = Join-Path $Dist "KPA_Root_v$Version.zip"
if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
$Stage = Join-Path $Dist ('.stage-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $Stage | Out-Null
    Get-ChildItem -LiteralPath $Toolkit -Force | Copy-Item -Destination $Stage -Recurse -Force

    # The stable release is a Pocket Advance-only package. Other profiles and
    # source-only templates remain in the repository but never enter this ZIP.
    foreach ($Relative in @('devices\air-mini','devices\template')) {
        $Target = Join-Path $Stage $Relative
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
    }
    $Logs = Join-Path $Stage 'logs'
    if (Test-Path -LiteralPath $Logs) { Remove-Item -LiteralPath $Logs -Recurse -Force }
    Get-ChildItem -LiteralPath (Join-Path $Stage 'devices') -Directory | ForEach-Object {
        $OtaState = Join-Path $_.FullName 'ota'
        if (Test-Path -LiteralPath $OtaState) { Remove-Item -LiteralPath $OtaState -Recurse -Force }
    }
    # 已知版本原版与修补镜像均随包提供，并按机型目录表校验。
    # Bundle and verify catalog stock/patched images for offline operation.
    Initialize-KpaReleaseBootAssets (Join-Path $Stage 'devices/pocket-advance')
    Get-ChildItem -LiteralPath $Stage -File -Filter '*_Log_*.txt' | Remove-Item -Force
    $Profiles = @(Get-ChildItem -LiteralPath (Join-Path $Stage 'devices') -Directory)
    if ($Profiles.Count -ne 1 -or $Profiles[0].Name -ne 'pocket-advance') {
        throw 'Stable package contains an unexpected device profile.'
    }
    $ExpectedModules = @('DolbyAtmos_RazerPhone2_v1.0.6_fix.zip','KPA_MYuppy_Font.zip','KPA_RGB_Control.zip','PlayIntegrityFork.zip','Shamiko.zip')
    $Modules = @(Get-ChildItem -LiteralPath (Join-Path $Stage 'packages\modules') -File -Filter '*.zip' | Select-Object -ExpandProperty Name | Sort-Object)
    if (($Modules -join ',') -ne ($ExpectedModules -join ',')) {
        throw "Stable package contains unexpected modules: $($Modules -join ', ')"
    }
    $PackageFiles = Get-ChildItem -LiteralPath $Stage -Force
    Compress-Archive -LiteralPath $PackageFiles.FullName -DestinationPath $Output -CompressionLevel Optimal
} finally {
    if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}
Write-Host "Built $Output"
Write-Host "SHA256=$((Get-FileHash $Output -Algorithm SHA256).Hash)"
