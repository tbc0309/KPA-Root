$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\toolkit\scripts\PostRoot.ps1"
function Get-KpaText($English, $Chinese) { return $English }
function Start-Sleep { param($Seconds) }
function Mock-Adb { $global:LASTEXITCODE = 0 }
$Adb = 'Mock-Adb'
$script:KpaSerial = 'test'
$ZygiskScript = 'test.sh'
$script:attempt = 0
$script:failUntil = 0
function Invoke-KpaRootScript {
    $script:attempt++
    if ($script:attempt -le $script:failUntil) { return [pscustomobject]@{ExitCode=1;Output='simulated failure'} }
    return [pscustomobject]@{ExitCode=0;Output='ZYGISK_ENABLED=1'}
}
function Read-Host { return $script:answers.Dequeue() }
function Check($Name,$Passed) { if (!$Passed) { throw "FAIL $Name" }; Write-Host "PASS $Name" }

Check 'Immediate success' (Enable-KpaZygiskOptional)
$script:attempt=0; $script:failUntil=2
Check 'Automatic retry succeeds' ((Enable-KpaZygiskOptional) -and $script:attempt -eq 3)
$script:attempt=0; $script:failUntil=99; $script:answers=[Collections.Generic.Queue[string]]::new(); $script:answers.Enqueue('S')
$enabled=Enable-KpaZygiskOptional
$modulesReached=$true
Check 'Skip returns normally for module stage' (!$enabled -and $modulesReached -and $script:attempt -eq 3)
$script:attempt=0; $script:failUntil=3; $script:answers.Enqueue('R')
Check 'User retry succeeds' ((Enable-KpaZygiskOptional) -and $script:attempt -eq 4)
$script:probes=0
function Get-KpaProbe { $script:probes++; if ($script:probes -ge 3) { return 'uid=0(root)' }; return '' }
Wait-KpaShellRoot
Check 'Delayed Root authorization' ($script:probes -eq 3)
$tokens=$null; $errors=$null
[void][Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot\..\toolkit\scripts\Root.ps1",[ref]$tokens,[ref]$errors)
Check 'Root script parses' ($errors.Count -eq 0)
