param([string]$Toolkit = (Join-Path $PSScriptRoot 'toolkit'))
$ErrorActionPreference = 'Stop'
$Language = 'EN'
. (Join-Path $Toolkit 'KPA.Common.ps1')
$script:KpaSerial = 'TEST'
$Adb = 'mock-adb'
$Fastboot = 'mock-fastboot'
function Start-Sleep { param($Seconds) }
function mock-fastboot {
    $script:Reboots++
    $global:LASTEXITCODE = 0
}
function Wait-KpaAndroid { $script:BootChecks++ }
function Get-KpaProbe {
    param($File, $Arguments)
    if ($File -eq $Fastboot) {
        $script:Probes++
        if ($script:Scenario -eq 'locked') { return 'unlocked: no' }
        if ($script:Scenario -eq 'reconnect' -and $script:Probes -gt 1) { return 'unlocked: yes' }
        return ''
    }
    if ($script:Scenario -eq 'already-booted') { return '0' }
    return ''
}
foreach ($Scenario in @('reconnect', 'already-booted', 'locked')) {
    $script:Scenario = $Scenario
    $script:Reboots = 0
    $script:BootChecks = 0
    $script:Probes = 0
    $Failed = $false
    try { Complete-KpaUnlock } catch { $Failed = $true }
    if ($Scenario -eq 'reconnect' -and ($Failed -or $Reboots -ne 1 -or $BootChecks -ne 1)) { throw 'Reconnect test failed' }
    if ($Scenario -eq 'already-booted' -and ($Failed -or $Reboots -ne 0 -or $BootChecks -ne 1)) { throw 'Already booted test failed' }
    if ($Scenario -eq 'locked' -and (-not $Failed -or $Reboots -ne 0 -or $BootChecks -ne 0)) { throw 'Locked device test failed' }
    Write-Output "PASS: $Scenario"
}
$Files = Get-ChildItem -LiteralPath $Toolkit -Filter '*.ps1'
foreach ($File in $Files) {
    $Tokens = $null
    $Errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count) { throw ($Errors | Out-String) }
}
Write-Output 'PASS: PowerShell parsing'
