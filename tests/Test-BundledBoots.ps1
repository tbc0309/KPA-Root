$ErrorActionPreference = 'Stop'
$Toolkit = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../toolkit'))
. (Join-Path $Toolkit 'scripts/Device.ps1')
. (Join-Path $Toolkit 'scripts/OtaBoot.ps1')
$Scratch = Join-Path ([IO.Path]::GetTempPath()) ('kpa-bundled-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Scratch | Out-Null
try {
    foreach ($Profile in @(Get-KpaDeviceProfiles)) {
        # 无运行时索引和网络，只允许复用目录表内的完整镜像。
        # No runtime index or network: catalog images must be sufficient.
        $Profile.ProfileRoot = Join-Path $Scratch $Profile.Id
        $script:KpaDeviceProfile = $Profile
        foreach ($Entry in $Profile.Firmware) {
            if ($Entry.PatchedHash -notmatch '^[0-9A-F]{64}$') { throw 'Missing patched hash' }
            $Stock = Ensure-KpaStockBoot -RootDir $Toolkit -Profile $Profile -Build $Entry.Server -Serial 'INVALID_NO_NETWORK'
            $Patched = Ensure-KpaPatchedBoot -RootDir $Toolkit -Stock $Stock -Adb 'MUST_NOT_RUN'
            if ((Get-FileHash -LiteralPath $Patched).Hash -ne $Entry.PatchedHash) { throw 'Patched hash mismatch' }
        }
    }
    # 隔离一个损坏镜像，确认固定哈希校验不会放行。
    # Isolate a corrupt image and confirm catalog verification rejects it.
    $script:KpaDeviceProfile.ImageRoot = Join-Path $Scratch 'corrupt'
    New-Item -ItemType Directory -Path $script:KpaDeviceProfile.ImageRoot | Out-Null
    $Bad = Get-KpaDeviceImagePath $script:KpaDeviceProfile "boot_$($Stock.Version)_magisk_30.7.img"
    $Stream = [IO.File]::Create($Bad)
    try { $Stream.SetLength($script:KpaDeviceProfile.BootSize) } finally { $Stream.Dispose() }
    $Rejected = $false
    try { Ensure-KpaPatchedBoot -RootDir $Toolkit -Stock $Stock -Adb 'MUST_NOT_RUN' | Out-Null } catch {
        if ($_.Exception.Message -notmatch 'SHA256 mismatch') { throw }
        $Rejected = $true
    }
    if (-not $Rejected) { throw 'Corrupt bundled boot was accepted' }
} finally {
    $Resolved = [IO.Path]::GetFullPath($Scratch)
    if ((Split-Path -Parent $Resolved) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $Resolved -Recurse -Force
}
Write-Output 'PASS: all nine stock/patched pairs reused without OTA, patch host or runtime indexes; corrupt image rejected'
