$ErrorActionPreference = 'Stop'
$Language = 'EN'
. "$PSScriptRoot\..\toolkit\scripts\Common.ps1"
. "$PSScriptRoot\..\toolkit\scripts\PostRoot.ps1"

$Adb = 'Invoke-FakeAdb'
$script:KpaSerial = 'TEST'
$script:CapturedArguments = @()
function Invoke-FakeAdb {
    $script:CapturedArguments = @($args)
    $global:LASTEXITCODE = 0
    Write-Output 'MODULE_INSTALLED_DISABLED=test_module'
}

$Result = Invoke-KpaRootScript -RemotePath '/data/local/tmp/install_bundled_modules.sh' -Arguments @('test_module','second-module')
if ($Result.ExitCode -ne 0) { throw 'A valid remote command failed.' }
$CommandText = $script:CapturedArguments -join ' '
if ($CommandText -notmatch "su -c 'sh /data/local/tmp/install_bundled_modules\.sh test_module second-module'") {
    throw "Remote command was assembled incorrectly: $CommandText"
}

foreach ($Invalid in @('../escape','bad;command','bad command',"bad`ncommand")) {
    $Rejected = $false
    try { Invoke-KpaRootScript -RemotePath '/data/local/tmp/test.sh' -Arguments @($Invalid) | Out-Null } catch { $Rejected = $true }
    if (-not $Rejected) { throw "Unsafe argument was accepted: $Invalid" }
}

$RejectedPath = $false
try { Invoke-KpaRootScript -RemotePath '/data/local/tmp/test.sh argument' | Out-Null } catch { $RejectedPath = $true }
if (-not $RejectedPath) { throw 'A script path containing arguments was accepted.' }

Write-Output 'PASS: remote script path and arguments are separated and validated'
