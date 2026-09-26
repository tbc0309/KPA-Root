$ErrorActionPreference = 'Stop'
$Language = 'EN'
. "$PSScriptRoot/toolkit/KPA.Common.ps1"
. "$PSScriptRoot/toolkit/KPA.Magisk.ps1"
$Adb = 'Invoke-FakeAdb'
$BundledMagiskCode = 30700
$MagiskApk = "$PSScriptRoot/toolkit/Magisk-v30.7.apk"
$ExpectedApkHash = (Get-FileHash $MagiskApk).Hash
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
