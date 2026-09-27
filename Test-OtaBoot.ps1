$ErrorActionPreference = 'Stop'
$Language = 'EN'
. "$PSScriptRoot/toolkit/KPA.Common.ps1"
. "$PSScriptRoot/toolkit/KPA.OtaBoot.ps1"

$ExpectedDumperHash = '09EA2F5BCB4424BDEEDAB4FC7983116BDD30661E7D886B1C453FC08C64066848'
$Dumper = "$PSScriptRoot/toolkit/tools/payload_dumper.exe"
if ((Get-FileHash -LiteralPath $Dumper -Algorithm SHA256).Hash -ne $ExpectedDumperHash) {
    throw 'payload_dumper.exe hash mismatch'
}

$KnownBoots = @{
    '0730' = '735E1D3855DC0165762006CDCB1136D3047B8E999A559FBD259B2ADB58A32487'
    '0813' = '66919AA93F4D1CE9055F2F08B20034E031E63444C2B77E0D2FA3EB186817A71A'
    '0828' = 'F25E0D5115E4E382983F9ACB47B3A2B8AEFB8C8C866D5A07BB888E48553D4039'
}
foreach ($Entry in $KnownBoots.GetEnumerator()) {
    $Path = "$PSScriptRoot/toolkit/boot_$($Entry.Key)_stock.img"
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Entry.Value) {
        throw "Stock boot hash mismatch: $($Entry.Key)"
    }
}

# Existing valid images must return before any network request is attempted.
$Existing = Ensure-KpaStockBoot -RootDir "$PSScriptRoot/toolkit" -Build 'BW03_20260828_20260827-2100' -Serial 'INVALID'
if ($Existing.Generated -or $Existing.Hash -ne $KnownBoots['0828']) {
    throw 'Existing stock boot was not reused'
}

$Tokens = $null
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$PSScriptRoot/toolkit/KPA.OtaBoot.ps1",
    [ref]$Tokens,
    [ref]$ParseErrors
) | Out-Null
if ($ParseErrors.Count -ne 0) { throw 'KPA.OtaBoot.ps1 has parser errors' }

Write-Output 'PASS: OTA boot prerequisites and existing-image reuse'
