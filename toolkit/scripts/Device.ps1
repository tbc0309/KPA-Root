function Get-KpaDeviceProfiles {
    $Root = Join-Path (Split-Path -Parent $PSScriptRoot) 'devices'
    $Profiles = @(Get-ChildItem -LiteralPath $Root -Directory | ForEach-Object {
        $DeviceFile = Join-Path $_.FullName 'device.psd1'
        if (Test-Path -LiteralPath $DeviceFile) {
            $FirmwareFile = Join-Path $_.FullName 'firmware.psd1'
            $OtaFile = Join-Path $_.FullName 'ota.psd1'
            $ModulesFile = Join-Path $_.FullName 'modules.psd1'
            foreach ($RequiredFile in @($FirmwareFile,$OtaFile,$ModulesFile)) {
                if (-not (Test-Path -LiteralPath $RequiredFile -PathType Leaf)) { throw "Device configuration file is missing: $RequiredFile" }
            }

            $Data = Import-PowerShellDataFile -LiteralPath $DeviceFile
            $FirmwareData = Import-PowerShellDataFile -LiteralPath $FirmwareFile
            $OtaData = Import-PowerShellDataFile -LiteralPath $OtaFile
            $ModulesData = Import-PowerShellDataFile -LiteralPath $ModulesFile
            foreach ($Required in @('Id','Name','PackageName','LauncherTitle','Models','Devices','Boards','FastbootProductPattern','SerialPattern','BuildPattern','BootSize','ImageDirectory','FastbootConfirmKeyEn','FastbootConfirmKeyCn')) {
                if (-not $Data.ContainsKey($Required)) { throw "Device profile is missing '$Required': $DeviceFile" }
            }
            if (-not $FirmwareData.ContainsKey('Entries') -or -not $FirmwareData.Entries) { throw "Firmware table is empty: $FirmwareFile" }
            if (-not $ModulesData.ContainsKey('Preinstall')) { throw "Module allowlist is missing: $ModulesFile" }
            if (-not $OtaData.ContainsKey('Api')) { throw "OTA parameter table is incomplete: $OtaFile" }

            $Data['Firmware'] = @($FirmwareData.Entries)
            $Data['Ota'] = $OtaData
            $Data['PreinstallModules'] = @($ModulesData.Preinstall)
            if ($Data.Id -ne $_.Name) { throw "Device profile ID must match its folder name: $DeviceFile" }
            if (@($Data.PreinstallModules | Select-Object -Unique).Count -ne @($Data.PreinstallModules).Count) { throw "Device profile has duplicate module IDs: $ModulesFile" }
            $Data.ProfileRoot = $_.FullName
            $Data.ImageRoot = Join-Path $_.FullName $Data.ImageDirectory
            [pscustomobject]$Data
        }
    })
    $DuplicateIds = @($Profiles | Group-Object Id | Where-Object Count -gt 1)
    if ($DuplicateIds) { throw "Duplicate device profile ID: $($DuplicateIds.Name -join ', ')" }
    return $Profiles
}

function Find-KpaDeviceProfile([string]$Model,[string]$Device,[string]$Board,[string]$Serial,[string]$Build) {
    $Matches = @(Get-KpaDeviceProfiles | Where-Object {
        $Model -in $_.Models -and
        $Device -in $_.Devices -and
        $Board -in $_.Boards -and
        $Serial -match $_.SerialPattern -and
        $Build -match $_.BuildPattern
    })
    if ($Matches.Count -ne 1) { throw 'Unsupported or ambiguous hardware profile / 不支持或无法唯一识别机型。' }
    $script:KpaDeviceProfile = $Matches[0]
    return $script:KpaDeviceProfile
}

function Get-KpaFirmwareInfo($Profile,[string]$Build) {
    if ($Build -notmatch $Profile.BuildPattern) { throw "Unsupported firmware identifier: $Build" }
    $Date = $Matches[1]
    $Known = @($Profile.Firmware | Where-Object Date -eq $Date | Select-Object -First 1)
    [pscustomobject]@{ Date=$Date; Short=$Date.Substring(4); Known=if($Known){$Known[0]}else{$null} }
}

function Get-KpaDeviceImagePath($Profile,[string]$Name) { Join-Path $Profile.ImageRoot $Name }

function Test-KpaFastbootProduct($Profile,[string]$Text) { return $Text -match $Profile.FastbootProductPattern }
