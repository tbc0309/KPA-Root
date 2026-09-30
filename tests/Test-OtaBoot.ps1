$ErrorActionPreference = 'Stop'
$Language = 'EN'
. "$PSScriptRoot/../toolkit/scripts/Common.ps1"
. "$PSScriptRoot/../toolkit/scripts/Device.ps1"
. "$PSScriptRoot/../toolkit/scripts/OtaBoot.ps1"
$Profile = Find-KpaDeviceProfile 'GT78-VN' 'GT78-VN' 'k85v1_64' 'BW0308G250005012' 'BW03_20260828_20260827-2100'

$ExpectedDumperHash = '09EA2F5BCB4424BDEEDAB4FC7983116BDD30661E7D886B1C453FC08C64066848'
$Dumper = "$PSScriptRoot/../toolkit/tools/ota/payload_dumper.exe"
if ((Get-FileHash -LiteralPath $Dumper -Algorithm SHA256).Hash -ne $ExpectedDumperHash) {
    throw 'payload_dumper.exe hash mismatch'
}

$KnownBoots = @{}; foreach($Firmware in $Profile.Firmware){$KnownBoots[$Firmware.Short]=$Firmware.StockHash}
foreach ($Entry in $KnownBoots.GetEnumerator()) {
    $Path = Get-KpaDeviceImagePath $Profile "boot_$($Entry.Key)_stock.img"
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Entry.Value) {
        throw "Stock boot hash mismatch: $($Entry.Key)"
    }
}

# Existing valid images must return before any network request is attempted.
$Existing = Ensure-KpaStockBoot -RootDir "$PSScriptRoot/../toolkit" -Profile $Profile -Build 'BW03_20260828_20260827-2100' -Serial 'INVALID'
if ($Existing.Generated -or $Existing.Hash -ne $KnownBoots['0828']) {
    throw 'Existing stock boot was not reused'
}

$Tokens = $null
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$PSScriptRoot/../toolkit/scripts/OtaBoot.ps1",
    [ref]$Tokens,
    [ref]$ParseErrors
) | Out-Null
if ($ParseErrors.Count -ne 0) { throw 'scripts/OtaBoot.ps1 has parser errors' }

Write-Output 'PASS: OTA boot prerequisites and existing-image reuse'
