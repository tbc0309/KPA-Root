$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\toolkit\scripts\PostRoot.ps1"
$Adb = (Get-Process -Id $PID).Path
foreach ($code in @(0, 7)) {
    Invoke-KpaAdbTransfer -TransferArguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('1 file pushed'); exit $code")
    if ($LASTEXITCODE -ne $code) { throw "Exit code lost: expected $code" }
    if ($ErrorActionPreference -ne 'Stop') { throw 'Error preference leaked' }
    Write-Host "PASS native stderr with exit code $code"
}
