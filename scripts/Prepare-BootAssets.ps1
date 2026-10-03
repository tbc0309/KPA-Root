function Initialize-KpaReleaseBootAssets([string]$ProfileRoot) {
    $Firmware = Import-PowerShellDataFile -LiteralPath (Join-Path $ProfileRoot 'firmware.psd1')
    $Device = Import-PowerShellDataFile -LiteralPath (Join-Path $ProfileRoot 'device.psd1')
    $Images = Join-Path $ProfileRoot 'images'
    $Expected = @()
    foreach ($Entry in $Firmware.Entries) {
        foreach ($Kind in @('stock','magisk_30.7')) {
            $Hash = if ($Kind -eq 'stock') { $Entry.StockHash } else { $Entry.PatchedHash }
            if ($Hash -notmatch '^[0-9A-F]{64}$') { throw "Missing release boot hash: $($Entry.Short) $Kind" }
            $Name = "boot_$($Entry.Short)_$Kind.img"
            $Path = Join-Path $Images $Name
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing release boot: $Path" }
            if ((Get-Item -LiteralPath $Path).Length -ne $Device.BootSize -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Hash) {
                throw "Release boot verification failed: $Path"
            }
            $Expected += $Name
        }
    }
    # 仅在打包暂存目录清除非目录表镜像，避免带入用户生成的未知版本。
    # Clean non-catalog images only in staging; never ship unverified runtime output.
    Get-ChildItem -LiteralPath $Images -File -Filter '*.img' | Where-Object Name -notin $Expected | Remove-Item -Force
}
