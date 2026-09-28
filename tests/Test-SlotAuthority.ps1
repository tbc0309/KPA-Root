$ErrorActionPreference = 'Stop'
$Root = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\toolkit\Root.ps1') -Raw
$Restore = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\toolkit\Restore.ps1') -Raw

foreach ($Item in @(@('Root', $Root), @('Restore', $Restore))) {
    $Name = $Item[0]
    $Source = $Item[1]
    if ($Source -notmatch 'getprop ro\.boot\.slot_suffix') { throw "$Name does not read the running Android slot." }
    if ($Source -notmatch "Get-FastbootVar 'current-slot'") { throw "$Name does not verify Fastboot current-slot." }
    if ($Source -match '(?i)scheduled_target|/dev/block/by-name/misc|boot_control') { throw "$Name must not depend on misc A/B priority metadata." }
    Write-Host "PASS $Name uses Android and Fastboot current-slot without misc priority dependency"
}

Write-Host 'KPA Root slot authority checks passed.'
