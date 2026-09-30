$ErrorActionPreference = 'Stop'
$Toolkit = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\toolkit'))
$WindowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path -LiteralPath $WindowsPowerShell -PathType Leaf)) {
    throw 'Windows PowerShell 5.1 was not found.'
}

$Files = @(Get-ChildItem -LiteralPath $Toolkit -Recurse -File | Where-Object Extension -in '.ps1','.psd1')
foreach ($File in $Files) {
    $Bytes = [IO.File]::ReadAllBytes($File.FullName)
    if ($Bytes.Length -lt 3 -or $Bytes[0] -ne 0xEF -or $Bytes[1] -ne 0xBB -or $Bytes[2] -ne 0xBF) {
        throw "PowerShell source is not UTF-8 BOM: $($File.FullName)"
    }
}

$DeviceScript = Join-Path $Toolkit 'scripts\Device.ps1'
$CommonScript = Join-Path $Toolkit 'scripts\Common.ps1'
$Command = @"
`$ErrorActionPreference = 'Stop'
`$Files = @(Get-ChildItem -LiteralPath '$($Toolkit.Replace("'", "''"))' -Recurse -File | Where-Object Extension -in '.ps1','.psd1')
foreach (`$File in `$Files) {
    `$Tokens = `$null
    `$Errors = `$null
    [void][Management.Automation.Language.Parser]::ParseFile(`$File.FullName, [ref]`$Tokens, [ref]`$Errors)
    if (`$Errors.Count) { throw "Parser failure: `$(`$File.FullName)" }
}
. '$($CommonScript.Replace("'", "''"))'
. '$($DeviceScript.Replace("'", "''"))'
`$Profiles = @(Get-KpaDeviceProfiles)
if (`$Profiles.Count -ne 2) { throw 'Profile loading failed.' }
if (`$PSVersionTable.PSVersion -lt [version]'5.1') { throw 'Unexpected PowerShell version.' }
if (([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) -eq 0) { throw 'TLS 1.2 is not enabled.' }
Write-Output 'WINDOWS_POWERSHELL_OK'
"@
$Output = & $WindowsPowerShell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $Command 2>&1
if ($LASTEXITCODE -ne 0 -or $Output -notcontains 'WINDOWS_POWERSHELL_OK') {
    throw "Windows PowerShell compatibility check failed:`n$($Output -join "`n")"
}

Write-Output 'PASS: UTF-8 BOM and Windows PowerShell 5.1 profile loading'
