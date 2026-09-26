[CmdletBinding()]
param(
    [string]$Repository = 'tbc0309/KPA-Modules',
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'toolkit/modules' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$Headers = @{ 'User-Agent' = 'KPA-Root-Release-Builder' }
if ($env:GITHUB_TOKEN) { $Headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
$Releases = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$Repository/releases?per_page=100"

function Download-LatestModule([string]$TagPrefix, [string]$AssetPattern, [string]$OutputName, [string]$ExpectedId) {
    $Release = $Releases | Where-Object { -not $_.draft -and -not $_.prerelease -and $_.tag_name -like "$TagPrefix*" } | Select-Object -First 1
    if (-not $Release) { throw "No release found with tag prefix $TagPrefix" }
    $Asset = $Release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
    if (-not $Asset) { throw "No asset matching $AssetPattern in $($Release.tag_name)" }
    $Output = Join-Path $OutputDir $OutputName
    Invoke-WebRequest -Headers $Headers -Uri $Asset.browser_download_url -OutFile $Output

    # Validate the module identity before including an external release asset.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Archive = [IO.Compression.ZipFile]::OpenRead($Output)
    try {
        $Entry = $Archive.Entries | Where-Object { $_.FullName -eq 'module.prop' } | Select-Object -First 1
        if (-not $Entry) { throw "module.prop missing from $OutputName" }
        try {
            $Reader = [IO.StreamReader]::new($Entry.Open())
            try { $Prop = $Reader.ReadToEnd() } finally { $Reader.Dispose() }
        } catch {
            # Shamiko uses ZIP/XZ, which .NET cannot decompress.
            $SevenZip = @('C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\AOMEI\AOMEI Backupper\6.10.0\7z.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $SevenZip) { throw '7-Zip is required to validate ZIP/XZ module archives.' }
            $Prop = (& $SevenZip e -so $Output module.prop 2>$null) -join "`n"
            if ($LASTEXITCODE -ne 0) { throw "Cannot read module.prop from $OutputName" }
        }
        if ($Prop -notmatch "(?m)^id=$([regex]::Escape($ExpectedId))\r?$") { throw "Unexpected module id in $OutputName" }
    } finally {
        $Archive.Dispose()
    }
    Write-Host "$OutputName <= $($Release.tag_name) [$((Get-FileHash $Output -Algorithm SHA256).Hash)]"
}

Download-LatestModule 'font-v' 'KPA_MYuppy_Font_v*.zip' 'KPA_MYuppy_Font.zip' 'kpa_myuppy_font'
Download-LatestModule 'rgb-v' 'KPA_RGB_Control_v*.zip' 'KPA_RGB_Control.zip' 'kpa_rgb_control'

$Releases = Invoke-RestMethod -Headers $Headers -Uri 'https://api.github.com/repos/osm0sis/PlayIntegrityFork/releases?per_page=100'
Download-LatestModule 'v' 'PlayIntegrityFork*.zip' 'PlayIntegrityFork.zip' 'playintegrityfix'
$Releases = Invoke-RestMethod -Headers $Headers -Uri 'https://api.github.com/repos/LSPosed/LSPosed.github.io/releases?per_page=100'
Download-LatestModule 'shamiko-' 'Shamiko-*-release.zip' 'Shamiko.zip' 'zygisk_shamiko'
& (Join-Path $PSScriptRoot 'Fetch-Dolby.ps1') -OutputDir $OutputDir
