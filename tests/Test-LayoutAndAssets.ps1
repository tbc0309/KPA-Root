$ErrorActionPreference = 'Stop'
$Toolkit = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\toolkit'))
. (Join-Path $Toolkit 'scripts\Device.ps1')

$ExpectedRootFiles = @(
    '1_Unlock_CN.cmd','1_Unlock_EN.cmd','2_Root_CN.cmd',
    '2_Root_EN.cmd','3_Restore_CN.cmd','3_Restore_EN.cmd'
)
$RootFiles = @(Get-ChildItem -LiteralPath $Toolkit -File | Select-Object -ExpandProperty Name | Sort-Object)
if (($RootFiles -join ',') -ne (($ExpectedRootFiles | Sort-Object) -join ',')) { throw 'Toolkit root must contain only the six CMD launchers.' }
$RootFolders = @(Get-ChildItem -LiteralPath $Toolkit -Directory | Where-Object Name -ne 'logs' | Select-Object -ExpandProperty Name | Sort-Object)
if (($RootFolders -join ',') -ne 'devices,packages,scripts,tools') { throw "Unexpected toolkit folders: $($RootFolders -join ',')" }

$RequiredRuntime = @(
    'packages\Magisk-v30.7.apk',
    'scripts\Root.ps1','scripts\Restore.ps1','scripts\Unlock.ps1','scripts\patch_boot.sh',
    'tools\platform\adb.exe','tools\platform\fastboot.exe',
    'tools\driver\android_winusb\android_winusb.inf',
    'tools\ota\payload_dumper.exe','tools\ota\PAYLOAD_DUMPER_LICENSE.txt'
)
foreach ($Relative in $RequiredRuntime) {
    if (-not (Test-Path -LiteralPath (Join-Path $Toolkit $Relative) -PathType Leaf)) { throw "Missing runtime file: $Relative" }
}

$ModuleFiles = @{
    kpa_myuppy_font = 'KPA_MYuppy_Font.zip'
    kpa_rgb_control = 'KPA_RGB_Control.zip'
    playintegrityfix = 'PlayIntegrityFork.zip'
    zygisk_shamiko = 'Shamiko.zip'
    DolbyAtmos = 'DolbyAtmos_RazerPhone2_v1.0.6_fix.zip'
}
$OtaKeys = @('Api','Sign','TargetPattern','DeviceType','ConnectType','Platform','Project','DevicesInfoExt','Fingerprint','SdkLevel','SdkRelease','Resolution','AppVersion','AppCode','SendId')

foreach ($Profile in @(Get-KpaDeviceProfiles)) {
    foreach ($ModuleId in @($Profile.PreinstallModules)) {
        if (-not $ModuleFiles.ContainsKey($ModuleId)) { throw "Unknown module ID in $($Profile.Id): $ModuleId" }
        $Archive = Join-Path $Toolkit ('packages\modules\' + $ModuleFiles[$ModuleId])
        if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) { throw "Missing module archive: $Archive" }
    }
    foreach ($Key in $OtaKeys) {
        if (-not $Profile.Ota.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Profile.Ota[$Key])) { throw "Missing OTA parameter '$Key' in $($Profile.Id)" }
    }
    foreach ($Firmware in @($Profile.Firmware)) {
        if ($Firmware.Date -notmatch '^\d{8}$' -or $Firmware.Short -ne $Firmware.Date.Substring(4)) { throw "Invalid firmware naming in $($Profile.Id)" }
        if ($Firmware.StockHash -notmatch '^[0-9A-F]{64}$') { throw "Invalid stock hash in $($Profile.Id) $($Firmware.Short)" }
        $Image = Get-KpaDeviceImagePath $Profile "boot_$($Firmware.Short)_stock.img"
        if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) { throw "Missing stock boot: $Image" }
        if ((Get-Item -LiteralPath $Image).Length -ne $Profile.BootSize) { throw "Unexpected boot size: $Image" }
        if ((Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash -ne $Firmware.StockHash) { throw "Stock boot hash mismatch: $Image" }
    }
}

$PatchedImages = @(Get-ChildItem -LiteralPath (Join-Path $Toolkit 'devices') -Recurse -File -Filter 'boot_*_magisk_*.img')
foreach ($Image in $PatchedImages) {
    $Profile = @(Get-KpaDeviceProfiles | Where-Object { $Image.FullName.StartsWith($_.ImageRoot, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
    if (-not $Profile) { throw "Generated boot is outside a device profile: $($Image.FullName)" }
    if ($Image.Name -notmatch '^boot_([0-9]{4}|[0-9]{8})_magisk_[0-9.]+\.img$') { throw "Invalid generated boot name: $($Image.Name)" }
    $Version = $Matches[1]
    if ($Image.Length -ne $Profile.BootSize) { throw "Generated boot size mismatch: $($Image.FullName)" }
    $IndexFile = Join-Path $Profile.ProfileRoot 'ota\generated-patched-boots.json'
    if (-not (Test-Path -LiteralPath $IndexFile -PathType Leaf)) { throw "Generated boot index is missing: $($Image.FullName)" }
    $Record = @(Get-Content -LiteralPath $IndexFile -Raw | ConvertFrom-Json) | Where-Object Version -eq $Version | Select-Object -First 1
    if (-not $Record) { throw "Generated boot index entry is missing: $($Image.FullName)" }
    if ((Get-FileHash -LiteralPath $Image.FullName -Algorithm SHA256).Hash -ne [string]$Record.Hash) { throw "Generated boot hash mismatch: $($Image.FullName)" }
}

$BuildScript = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\build-release.ps1') -Raw
if ($BuildScript -notmatch "boot_\*_magisk_\*\.img") { throw 'Release build does not exclude runtime-patched boot images.' }
Write-Output 'PASS: toolkit layout, runtime paths, parameter tables, stock images and generated-image records'
