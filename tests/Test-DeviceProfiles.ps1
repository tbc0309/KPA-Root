$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../toolkit/scripts/Device.ps1"

$Profiles = @(Get-KpaDeviceProfiles)
if ($Profiles.Count -ne 2) { throw "Expected two device profiles, found $($Profiles.Count)." }

$Cases = @(
    @{
        Id = 'pocket-advance'; Serial = 'BW0308G250005012'; Build = 'BW03_20260828_20260827-2100'
        FirmwareCount = 3; Modules = @('kpa_myuppy_font','kpa_rgb_control','playintegrityfix','zygisk_shamiko','DolbyAtmos')
        ConfirmKeyCn = '音量+（L2 右侧 MODE）'
        ImageKinds = @('stock')
    },
    @{
        Id = 'air-mini'; Serial = 'BW02092211000027'; Build = 'MP40AY2-20251125_20251125-1717'
        FirmwareCount = 6; Modules = @('playintegrityfix','zygisk_shamiko')
        ConfirmKeyCn = '音量+'
        ImageKinds = @('stock')
    }
)

foreach ($Case in $Cases) {
    $Profile = $Profiles | Where-Object Id -eq $Case.Id | Select-Object -First 1
    if (-not $Profile) { throw "Missing profile: $($Case.Id)" }
    if ($Profile.Firmware.Count -ne $Case.FirmwareCount) { throw "Unexpected firmware count: $($Case.Id)" }
    if ((@($Profile.PreinstallModules) -join ',') -ne ($Case.Modules -join ',')) { throw "Unexpected module allowlist: $($Case.Id)" }
    if ($Profile.FastbootConfirmKeyCn -ne $Case.ConfirmKeyCn) { throw "Unexpected confirmation key: $($Case.Id)" }

    $Detected = Find-KpaDeviceProfile 'GT78-VN' 'GT78-VN' 'k85v1_64' $Case.Serial $Case.Build
    if ($Detected.Id -ne $Case.Id) { throw "Profile detection failed: $($Case.Id)" }
    $Firmware = Get-KpaFirmwareInfo $Detected $Case.Build
    if (-not $Firmware.Known) { throw "Known firmware was not resolved: $($Case.Id)" }

    foreach ($Entry in $Profile.Firmware) {
        foreach ($Kind in $Case.ImageKinds) {
            $Path = Get-KpaDeviceImagePath $Profile "boot_$($Entry.Short)_$Kind.img"
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing device image: $Path" }
        }
    }
}

$Rejected = $false
try { Find-KpaDeviceProfile 'GT78-VN' 'GT78-VN' 'k85v1_64' 'UNKNOWN' 'UNKNOWN' | Out-Null } catch { $Rejected = $true }
if (-not $Rejected) { throw 'Ambiguous shared hardware identifiers were accepted without serial and build identity.' }

Write-Output 'PASS: two device profiles, identity rules, firmware data, images and module allowlists'
