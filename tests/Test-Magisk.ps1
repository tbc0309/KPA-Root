$ErrorActionPreference = 'Stop'
$Language = 'EN'
. "$PSScriptRoot/../toolkit/scripts/Common.ps1"
. "$PSScriptRoot/../toolkit/scripts/Magisk.ps1"
$Adb = 'Invoke-FakeAdb'
$BundledMagiskCode = 30700
$MagiskApk = "$PSScriptRoot/../toolkit/packages/Magisk-v30.7.apk"
$ExpectedApkHash = (Get-FileHash $MagiskApk).Hash

$StatusFixture = "MAGISK_VERSION=30.7:MAGISK:R`r`nMAGISK_CODE=30700`r`nZYGISK_SETTING=value=1`r`n"
if ((Get-KpaStatusValue $StatusFixture 'MAGISK_VERSION') -ne '30.7:MAGISK:R') { throw 'Magisk version CRLF parsing failed.' }
if ((Get-KpaStatusValue $StatusFixture 'MAGISK_CODE') -ne '30700') { throw 'Magisk code CRLF parsing failed.' }
if ((Get-KpaStatusValue $StatusFixture 'ZYGISK_SETTING') -ne 'value=1') { throw 'Zygisk setting CRLF parsing failed.' }
if ($null -ne (Get-KpaStatusValue $StatusFixture 'MISSING')) { throw 'Missing status key returned a value.' }
Write-Output 'PASS: Magisk status parsing with Windows line endings'
function Get-KpaProbe { return $script:PackageText }
function Invoke-FakeAdb {
    $script:Installs++
    if (-not $script:BrokenRepair) { $script:PackageText = 'versionCode=30700' }
    $global:LASTEXITCODE = 0
}
foreach ($InitialCode in @(0, 1, 30600, 30700, 30800)) {
    $script:PackageText = "versionCode=$InitialCode"
    $script:Installs = 0
    $script:BrokenRepair = $false
    $script:KpaManagerRepairUsed = $false
    Ensure-KpaManager
    $Expected = if ($InitialCode -lt 30700) { 1 } else { 0 }
    if ($Installs -ne $Expected) { throw "Unexpected installation count: $InitialCode" }
    Ensure-KpaManager
    if ($Installs -ne $Expected) { throw 'Unexpected repeat installation' }
    Write-Output "PASS: version $InitialCode"
}
$script:PackageText = 'versionCode=1'
$script:KpaManagerRepairUsed = $false
$script:BrokenRepair = $true
$Failed = $false
try { Ensure-KpaManager } catch { $Failed = $true }
if (-not $Failed) { throw 'Broken repair was accepted' }
$Before = $Installs
try { Ensure-KpaManager } catch { }
if ($Installs -ne $Before) { throw 'Repair repeated after failure' }
Write-Output 'PASS: failed repair stops without retrying'
