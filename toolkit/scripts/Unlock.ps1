[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN', [switch]$PreflightOnly)

. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Device.ps1')

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $PSScriptRoot
$Adb = Join-Path $RootDir 'tools\platform\adb.exe'
$Fastboot = Join-Path $RootDir 'tools\platform\fastboot.exe'
$LogDir = Join-Path $RootDir 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Log = Join-Path $LogDir ('Unlock_Log_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')

function Get-FastbootVar([string]$Name) {
    $Result = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar $Name"
    if (-not $Result) { throw (Get-KpaText "Fastboot query failed: $Name" "Fastboot 查询失败：$Name") }
    return $Result
}

Start-Transcript -LiteralPath $Log | Out-Null
try {
    Write-Host (Get-KpaText 'WARNING: Unlocking normally erases all user data. Back up first.' '警告：解锁通常会清除全部用户数据，请先完成备份。') -ForegroundColor Red
    Write-KpaSection 'What this script will do' '本脚本操作流程'
    Write-KpaStep 1 4 'Check tools, install the USB driver, and wait for ADB authorization' '检查工具、安装 USB 驱动并等待 ADB 授权'
    Write-KpaStep 2 4 'Read the device identity and current lock state' '读取设备身份与当前锁状态'
    Write-KpaStep 3 4 'Ask twice before entering Fastboot and erasing data' '进入 Fastboot 和清除数据前进行两次确认'
    Write-KpaStep 4 4 'Verify the unlocked state, restart, and wait for Android' '验证解锁状态、重启并等待 Android'

    Initialize-KpaUsbEnvironment -Adb $Adb -Fastboot $Fastboot | Out-Null

    $Model = (& $Adb shell getprop ro.product.bootimage.model).Trim()
    $Device = (& $Adb shell getprop ro.product.bootimage.device).Trim()
    $Board = (& $Adb shell getprop ro.product.board).Trim()
    $Build = (& $Adb shell getprop ro.build.display.id).Trim()
    $Incremental = (& $Adb shell getprop ro.build.version.incremental).Trim()
    $Android = (& $Adb shell getprop ro.build.version.release).Trim()
    $Sdk = (& $Adb shell getprop ro.build.version.sdk).Trim()
    $Slot = (& $Adb shell getprop ro.boot.slot_suffix).Trim().TrimStart('_')
    $Serial = (& $Adb get-serialno).Trim()
    $BootState = (& $Adb shell getprop ro.boot.verifiedbootstate).Trim()
    $FlashLocked = Get-KpaBootLock
    $Profile = Find-KpaDeviceProfile $Model $Device $Board $Serial $Build
    Write-KpaBanner "$($Profile.Name) - Bootloader Unlock" "$($Profile.Name) - Bootloader 解锁"

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
        Write-KpaHint 'Android reports an unlocked bootloader. Fastboot will verify it before the script exits.' 'Android 显示 Bootloader 已解锁；脚本仍将在 Fastboot 中确认后再退出。' Yellow
    } elseif ($FlashLocked -eq '1') {
        Write-KpaHint 'Android reports a locked bootloader. Fastboot will verify it before any unlock command.' 'Android 显示 Bootloader 已锁定；发送解锁命令前会在 Fastboot 中再次确认。' Yellow
    } else {
        Write-KpaHint 'Android did not expose a reliable lock state. Fastboot will verify it before any unlock command.' 'Android 未提供可靠的锁状态；发送解锁命令前会在 Fastboot 中确认。' Yellow
    }

    if ($PreflightOnly) {
        Write-KpaSection 'Preflight completed' '预检完成'
        Write-Host 'No unlock or flashing command was executed. ||| 未执行任何解锁或刷写命令。' -ForegroundColor Green
        exit 0
    }

    if (-not (Read-KpaYes 'Enter Bootloader?' '进入 Bootloader？')) { exit 0 }
    Write-Host 'Rebooting to bootloader / 正在重启到 Bootloader...'
    & $Adb reboot bootloader
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Failed to enter Bootloader.' '无法进入 Bootloader，已停止。') }
    Wait-KpaFastbootDevice -Fastboot $Fastboot

    $Product = Get-FastbootVar 'product'
    if (-not (Test-KpaFastbootProduct $Profile $Product)) { throw 'Unexpected fastboot product / Fastboot 产品信息不匹配。' }
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
    if (-not (Read-KpaYes 'Erase user data and unlock the bootloader?' '清除用户数据并解锁 Bootloader？')) {
        & $Fastboot -s $script:KpaSerial reboot | Out-Null
        throw 'Cancelled safely; rebooting Android / 已安全取消，正在重启 Android。'
    }

    $ConfirmKey = Get-KpaText $Profile.FastbootConfirmKeyEn $Profile.FastbootConfirmKeyCn
    Write-Host ((Get-KpaText 'If prompted on the handheld, press ' '如掌机出现确认界面，请按') + $ConfirmKey + (Get-KpaText ' to select YES.' '选择 YES。')) -ForegroundColor Yellow
    Write-KpaHint 'The command may complete without showing a confirmation screen. The script will verify the result automatically.' '命令也可能不显示确认界面而直接完成；脚本会自动验证最终结果。' DarkGray
    & $Fastboot -s $script:KpaSerial flashing unlock
    if ($LASTEXITCODE -ne 0) { throw 'fastboot flashing unlock failed / Fastboot 解锁命令失败。' }

    Complete-KpaUnlock
    Write-Host 'Bootloader unlock verified before and after restart. ||| Bootloader 已完成重启前后的解锁验证。' -ForegroundColor Green
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
