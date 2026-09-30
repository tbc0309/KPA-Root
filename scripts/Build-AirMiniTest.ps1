[CmdletBinding()]
param([Parameter(Mandatory)][string]$Version)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Toolkit = Join-Path $ProjectRoot 'toolkit'
$Dist = Join-Path $ProjectRoot 'dist'
$Stage = Join-Path $Dist '.stage-air-mini-test'
$DeviceConfig = Import-PowerShellDataFile -LiteralPath (Join-Path $Toolkit 'devices\air-mini\device.psd1')
foreach ($Required in @('PackageName','LauncherTitle')) {
    if (-not $DeviceConfig.ContainsKey($Required) -or [string]::IsNullOrWhiteSpace([string]$DeviceConfig[$Required])) {
        throw "AIR Mini device profile is missing $Required."
    }
}
$Output = Join-Path $Dist ($DeviceConfig.PackageName + '_v' + $Version + '.zip')

if (Test-Path -LiteralPath $Stage) {
    $ResolvedStage = (Resolve-Path -LiteralPath $Stage).Path
    $ExpectedStage = [IO.Path]::GetFullPath($Stage)
    if ($ResolvedStage -ne $ExpectedStage -or (Split-Path -Parent $ResolvedStage) -ne [IO.Path]::GetFullPath($Dist)) {
        throw "Unsafe staging path: $ResolvedStage"
    }
    Remove-Item -LiteralPath $ResolvedStage -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $Stage | Out-Null
try {
    Get-ChildItem -LiteralPath $Toolkit -Force | Copy-Item -Destination $Stage -Recurse -Force

    # CMD launchers run before ADB device detection, so a single-device package
    # receives its user-visible window titles from the selected device profile.
    $LauncherTitles = @{
        '1_Unlock_CN.cmd' = "$($DeviceConfig.LauncherTitle) Bootloader Unlock"
        '1_Unlock_EN.cmd' = "$($DeviceConfig.LauncherTitle) Bootloader Unlock"
        '2_Root_CN.cmd' = "$($DeviceConfig.LauncherTitle) Root"
        '2_Root_EN.cmd' = "$($DeviceConfig.LauncherTitle) Root"
        '3_Restore_CN.cmd' = "$($DeviceConfig.LauncherTitle) Restore Stock Boot"
        '3_Restore_EN.cmd' = "$($DeviceConfig.LauncherTitle) Restore Stock Boot"
    }
    foreach ($Launcher in $LauncherTitles.GetEnumerator()) {
        $LauncherPath = Join-Path $Stage $Launcher.Key
        $Content = [IO.File]::ReadAllText($LauncherPath)
        $TitlePattern = New-Object Text.RegularExpressions.Regex('(?m)^title\s+.*$')
        $Updated = $TitlePattern.Replace($Content, ('title ' + $Launcher.Value), 1)
        if ($Updated -eq $Content) { throw "Launcher title was not updated: $($Launcher.Key)" }
        $Utf8Bom = New-Object Text.UTF8Encoding($true)
        [IO.File]::WriteAllText($LauncherPath, $Updated, $Utf8Bom)
    }

    # Keep only the AIR Mini profile and its approved modules.
    $RemoveTargets = @(
        'devices\pocket-advance',
        'devices\template',
        'devices\air-mini\ota',
        'packages\modules\KPA_MYuppy_Font.zip',
        'packages\modules\KPA_RGB_Control.zip',
        'packages\modules\DolbyAtmos_RazerPhone2_v1.0.6_fix.zip',
        'logs'
    )
    foreach ($Relative in $RemoveTargets) {
        $Target = Join-Path $Stage $Relative
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
    }
    Get-ChildItem -LiteralPath (Join-Path $Stage 'devices') -Recurse -File -Filter 'boot_*_magisk_*.img' | Remove-Item -Force

    $Profiles = @(Get-ChildItem -LiteralPath (Join-Path $Stage 'devices') -Directory)
    if ($Profiles.Count -ne 1 -or $Profiles[0].Name -ne 'air-mini') {
        throw 'AIR Mini package contains an unexpected device profile.'
    }
    $Modules = @(Get-ChildItem -LiteralPath (Join-Path $Stage 'packages\modules') -File -Filter '*.zip' | Select-Object -ExpandProperty Name | Sort-Object)
    if (($Modules -join ',') -ne 'PlayIntegrityFork.zip,Shamiko.zip') {
        throw "AIR Mini package contains unexpected modules: $($Modules -join ', ')"
    }
    if (Get-ChildItem -LiteralPath $Stage -Recurse -File -Filter 'boot_*_magisk_*.img') {
        throw 'Prebuilt Magisk boot must not be included.'
    }
    foreach ($Launcher in $LauncherTitles.GetEnumerator()) {
        $LauncherPath = Join-Path $Stage $Launcher.Key
        $Expected = 'title ' + $Launcher.Value
        if (-not (Select-String -LiteralPath $LauncherPath -SimpleMatch $Expected -Quiet)) {
            throw "Incorrect launcher title: $($Launcher.Key)"
        }
    }

    if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
    $PackageFiles = Get-ChildItem -LiteralPath $Stage -Force
    Compress-Archive -LiteralPath $PackageFiles.FullName -DestinationPath $Output -CompressionLevel Optimal
} finally {
    if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}

Write-Host "Built $Output"
Write-Host "Size=$((Get-Item -LiteralPath $Output).Length)"
Write-Host "SHA256=$((Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash)"
