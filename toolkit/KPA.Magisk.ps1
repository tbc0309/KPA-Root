function Get-KpaManagerCode {
    $Package = Get-KpaProbe $Adb "-s $script:KpaSerial shell dumpsys package com.topjohnwu.magisk"
    if (-not $Package) { throw (Get-KpaText 'Unable to read Magisk package state.' '无法读取 Magisk 安装状态。') }
    if ($Package -match 'versionCode=(\d+)') { return [int]$Matches[1] }
    return 0
}

function Ensure-KpaManager {
    # One repair per run; preserve newer installed managers.
    $Code = Get-KpaManagerCode
    if ($Code -ge $BundledMagiskCode) { return }
    if ($script:KpaManagerRepairUsed) {
        throw (Get-KpaText 'Magisk changed again after repair. Open Magisk and finish setup before retrying.' 'Magisk 修复后再次异常。请完成管理器初始化后重试。')
    }
    if ((Get-FileHash -LiteralPath $MagiskApk -Algorithm SHA256).Hash -ne $ExpectedApkHash) {
        throw (Get-KpaText 'Magisk APK checksum mismatch.' 'Magisk APK 校验失败。')
    }
    $script:KpaManagerRepairUsed = $true
    Write-Host 'Repairing Magisk manager... ||| 正在修复 Magisk 管理器……' -ForegroundColor Yellow
    & $Adb -s $script:KpaSerial install -r $MagiskApk
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Magisk installation failed.' 'Magisk 安装失败。') }
    if ((Get-KpaManagerCode) -lt $BundledMagiskCode) {
        throw (Get-KpaText 'Magisk version verification failed after repair.' '修复后 Magisk 版本校验失败。')
    }
    Write-Host 'Magisk manager verified. ||| Magisk 管理器版本校验通过。' -ForegroundColor Green
}
