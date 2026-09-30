param([string]$Toolkit = (Join-Path $PSScriptRoot '..\toolkit'))
$ErrorActionPreference = 'Stop'
$Language = 'EN'
. (Join-Path $Toolkit 'scripts\Common.ps1')
$script:KpaSerial = 'TEST'
$Adb = 'mock-adb'
$Fastboot = 'mock-fastboot'
function Start-Sleep { param($Seconds) }
function mock-fastboot {
    $script:Reboots++
    $global:LASTEXITCODE = 0
}
function Get-KpaProbe {
    param($File, $Arguments)
    if ($File -eq $Fastboot) {
        $script:Probes++
        if ($script:Scenario -eq 'locked') { return 'unlocked: no' }
        if ($script:Scenario -eq 'reconnect' -and $script:Probes -gt 1) { return 'unlocked: yes' }
        return ''
    }
    if ($Arguments -match 'sys\.boot_completed') { $script:BootChecks++; return '1' }
    return ''
}
foreach ($Scenario in @('reconnect', 'locked')) {
    $script:Scenario = $Scenario
    $script:Reboots = 0
    $script:Probes = 0
    $script:BootChecks = 0
    $Failed = $false
    try {
        Complete-KpaUnlock `
            -WaitForAndroid { $script:BootChecks++ } `
            -GetAndroidLock { '0' }
    } catch { $Failed = $true }
    if ($Scenario -eq 'reconnect' -and ($Failed -or $Reboots -ne 1 -or $BootChecks -ne 1)) { throw 'Reconnect test failed' }
    if ($Scenario -eq 'locked' -and (-not $Failed -or $Reboots -ne 0)) { throw 'Locked device test failed' }
    Write-Output "PASS: $Scenario"
}
