[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN', [switch]$PreflightOnly)

. (Join-Path $PSScriptRoot 'KPA.Common.ps1')

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Adb = Join-Path $RootDir 'platform-tools\adb.exe'
$Fastboot = Join-Path $RootDir 'platform-tools\fastboot.exe'
$Log = Join-Path $RootDir ('Unlock_Log_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')

function Get-FastbootVar([string]$Name) {
    $Result = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar $Name"
    if (-not $Result) { throw (Get-KpaText "Fastboot query failed: $Name" "Fastboot 查询失败：$Name") }
    return $Result
}

Start-Transcript -LiteralPath $Log | Out-Null
try {
    Write-KpaBanner 'KONKR Pocket Advance - Bootloader Unlock' 'KONKR Pocket Advance - Bootloader 解锁'
    Write-Host 'WARNING: Unlocking normally erases all user data. Back up first. / 警告：解锁通常会清除全部用户数据，请先完成备份。' -ForegroundColor Red

    Initialize-KpaUsbEnvironment -Adb $Adb -Fastboot $Fastboot | Out-Null

    $Model = (& $Adb shell getprop ro.product.model).Trim()
    $Device = (& $Adb shell getprop ro.product.device).Trim()
    $Board = (& $Adb shell getprop ro.product.board).Trim()
    $Build = (& $Adb shell getprop ro.build.display.id).Trim()
    $Incremental = (& $Adb shell getprop ro.build.version.incremental).Trim()
    $Android = (& $Adb shell getprop ro.build.version.release).Trim()
    $Sdk = (& $Adb shell getprop ro.build.version.sdk).Trim()
    $Slot = (& $Adb shell getprop ro.boot.slot_suffix).Trim().TrimStart('_')
    $Serial = (& $Adb get-serialno).Trim()
    $BootState = (& $Adb shell getprop ro.boot.verifiedbootstate).Trim()
    $FlashLocked = (& $Adb shell getprop ro.boot.flash.locked).Trim()
    if ($Model -ne 'GT78-VN' -or $Device -ne 'GT78-VN' -or $Board -ne 'k85v1_64') {
        throw 'Unsupported hardware; refusing to unlock / 设备型号不匹配，拒绝执行解锁。'
    }

    Write-KpaSection 'Android preflight' 'Android 预检'
    Write-KpaStatus 'ADB serial' '设备序列号' ("$Serial") Gray
    Write-KpaStatus 'Model' '型号' ("$Model") Green
    Write-KpaStatus 'Device' '设备代号' ("$Device") Gray
    Write-KpaStatus 'Board' '主板' ("$Board") Green
    Write-KpaStatus 'Build' '系统版本' ("$Build") Green
    Write-KpaStatus 'Incremental' '构建号' ("$Incremental") Gray
    Write-KpaStatus 'Android / SDK' 'Android / SDK' ("$Android / $Sdk") Gray
    Write-KpaStatus 'Active slot' '活动槽' ("$Slot") Yellow
    Write-KpaStatus 'Boot state' 'AVB 状态' ("$BootState") Gray
    Write-KpaStatus 'Flash locked' '锁状态' ("$FlashLocked") Yellow

    if ($FlashLocked -eq '0') {
        Write-KpaSection 'Already unlocked' 'Bootloader 已解锁'
        Write-Host 'No action is needed. Exiting without rebooting. ||| 无需继续操作，直接退出，不重启掌机。' -ForegroundColor Green
        exit 0
    }
    if ($FlashLocked -ne '1') {
        throw (Get-KpaText 'Unable to verify the lock state. Stopping.' '无法确认锁状态，已停止操作。')
    }

    if ($PreflightOnly) {
        Write-KpaSection 'Preflight completed' '预检完成'
        Write-Host 'No unlock or flashing command was executed. ||| 未执行任何解锁或刷写命令。' -ForegroundColor Green
        exit 0
    }

    $Proceed = Read-Host 'Type CONTINUE to enter Bootloader; anything else cancels ||| 输入 CONTINUE 进入 Bootloader，其他输入取消'
    if ($Proceed -cne 'CONTINUE') { exit 0 }
    Write-Host 'Rebooting to bootloader / 正在重启到 Bootloader...'
    & $Adb reboot bootloader
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Failed to enter Bootloader.' '无法进入 Bootloader，已停止。') }
    Wait-KpaFastbootDevice -Fastboot $Fastboot

    $Product = Get-FastbootVar 'product'
    if ($Product -notmatch 'k85v1_64|GT78|BW03') { throw 'Unexpected fastboot product / Fastboot 产品信息不匹配。' }
    $UnlockState = Get-FastbootVar 'unlocked'
    Write-KpaSection 'Fastboot preflight' 'Fastboot 预检'
    Write-Host $Product.Trim() -ForegroundColor Green
    Write-Host $UnlockState.Trim() -ForegroundColor Yellow
    if ($UnlockState -match 'unlocked:\s*yes') {
        Write-Host 'Already unlocked; no change made / 已经解锁，无需重复操作。' -ForegroundColor Green
        & $Fastboot -s $script:KpaSerial reboot | Out-Null
        exit 0
    }

    if ($UnlockState -notmatch 'unlocked:\s*no') {
        throw (Get-KpaText 'Fastboot lock state is unknown. Unlock command was not sent.' 'Fastboot 锁状态不明，未发送解锁命令。')
    }
    Write-Host 'DATA WIPE: The command may take effect immediately without another on-device prompt. ||| 清除数据：命令可能立即生效，掌机不一定再次弹出确认。' -ForegroundColor Red
    $Confirm = Read-Host 'Type UNLOCK to erase data and continue / 输入 UNLOCK 确认清除数据并继续'
    if ($Confirm -cne 'UNLOCK') {
        & $Fastboot -s $script:KpaSerial reboot | Out-Null
        throw 'Cancelled safely; rebooting Android / 已安全取消，正在重启 Android。'
    }

    Write-Host 'If prompted, select YES with Volume Up (MODE to the right of L2). ||| 如出现确认界面，按音量+（L2 右侧 MODE）选择 YES。' -ForegroundColor Yellow
    & $Fastboot -s $script:KpaSerial flashing unlock
    if ($LASTEXITCODE -ne 0) { throw 'fastboot flashing unlock failed / Fastboot 解锁命令失败。' }

    Complete-KpaUnlock
    Write-Host 'Bootloader unlocked. Android startup verified. ||| Bootloader 已解锁，Android 启动验证通过。' -ForegroundColor Green
    Write-KpaStatus 'Log' '日志' ("$Log") Gray
}
catch {
    Write-KpaSection 'Operation failed' '操作失败'
    Write-Host ((Get-KpaText 'Reason: ' '原因：') + $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host ((Get-KpaText 'Log: ' '日志：') + $Log)
    exit 1
}
finally { Stop-Transcript | Out-Null }
