[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN', [switch]$PreflightOnly)

. (Join-Path $PSScriptRoot 'KPA.Common.ps1')
. (Join-Path $PSScriptRoot 'KPA.Magisk.ps1')
$script:KpaManagerRepairUsed = $false

$ErrorActionPreference = 'Stop'
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path $RootDir 'platform-tools'
$Adb = Join-Path $ToolsDir 'adb.exe'
$Fastboot = Join-Path $ToolsDir 'fastboot.exe'
$MagiskApk = Join-Path $RootDir 'Magisk-v30.7.apk'
$ZygiskScript = Join-Path $RootDir 'enable_zygisk.sh'
$StatusScript = Join-Path $RootDir 'check_root_status.sh'
$ModuleInstaller = Join-Path $RootDir 'install_bundled_modules.sh'
$FontModule = Join-Path $RootDir 'modules\KPA_MYuppy_Font.zip'
$RgbModule = Join-Path $RootDir 'modules\KPA_RGB_Control.zip'
$PifModule = Join-Path $RootDir 'modules\PlayIntegrityFork.zip'
$ShamikoModule = Join-Path $RootDir 'modules\Shamiko.zip'
$DolbyModule = Join-Path $RootDir 'modules\DolbyAtmos_RazerPhone2_v1.0.6_fix.zip'
$ExpectedApkHash = 'E0D32D2123532860F97123D927B1BB86C4E08E6FD8A48BFC6B5BEE0AFAE9EBD5'
$BundledMagiskVersion = '30.7'
$BundledMagiskCode = 30700
$Log = Join-Path $RootDir ('Root_Log_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')

function Get-FastbootVar([string]$Name) {
    $Result = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar $Name"
    if (-not $Result) { throw (Get-KpaText "Fastboot query failed: $Name" "Fastboot 查询失败：$Name") }
    return $Result
}

function Install-BundledModulesDisabled {
    Write-Host 'Installing bundled modules in disabled state / 正在安装内置模块（默认停用）...' -ForegroundColor Cyan
    foreach ($Module in @($FontModule, $RgbModule, $PifModule, $ShamikoModule, $DolbyModule)) {
        & $Adb push $Module ('/data/local/tmp/' + (Split-Path $Module -Leaf)) | Out-Null
        if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Module transfer failed.' '模块传输失败。') }
    }
    & $Adb push $ModuleInstaller /data/local/tmp/install_bundled_modules.sh | Out-Null
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Installer transfer failed.' '安装脚本传输失败。') }
    $Output = (& $Adb shell su -c 'sh /data/local/tmp/install_bundled_modules.sh' 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "Bundled module installation failed / 内置模块安装失败：$Output" }
    Write-Host $Output.Trim()
    & $Adb shell rm -f /data/local/tmp/KPA_MYuppy_Font.zip /data/local/tmp/KPA_RGB_Control.zip /data/local/tmp/PlayIntegrityFork.zip /data/local/tmp/Shamiko.zip /data/local/tmp/DolbyAtmos_RazerPhone2_v1.0.6_fix.zip /data/local/tmp/install_bundled_modules.sh | Out-Null
}

Start-Transcript -LiteralPath $Log | Out-Null
try {
    Write-KpaBanner 'KONKR Pocket Advance - Root (0730 / 0813 / 0828)' 'KONKR Pocket Advance - 获取 Root（0730 / 0813 / 0828）'
    Write-Host 'Bootloader must already be unlocked / Bootloader 必须已经解锁。'
    Write-Host 'Only the active boot slot is flashed / 只刷当前活动槽，不改另一槽。' -ForegroundColor Yellow
    Write-Host 'Before every OTA, restore the matching stock boot / 每次 OTA 前必须恢复匹配的原版 boot。' -ForegroundColor Red

    foreach ($File in @($Adb, $Fastboot, $MagiskApk, $ZygiskScript, $StatusScript, $ModuleInstaller, $FontModule, $RgbModule, $PifModule, $ShamikoModule, $DolbyModule)) {
        if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file missing / 缺少文件：$File" }
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $MagiskApk).Hash -ne $ExpectedApkHash) {
        throw 'Magisk APK SHA256 mismatch / Magisk APK 哈希不匹配。'
    }

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

    $IsRooted = $false
    $MagiskVersion = Get-KpaText 'not available' '不可用'
    $MagiskCode = 0
    $ZygiskSetting = Get-KpaText 'unknown' '未知'
    $ZygiskProcess = Get-KpaText 'not running' '未运行'
    $MagiskAppVersion = Get-KpaText 'not found' '未找到'
    $MagiskAppCode = 0
    Write-KpaSection 'Check Root authorization' '检查 Root 授权'
    Write-Host 'Watch the handheld screen: if Shell requests superuser access, tap Allow. ||| 请留意掌机屏幕：如 Shell 请求超级用户权限，请点击“允许”。' -ForegroundColor Yellow
    Write-Host 'If previously denied, open Magisk > Superuser and enable Shell access. ||| 若此前拒绝过，请打开 Magisk → 超级用户，允许 Shell 的 Root 权限。'
    $RootProbe = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c id"
    if ($RootProbe -match 'uid=0') {
        $IsRooted = $true
        & $Adb push $StatusScript /data/local/tmp/check_root_status.sh | Out-Null
        $StatusText = (& $Adb shell su -c 'sh /data/local/tmp/check_root_status.sh' 2>&1 | Out-String)
        & $Adb shell rm -f /data/local/tmp/check_root_status.sh | Out-Null
        if ($StatusText -match '(?m)^MAGISK_VERSION=(.+)$') { $MagiskVersion = $Matches[1].Trim() }
        if ($StatusText -match '(?m)^MAGISK_CODE=(\d+)$') { $MagiskCode = [int]$Matches[1] }
        if ($StatusText -match '(?m)^ZYGISK_SETTING=(.+)$') { $ZygiskSetting = $Matches[1].Trim() }
        if ($StatusText -match '(?m)^ZYGISK_PROCESS=(.+)$') { $ZygiskProcess = $Matches[1].Trim() }
    }
    $MagiskPackage = (& $Adb shell dumpsys package com.topjohnwu.magisk 2>&1 | Out-String)
    if ($MagiskPackage -match 'versionName=([^\s]+)') { $MagiskAppVersion = $Matches[1].Trim() }
    if ($MagiskPackage -match 'versionCode=(\d+)') { $MagiskAppCode = [int]$Matches[1] }
    $CoreUpToDate = ($MagiskVersion -match '^30\.7(?:\b|:)') -or ($MagiskCode -ge $BundledMagiskCode)
    $AppUpToDate = ($MagiskAppVersion -match '^30\.7(?:\b|$)') -or ($MagiskAppCode -ge $BundledMagiskCode)
    $ZygiskEnabled = ($ZygiskSetting -match '(?:^|=)1$')

    if ($Model -ne 'GT78-VN' -or $Device -ne 'GT78-VN' -or $Board -ne 'k85v1_64') {
        throw 'Unsupported hardware / 设备型号不匹配。'
    }
    if ($Build -match '^BW03_20260730(?:_|$)') {
        $FirmwareVersion = '0730'
        $PatchedBoot = Join-Path $RootDir 'boot_0730_magisk_30.7.img'
        $ExpectedBootHash = 'B77034ED82094F73A5DB0A76870A6905399EA49934FAC05838D874019E748994'
    }
    elseif ($Build -match '^BW03_20260813(?:_|$)') {
        $FirmwareVersion = '0813'
        $PatchedBoot = Join-Path $RootDir 'boot_0813_magisk_30.7.img'
        $ExpectedBootHash = '4836B595C78F52A63EAA05FB0B4A7F344B609E6A7013740CC477778E729F636A'
    }
    elseif ($Build -match '^BW03_20260828(?:_|$)') {
        $FirmwareVersion = '0828'
        $PatchedBoot = Join-Path $RootDir 'boot_0828_magisk_30.7.img'
        $ExpectedBootHash = 'BB98AC02CEBE9CC7B3FD070660D76A5B57AF03BF24A8758E8FE63E61408149F1'
    }
    else {
        throw (Get-KpaText "Unsupported firmware: $Build. Supported: 0730, 0813, 0828." "不支持的固件：$Build。支持：0730、0813、0828。")
    }
    if (-not (Test-Path -LiteralPath $PatchedBoot -PathType Leaf)) {
        throw "Required boot image missing / 缺少 boot 镜像：$PatchedBoot"
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $PatchedBoot).Hash -ne $ExpectedBootHash) {
        throw "Patched boot SHA256 mismatch / $FirmwareVersion 修补镜像哈希不匹配。"
    }
    if ($Slot -notin @('a','b')) { throw "Unable to determine active slot / 无法识别活动槽：$Slot" }

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
    if ($IsRooted) {
        Write-Host 'Root status: ROOTED ||| Root 状态：已获取 Root' -ForegroundColor Green
        if (-not $CoreUpToDate) {
            Write-Host "Magisk Core: $MagiskVersion ($MagiskCode) - UPDATE AVAILABLE ||| Magisk 核心版本：$MagiskVersion ($MagiskCode) - 可更新到 $BundledMagiskVersion" -ForegroundColor Red
        } else {
            Write-KpaStatus 'Magisk Core' '核心版本' ("$MagiskVersion ($MagiskCode)") Green
        }
        if ($AppUpToDate) {
            Write-KpaStatus 'Magisk App' '管理器版本' ("$MagiskAppVersion ($MagiskAppCode)") Green
        } else {
            Write-Host "Magisk App: $MagiskAppVersion ($MagiskAppCode) - UPDATE AVAILABLE ||| Magisk 管理器版本：$MagiskAppVersion ($MagiskAppCode) - 可更新" -ForegroundColor Red
        }
        Write-KpaStatus 'Bundled' '工具包版本' ("Magisk $BundledMagiskVersion ($BundledMagiskCode)") Gray
        if ($ZygiskEnabled -and $ZygiskProcess -eq 'running') {
            Write-Host 'Zygisk: active ||| Zygisk：已生效' -ForegroundColor Green
        } elseif ($ZygiskEnabled) {
            Write-Host 'Zygisk: enabled; activation not verified ||| Zygisk：已开启，尚未确认生效' -ForegroundColor Yellow
        } else {
            Write-Host "Zygisk: DISABLED; setting=$ZygiskSetting ||| Zygisk：未开启；设置值=$ZygiskSetting" -ForegroundColor Red
        }
    } else {
        Write-Host 'Root status: NOT DETECTED ||| Root 状态：未检测到 Root' -ForegroundColor Red
        Write-Host 'If Shell authorization appears, approve it and run again / 若弹出 Shell 授权，请批准后重新运行。' -ForegroundColor Yellow
    }
    Write-KpaStatus 'Firmware' '固件匹配' ("$FirmwareVersion") Green
    Write-KpaStatus 'Image' '目标镜像' ("$(Split-Path -Leaf $PatchedBoot)") Yellow
    Write-KpaStatus 'Image size' '镜像大小' ("$((Get-Item -LiteralPath $PatchedBoot).Length) bytes") Gray
    Write-Host "SHA256                 : $ExpectedBootHash" -ForegroundColor Green
    Write-KpaStatus 'Target' '目标分区' ("boot_$Slot") Yellow

    if ($PreflightOnly) {
        Write-KpaSection 'Preflight completed' '预检完成'
        Write-Host 'No root or flashing command was executed. ||| 未执行任何 Root 或刷写命令。' -ForegroundColor Green
        exit 0
    }

    if ($IsRooted) {
        Write-KpaSection 'Existing Root actions' '已有 Root 操作'
        Write-Host '[1] Update/repair Magisk app and enable Zygisk; do not flash boot / [1] 更新/修复 Magisk 管理器并开启 Zygisk；不刷 boot' -ForegroundColor Green
        Write-Host '[2] Force reflash the matched Root boot / [2] 强制重新刷写已匹配的 Root boot' -ForegroundColor Yellow
        Write-Host '[0] Exit without changes / [0] 不做修改并退出'
        if (-not $CoreUpToDate) {
            Write-Host 'NOTICE: Updating the APK alone does not update Magisk Core. Choose [2] to update Core via the bundled Root boot. ||| 注意：仅更新 APK 不会升级 Magisk Core；要升级核心，请选择 [2] 刷写工具包中的 Root boot。' -ForegroundColor Red
        }
        $Action = Read-Host 'Choose 0, 1 or 2 / 请选择 0、1 或 2'
        if ($Action -eq '0') {
            Write-Host 'No changes made / 未做任何修改。' -ForegroundColor Green
            exit 0
        }
        elseif ($Action -eq '1') {
            Write-Host 'Installing/updating Magisk manager / 正在安装或更新 Magisk 管理器...'
            if ((Get-KpaManagerCode) -le $BundledMagiskCode) {
                & $Adb install -r $MagiskApk
                if ($LASTEXITCODE -ne 0) { throw 'Magisk APK installation failed / Magisk APK 安装失败。' }
            }
            Ensure-KpaManager
            & $Adb push $ZygiskScript /data/local/tmp/enable_zygisk.sh | Out-Null
            & $Adb shell su -c 'chmod 755 /data/local/tmp/enable_zygisk.sh && /data/local/tmp/enable_zygisk.sh'
            if ($LASTEXITCODE -ne 0) { throw 'Failed to enable Zygisk / 无法开启 Zygisk。' }
            & $Adb shell rm -f /data/local/tmp/enable_zygisk.sh | Out-Null
            Install-BundledModulesDisabled
            Write-Host 'Magisk manager updated and Zygisk enabled. Rebooting / Magisk 管理器已更新，Zygisk 已开启，正在重启...' -ForegroundColor Green
            & $Adb reboot
            if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Android reboot failed.' 'Android 重启失败。') }
            Wait-KpaAndroid
            Ensure-KpaManager
            exit 0
        }
        elseif ($Action -ne '2') {
            throw 'Invalid choice; no changes made / 选项无效，未做修改。'
        }
        Write-Host 'Force reflash selected / 已选择强制重新刷写。' -ForegroundColor Yellow
    }

    Write-Host 'Rebooting to bootloader / 正在重启到 Bootloader...'
    & $Adb reboot bootloader
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Failed to enter Bootloader.' '无法进入 Bootloader，已停止。') }
    Wait-KpaFastbootDevice -Fastboot $Fastboot

    $ProductText = Get-FastbootVar 'product'
    $SlotText = Get-FastbootVar 'current-slot'
    $UnlockText = Get-FastbootVar 'unlocked'
    if ($ProductText -notmatch 'k85v1_64|GT78|BW03') { throw 'Unexpected fastboot product / Fastboot 产品信息不匹配。' }
    if ($SlotText -notmatch "current-slot:\s*$Slot") { throw 'Active slot changed unexpectedly / 活动槽检测结果不一致。' }
    if ($UnlockText -notmatch 'unlocked:\s*yes') { throw 'Bootloader is not unlocked / Bootloader 未解锁。请先运行 1_Unlock.cmd。' }

    Write-KpaSection 'Fastboot verified' 'Fastboot 验证通过'
    Write-Host $ProductText.Trim()
    Write-Host $SlotText.Trim() -ForegroundColor Yellow
    Write-Host $UnlockText.Trim() -ForegroundColor Green
    Write-KpaStatus 'Final target' '最终目标' ("boot_$Slot") Yellow
    Write-Host 'WARNING: Flashing boot begins after confirmation / 警告：确认后将开始刷写 boot。' -ForegroundColor Red
    Write-Host 'Restore matching stock boot before OTA / OTA 前必须恢复匹配的原版 boot。' -ForegroundColor Red
    $Confirm = Read-Host 'Type ROOT to continue / 输入 ROOT 继续'
    if ($Confirm -cne 'ROOT') {
        & $Fastboot -s $script:KpaSerial reboot | Out-Null
        throw 'Cancelled safely; rebooting Android / 已安全取消，正在重启 Android。'
    }

    Write-Host "Flashing verified $FirmwareVersion Magisk boot to boot_$Slot / 正在刷写已校验镜像..." -ForegroundColor Yellow
    & $Fastboot -s $script:KpaSerial flash "boot_$Slot" $PatchedBoot
    if ($LASTEXITCODE -ne 0) { throw 'fastboot flash failed / Fastboot 刷写失败。' }
    & $Fastboot -s $script:KpaSerial reboot
    if ($LASTEXITCODE -ne 0) { throw 'fastboot reboot failed / Fastboot 重启失败。' }

    Wait-KpaAndroid

    Write-Host 'Installing Magisk 30.7 / 正在安装 Magisk 30.7...'
    if ((Get-KpaManagerCode) -lt $BundledMagiskCode) {
        & $Adb install -r $MagiskApk
        if ($LASTEXITCODE -ne 0) { throw 'Magisk APK installation failed / Magisk APK 安装失败。' }
    }
    Ensure-KpaManager
    & $Adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-KpaSection 'Magisk first-time setup' 'Magisk 首次初始化'
    Write-Host 'Complete Magisk additional setup and restart if requested. ||| 在掌机完成 Magisk 额外设置，并按提示重启。' -ForegroundColor Yellow
    Write-Host 'Keep USB connected. After restart, unlock the screen and approve USB debugging if prompted. ||| 保持 USB 连接；重启后解锁屏幕，按提示允许 USB 调试。'
    [void](Read-Host 'Press Enter after setup and restart ||| 完成设置及重启后按回车')
    Wait-KpaAndroid

    $RepairBefore = $script:KpaManagerRepairUsed
    Ensure-KpaManager
    if (-not $RepairBefore -and $script:KpaManagerRepairUsed) {
        & $Adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 | Out-Null
        [void](Read-Host 'Check Magisk and finish any requested setup/restart, then press Enter ||| 请检查 Magisk，完成可能出现的额外设置及重启，再按回车')
        Wait-KpaAndroid
        Ensure-KpaManager
    }
    Write-KpaSection 'Shell Root authorization' 'Shell Root 授权'
    Write-Host 'A Shell superuser request may appear. Tap Allow. Waiting up to two minutes. ||| 掌机可能弹出 Shell 超级用户请求，请选择允许。最多等待两分钟。' -ForegroundColor Yellow
    Write-Host 'Keep the screen unlocked. If no prompt appears, open Magisk > Superuser and allow Shell. ||| 保持屏幕解锁；若未弹出请求，请打开 Magisk → 超级用户，允许 Shell。'
    $RootReady = $false
    $RootTimer = [Diagnostics.Stopwatch]::StartNew()
    while ($RootTimer.Elapsed.TotalSeconds -lt 120) {
        $RootTest = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c id"
        if ($RootTest -match 'uid=0') { $RootReady = $true; break }
        Start-Sleep -Seconds 4
    }
    if (-not $RootReady) { throw 'Root authorization not granted / 未获得 Root 授权；请在 Magisk 中批准 Shell 后重试。' }

    & $Adb push $ZygiskScript /data/local/tmp/enable_zygisk.sh | Out-Null
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Failed to transfer the Zygisk setup script.' 'Zygisk 配置脚本传输失败。') }
    & $Adb shell su -c 'chmod 755 /data/local/tmp/enable_zygisk.sh && /data/local/tmp/enable_zygisk.sh'
    if ($LASTEXITCODE -ne 0) { throw 'Failed to enable Zygisk / 无法开启 Zygisk。' }
    & $Adb shell rm -f /data/local/tmp/enable_zygisk.sh
    Install-BundledModulesDisabled
    Write-Host 'Rebooting to activate Zygisk / 正在重启以启用 Zygisk...'
    & $Adb reboot
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Android reboot failed.' 'Android 重启失败。') }
    Wait-KpaAndroid

    Ensure-KpaManager
    $FinalRoot = (& $Adb shell su -c id 2>&1 | Out-String)
    & $Adb push $StatusScript /data/local/tmp/check_root_status.sh | Out-Null
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Status script transfer failed.' '状态检查脚本传输失败。') }
    $FinalStatus = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c 'sh /data/local/tmp/check_root_status.sh'"
    & $Adb shell rm -f /data/local/tmp/check_root_status.sh | Out-Null
    $Zygisk = $FinalStatus -match '(?m)^ZYGISK_PROCESS=running\s*$'
    if ($FinalRoot -notmatch 'uid=0') { throw 'Final root verification failed / 最终 Root 验证失败。' }
    if (-not $Zygisk) { throw 'Zygisk process not detected; check Magisk / 未检测到 Zygisk 进程，请检查 Magisk。' }

    Write-Host ''
    Write-Host 'SUCCESS: Root, Magisk 30.7 and Zygisk are active / 成功：Root、Magisk 30.7、Zygisk 均已启用。' -ForegroundColor Green
    Write-KpaStatus 'Active rooted slot' 'Root 活动槽' ("$Slot") Gray
    Write-KpaStatus 'Firmware' '固件' ("$FirmwareVersion") Gray
    Write-KpaStatus 'Log' '日志' ("$Log") Gray
}
catch {
    Write-KpaSection 'Operation failed' '操作失败'
    Write-Host ((Get-KpaText 'Reason: ' '原因：') + $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host ((Get-KpaText 'Log: ' '日志：') + $Log)
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
