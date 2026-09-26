[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN', [switch]$PreflightOnly)

. (Join-Path $PSScriptRoot 'KPA.Common.ps1')

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Adb = Join-Path $RootDir 'platform-tools\adb.exe'
$Fastboot = Join-Path $RootDir 'platform-tools\fastboot.exe'
$Log = Join-Path $RootDir ('Restore_Log_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')

function Get-FastbootVar([string]$Name) {
    $Result = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar $Name"
    if (-not $Result) { throw (Get-KpaText "Fastboot query failed: $Name" "Fastboot 查询失败：$Name") }
    return $Result
}

Start-Transcript -LiteralPath $Log | Out-Null
try {
    Write-KpaBanner 'KONKR Pocket Advance - Restore / Relock' 'KONKR Pocket Advance - 恢复 / 加锁'
    Write-Host 'Restore stock boot before OTA. Relocking is optional. ||| OTA 前恢复原版 boot；加锁为独立可选操作。' -ForegroundColor Yellow

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
    if ($Model -ne 'GT78-VN' -or $Device -ne 'GT78-VN' -or $Board -ne 'k85v1_64') { throw 'Unsupported hardware / 设备型号不匹配。' }
    if ($Slot -notin @('a','b')) { throw "Unable to determine active slot / 无法识别活动槽：$Slot" }

    Write-KpaSection 'Current device state' '当前设备状态'
    Write-KpaStatus 'Build' '系统版本' $Build Green
    Write-KpaStatus 'Active slot' '活动槽' $Slot Yellow
    if ($FlashLocked -eq '1') {
        Write-Host 'Bootloader already locked. Exiting. ||| Bootloader 已加锁，退出。' -ForegroundColor Green
        exit 0
    }
    if ($FlashLocked -ne '0') { throw (Get-KpaText 'Unknown lock state; stopping.' '无法确认锁状态，已停止。') }
    Write-KpaStatus 'Bootloader' 'Bootloader' (Get-KpaText 'Unlocked' '已解锁') Yellow

    # Lack of su does not establish whether the on-disk boot image is stock.
    $StockHashes = @{
        '0730' = '735E1D3855DC0165762006CDCB1136D3047B8E999A559FBD259B2ADB58A32487'
        '0813' = '66919AA93F4D1CE9055F2F08B20034E031E63444C2B77E0D2FA3EB186817A71A'
        '0828' = 'F25E0D5115E4E382983F9ACB47B3A2B8AEFB8C8C866D5A07BB888E48553D4039'
    }
    $BootIsStock = $false
    $BootHash = ''
    $KnownVersion = ''
    if ($Build -match '^BW03_2026(0730|0813|0828)(?:_|$)') { $KnownVersion = $Matches[1] }
    if ($KnownVersion) {
        $HashOutput = Get-KpaProbe $Adb "-s $script:KpaSerial shell sha256sum /dev/block/by-name/boot_$Slot"
        if ($HashOutput -notmatch '(?im)^([a-f0-9]{64})\s+') {
            $HasSu = Get-KpaProbe $Adb "-s $script:KpaSerial shell command -v su"
            if ($HasSu) {
                Write-Host 'To inspect boot, allow Shell Root access on the handheld if prompted. ||| 为读取 boot 校验值，如掌机弹出 Shell Root 请求，请点击允许。' -ForegroundColor Yellow
                $HashOutput = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c 'sha256sum /dev/block/by-name/boot_$Slot'"
            }
        }
        if ($HashOutput -match '(?im)^([a-f0-9]{64})\s+') {
            $BootHash = $Matches[1]
            $BootIsStock = $BootHash -ieq $StockHashes[$KnownVersion]
        }
    }
    if ($BootIsStock) {
        Write-Host 'Boot matches stock SHA256. No restore needed. ||| boot 与原版 SHA256 一致，无需恢复。' -ForegroundColor Green
    } elseif ($BootHash) {
        Write-Host 'Boot SHA256 differs from the stock image. ||| boot 校验值与原版不一致。' -ForegroundColor Yellow
    } else {
        Write-Host 'Stock boot could not be verified: partition unreadable or no matching reference. ||| 无法验证原版 boot：分区不可读或无匹配镜像。' -ForegroundColor Yellow
    }

    $RestoreBoot = $true
    $RelockOnly = $false
    if (-not $PreflightOnly) {
        Write-KpaSection 'Choose an operation' '选择操作'
        Write-Host '[1] Restore stock boot; optionally relock afterwards ||| [1] 恢复原版 boot，完成后可另行选择加锁'
        Write-Host '[2] Relock only; do not flash boot ||| [2] 仅重新锁定 Bootloader，不刷写 boot' -ForegroundColor Yellow
        Write-Host '[0] Exit ||| [0] 退出'
        $Action = Read-Host 'Choose 0, 1 or 2 ||| 请选择 0、1 或 2'
        if ($Action -ceq '0' -or [string]::IsNullOrWhiteSpace($Action)) { exit 0 }
        if ($Action -notin @('1','2')) { throw (Get-KpaText 'Invalid choice.' '选项无效。') }
        $RelockOnly = $Action -ceq '2'
        $RestoreBoot = -not $RelockOnly
        if ($RestoreBoot -and $BootIsStock) {
            Write-Host 'Stock boot already present. Exiting. Use option 2 to relock. ||| 已是原版 boot，退出。如需加锁，选择选项 2。' -ForegroundColor Green
            exit 0
        }
        if ($FlashLocked -eq '1') {
            Write-Host 'Bootloader is already locked. No change made. ||| Bootloader 已加锁，未执行任何修改。' -ForegroundColor Green
            exit 0
        }
        if ($FlashLocked -ne '0') { throw (Get-KpaText 'Unknown lock state.' '锁状态不明，已停止。') }
    }

    if ($RestoreBoot) {
    if ($Build -match '^BW03_20260730(?:_|$)') {
        $Version='0730'; $StockBoot=Join-Path $RootDir 'boot_0730_stock.img'; $ExpectedHash='735E1D3855DC0165762006CDCB1136D3047B8E999A559FBD259B2ADB58A32487'
    } elseif ($Build -match '^BW03_20260813(?:_|$)') {
        $Version='0813'; $StockBoot=Join-Path $RootDir 'boot_0813_stock.img'; $ExpectedHash='66919AA93F4D1CE9055F2F08B20034E031E63444C2B77E0D2FA3EB186817A71A'
    } elseif ($Build -match '^BW03_20260828(?:_|$)') {
        $Version='0828'; $StockBoot=Join-Path $RootDir 'boot_0828_stock.img'; $ExpectedHash='F25E0D5115E4E382983F9ACB47B3A2B8AEFB8C8C866D5A07BB888E48553D4039'
    } else {
        throw "Unsupported firmware / 不支持的固件：$Build"
    }
    if (-not (Test-Path -LiteralPath $StockBoot -PathType Leaf)) { throw "Stock boot missing / 缺少原版镜像：$StockBoot" }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $StockBoot).Hash -ne $ExpectedHash) { throw 'Stock boot hash mismatch / 原版镜像哈希不匹配。' }
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
    Write-KpaStatus 'Flash locked' '锁状态' ("$FlashLocked") Gray
    if ($RestoreBoot) {
    Write-KpaStatus 'Firmware' '固件匹配' ("$Version") Green
    Write-KpaStatus 'Image' '原版镜像' ("$(Split-Path -Leaf $StockBoot)") Yellow
    Write-KpaStatus 'Image size' '镜像大小' ("$((Get-Item -LiteralPath $StockBoot).Length) bytes") Gray
    Write-Host "SHA256                 : $ExpectedHash" -ForegroundColor Green
    Write-KpaStatus 'Target' '目标分区' ("boot_$Slot") Yellow
    }

    if ($PreflightOnly) {
        Write-KpaSection 'Preflight completed' '预检完成'
        Write-Host 'No restore or flashing command was executed. ||| 未执行任何恢复或刷写命令。' -ForegroundColor Green
        exit 0
    }

    $Continue = Read-Host 'Type CONTINUE to enter Bootloader; anything else cancels ||| 输入 CONTINUE 进入 Bootloader，其他输入取消'
    if ($Continue -cne 'CONTINUE') { exit 0 }
    & $Adb reboot bootloader

    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Failed to enter Bootloader.' '无法进入 Bootloader，已停止。') }
    Wait-KpaFastbootDevice -Fastboot $Fastboot
    $FastbootSlot = Get-FastbootVar 'current-slot'
    $UnlockState = Get-FastbootVar 'unlocked'
    $Product = Get-FastbootVar 'product'
    if ($Product -notmatch 'product:\s*(k85v1_64|GT78|BW03)') { throw (Get-KpaText 'Unexpected Fastboot product.' 'Fastboot 产品信息不匹配。') }
    if ($FastbootSlot -notmatch "current-slot:\s*$Slot") { throw 'Active slot changed unexpectedly / 活动槽与 Android 中检测结果不一致。' }
    if ($UnlockState -match 'unlocked:\s*no') {
        Write-Host 'Bootloader is already locked. No flash or lock command will be sent. ||| Bootloader 已加锁，不发送刷写或重复加锁命令。' -ForegroundColor Green
        & $Fastboot -s $script:KpaSerial reboot
        if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Reboot failed.' '重启失败。') }
        exit 0
    }
    if ($UnlockState -notmatch 'unlocked:\s*yes') { throw (Get-KpaText 'Unknown Fastboot lock state.' 'Fastboot 锁状态未知，已停止。') }

    Write-KpaSection 'Fastboot verified' 'Fastboot 验证通过'
    Write-Host $FastbootSlot.Trim() -ForegroundColor Yellow
    Write-Host $UnlockState.Trim() -ForegroundColor Green
    if ($RestoreBoot) {
    Write-KpaStatus 'Final target' '最终目标' ("boot_$Slot") Yellow
    Write-Host 'This removes Root from the active slot / 这会移除活动槽上的 Root。' -ForegroundColor Red
    $Confirm = Read-Host 'Type RESTORE to continue / 输入 RESTORE 继续'
    if ($Confirm -cne 'RESTORE') {
        & $Fastboot -s $script:KpaSerial reboot | Out-Null
        throw 'Cancelled safely; rebooting Android / 已安全取消，正在重启 Android。'
    }

    Write-Host "Restoring stock $Version boot to boot_$Slot / 正在恢复 $Version 原版 boot 到 boot_$Slot..." -ForegroundColor Yellow
    & $Fastboot -s $script:KpaSerial flash "boot_$Slot" $StockBoot
    if ($LASTEXITCODE -ne 0) { throw 'fastboot flash failed / Fastboot 刷写失败。' }

    Write-Host ''
    Write-Host 'Stock boot restored successfully / 原版 boot 已成功恢复。' -ForegroundColor Green
    }
    Write-Host 'Optional: relock the bootloader / 可选：重新锁定 Bootloader。' -ForegroundColor Cyan
    Write-Host 'Relocking is not recommended. It may immediately erase data without a Volume Up / MODE confirmation. ||| 不建议重新锁定。命令可能立即清除数据，不一定需要音量+ / MODE 二次确认。' -ForegroundColor Red
    Write-Host 'Only relock if ALL flashed partitions are official and unmodified; this toolkit can verify only the selected boot image. / 仅在所有已刷分区均为官方原版时锁定；本工具只能验证当前选择的 boot 镜像。' -ForegroundColor Red
    if ($RelockOnly) {
        Write-Host 'Stock boot has NOT been restored in this run. Root/patched or mismatched partitions can prevent boot after locking. ||| 本次未恢复原版 boot。若仍有 Root 修补或不匹配分区，加锁后可能无法启动。' -ForegroundColor Red
    }
    $DidRelock = $false
    $RelockChoice = Read-Host 'Relock bootloader now? Type Y for yes; anything else keeps it unlocked / 现在重新锁定？输入 Y 确认，其他输入保持解锁'
    if ($RelockChoice -ceq 'Y') {
        $LockConfirm = Read-Host 'Type LOCK-ERASE to confirm ALL partitions are stock and accept immediate data loss ||| 确认所有分区均为原版并接受立即清除数据后，输入 LOCK-ERASE'
        if ($LockConfirm -ceq 'LOCK-ERASE') {
            Write-Host 'If a confirmation appears, press Volume Up / YES (MODE to the right of L2). ||| 如掌机出现确认界面，请按音量+ / YES（L2 右侧的 MODE）。' -ForegroundColor Yellow
            & $Fastboot -s $script:KpaSerial flashing lock
            if ($LASTEXITCODE -ne 0) {
                throw (Get-KpaText 'Relock command failed or was cancelled.' '加锁命令失败或已取消。')
            } else {
                Start-Sleep -Seconds 2
                if (@(& $Fastboot devices).Count -eq 1) {
                    $FinalLockState = Get-FastbootVar 'unlocked'
                    if ($FinalLockState -match 'unlocked:\s*no') {
                        Write-Host 'Bootloader relocked successfully / Bootloader 已成功重新锁定。' -ForegroundColor Green
                        $DidRelock = $true
                    } else {
                        throw (Get-KpaText 'Bootloader is still unlocked; relock not verified.' 'Bootloader 仍显示解锁，加锁未通过验证。')
                    }
                } else {
                    throw (Get-KpaText 'Device disconnected; lock state could not be verified. Check the handheld.' '设备已断开，无法确认锁状态，请检查掌机。')
                }
            }
        } else {
            Write-Host 'Relock cancelled; keeping bootloader unlocked / 已取消重新锁定，保持 Bootloader 解锁。' -ForegroundColor Yellow
        }
    } else {
        Write-Host 'Keeping bootloader unlocked / 保持 Bootloader 解锁。' -ForegroundColor Yellow
    }

    if (@(& $Fastboot devices).Count -eq 1) {
        & $Fastboot -s $script:KpaSerial reboot
        if ($LASTEXITCODE -ne 0) { throw 'fastboot reboot failed / Fastboot 重启失败。' }
    }
    if ($DidRelock) {
        Write-Host 'Relock verified and reboot requested. Complete setup on the handheld; USB debugging may need to be enabled again. ||| 已确认加锁并发送重启。请在掌机完成初始化，之后可能需要重新开启 USB 调试。' -ForegroundColor Green
    } else {
        Wait-KpaAndroid
        if ($RestoreBoot) { Write-Host 'Stock boot restored; Android startup verified. Bootloader remains unlocked. ||| 原版 boot 已恢复，Android 启动已确认，Bootloader 保持解锁。' -ForegroundColor Green }
        else { Write-Host 'Relock cancelled. Android startup verified. ||| 已取消加锁，已确认 Android 启动完成。' }
    }
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
