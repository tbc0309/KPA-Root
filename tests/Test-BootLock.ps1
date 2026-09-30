$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\toolkit\scripts\Common.ps1"
$Cases = @(
    @('androidboot.vbmeta.device_state=unlocked androidboot.verifiedbootstate=orange', '0'),
    @('androidboot.vbmeta.device_state=locked', '1'),
    @('androidboot.vbmeta.device_state = "unlocked"', '0'),
    @('ro.boot.flash.locked=1 ro.boot.vbmeta.device_state=locked', 'unknown'),
    @('androidboot.vbmeta.device_state=locked androidboot.vbmeta.device_state=unlocked', 'unknown'),
    @('', 'unknown')
)
foreach ($Case in $Cases) {
    if ((ConvertFrom-KpaBootLock $Case[0]) -ne $Case[1]) { throw "Failed: $($Case[0])" }
}
Write-Host 'PASS: kernel lock states, quoted bootconfig, spoofed properties, conflict and missing data'
