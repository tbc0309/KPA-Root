[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDir)
$ErrorActionPreference = 'Stop'
# Keep the reviewed UI fix rather than downloading an unpatched module.
$Name = 'DolbyAtmos_RazerPhone2_v1.0.6_fix.zip'
$Source = Join-Path (Split-Path -Parent $PSScriptRoot) "assets/$Name"
if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne '29F17B569A801431BAF97EF9F51764C3EE77B90060A79004299E53CA421B3F01') {
    throw 'Dolby UI fix archive SHA256 mismatch.'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Copy-Item -LiteralPath $Source -Destination (Join-Path $OutputDir $Name) -Force
Write-Host "$Name <= reviewed landscape UI fix (upstream v1.0.6)"
