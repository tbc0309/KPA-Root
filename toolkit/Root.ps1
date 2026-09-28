[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN', [switch]$PreflightOnly)

. (Join-Path $PSScriptRoot 'KPA.Common.ps1')
. (Join-Path $PSScriptRoot 'KPA.Magisk.ps1')
. (Join-Path $PSScriptRoot 'KPA.OtaBoot.ps1')
. (Join-Path $PSScriptRoot 'KPA.PostRoot.ps1')
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
    Wait-KpaShellRoot
    Write-KpaSection 'Bundled modules' '安装内置模块'
    Write-Host (Get-KpaText 'Installing 5 modules. Please wait; keep USB connected.' '正在处理 5 个模块，请稍候并保持 USB 连接。')
    Write-Host (Get-KpaText 'New modules remain disabled. Existing modules are preserved.' '新模块默认停用；已有模块及其开关状态保持不变。')
    Write-Host ''
    foreach ($Module in @($FontModule, $RgbModule, $PifModule, $ShamikoModule, $DolbyModule)) {
        Invoke-KpaAdbTransfer -TransferArguments @('push', $Module, ('/data/local/tmp/' + (Split-Path $Module -Leaf)))
        if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Module transfer failed.' '模块传输失败。') }
    }
    Invoke-KpaAdbTransfer -TransferArguments @('push', $ModuleInstaller, '/data/local/tmp/install_bundled_modules.sh')
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Installer transfer failed.' '安装脚本传输失败。') }
    $Result = Invoke-KpaRootScript '/data/local/tmp/install_bundled_modules.sh'
    $Output = $Result.Output
    $DetailLog = [IO.Path]::ChangeExtension($Log, 'modules.log')
    Invoke-KpaAdbTransfer -TransferArguments @('pull', '/data/local/tmp/kpa_module_install.log', $DetailLog)
    if ($LASTEXITCODE -ne 0) { Write-Host (Get-KpaText 'Could not retrieve module diagnostics.' '未能取回模块详细日志。') -ForegroundColor Yellow }
    $Names = @{ kpa_myuppy_font='KPA MYuppy Font'; kpa_rgb_control='KPA RGB Control'; playintegrityfix='Play Integrity Fork'; zygisk_shamiko='Shamiko'; DolbyAtmos='Dolby Atmos' }
    foreach ($Line in ($Output -split '\r?\n')) {
        if ($Line -match '^MODULE_(INSTALLED_DISABLED|SKIPPED|FAILED)=(\w+)$') {
            $State = $Matches[1]; $Id = $Matches[2]
            $Label = if ($Names.ContainsKey($Id)) { $Names[$Id] } else { $Id }
            $Text = switch ($State) {
                'INSTALLED_DISABLED' { Get-KpaText 'Installed / disabled' '已安装，未启用' }
                'SKIPPED' { Get-KpaText 'Existing / unchanged' '已存在，保持不变' }
                'FAILED' { Get-KpaText 'Failed' '安装失败' }
            }
            $Color = if ($State -eq 'FAILED') { 'Red' } else { 'Green' }
            Write-KpaStatus $Label $Label $Text $Color
            Write-Host ''
        }
    }
    Write-Host ((Get-KpaText 'Module log: ' '模块详细日志：') + (Split-Path $DetailLog -Leaf)) -ForegroundColor DarkGray
    if ($Result.ExitCode -ne 0) { throw (Get-KpaText 'Module installation failed. See the module log.' '模块安装失败，请查看模块详细日志。') }
    & $Adb shell rm -f /data/local/tmp/KPA_MYuppy_Font.zip /data/local/tmp/KPA_RGB_Control.zip /data/local/tmp/PlayIntegrityFork.zip /data/local/tmp/Shamiko.zip /data/local/tmp/DolbyAtmos_RazerPhone2_v1.0.6_fix.zip /data/local/tmp/install_bundled_modules.sh | Out-Null
}

Start-Transcript -LiteralPath $Log | Out-Null
try {
    Write-KpaBanner 'KONKR Pocket Advance - Root' 'KONKR Pocket Advance - 获取 Root'
    Write-KpaSection 'Before you start' '开始前须知'
    Write-KpaStatus 'Bootloader' 'Bootloader' (Get-KpaText 'Must be unlocked' '必须已解锁') Yellow
    Write-KpaStatus 'Flash target' '刷写范围' (Get-KpaText 'Active boot slot only' '仅当前活动 boot 槽') Yellow
    Write-KpaStatus 'Before OTA' 'OTA 前' (Get-KpaText 'Restore stock boot first' '必须先恢复原版 boot') Red
    Write-KpaHint 'After an OTA and the first successful boot, run this Root script again. A missing boot is reconstructed from official incremental OTAs.' 'OTA 完成并成功进入新系统后，再次运行本 Root 脚本；缺少 boot 时会从官方增量 OTA 自动合成。'
    Write-KpaHint 'For automatic OTA preparation and post-update patching, use the Root edition of KPA Tools with KPA Root Helper.' '如需自动完成 OTA 前准备和更新后修补，建议配合 KPA助手 Root 版的 KPA Root Helper。' DarkGray

    foreach ($File in @($Adb, $Fastboot, $MagiskApk, $ZygiskScript, $StatusScript, $ModuleInstaller, $FontModule, $RgbModule, $PifModule, $ShamikoModule, $DolbyModule)) {
        if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file missing / 缺少文件：$File" }
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $MagiskApk).Hash -ne $ExpectedApkHash) {
        throw 'Magisk APK SHA256 mismatch / Magisk APK 哈希不匹配。'
    }

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
        Invoke-KpaAdbTransfer -TransferArguments @('push', $StatusScript, '/data/local/tmp/check_root_status.sh')
        if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Status script transfer failed.' '状态检查脚本传输失败。') }
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
    if ($Build -notmatch '^BW03_(\d{8})(?:_|$)') {
        throw (Get-KpaText "Unsupported firmware identifier: $Build." "无法识别固件版本：$Build。")
    }
    $FirmwareDate = $Matches[1]
    $FirmwareVersion = $FirmwareDate.Substring(4)
    $PatchedBoot = Join-Path $RootDir "boot_${FirmwareVersion}_magisk_30.7.img"
    $KnownPatchedHashes = @{
        '0730' = 'B77034ED82094F73A5DB0A76870A6905399EA49934FAC05838D874019E748994'
        '0813' = '4836B595C78F52A63EAA05FB0B4A7F344B609E6A7013740CC477778E729F636A'
        '0828' = 'BB98AC02CEBE9CC7B3FD070660D76A5B57AF03BF24A8758E8FE63E61408149F1'
    }
    if (-not (Test-Path -LiteralPath $PatchedBoot -PathType Leaf)) {
        Write-KpaSection 'Prepare missing boot image' '准备缺少的 boot 镜像'
        $StockInfo = Ensure-KpaStockBoot -RootDir $RootDir -Build $Build -Serial $Serial
        $PatchedBoot = Ensure-KpaPatchedBoot -RootDir $RootDir -Stock $StockInfo -Adb $Adb
    }
    $ExpectedBootHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PatchedBoot).Hash
    if ($KnownPatchedHashes.ContainsKey($FirmwareVersion) -and $ExpectedBootHash -ne $KnownPatchedHashes[$FirmwareVersion]) {
        throw "Patched boot SHA256 mismatch / $FirmwareVersion 修补镜像哈希不匹配。"
    }
    if (-not $KnownPatchedHashes.ContainsKey($FirmwareVersion)) {
        $RecordedPatchedHash = Get-KpaRecordedPatchedHash -RootDir $RootDir -Version $FirmwareVersion
        if (-not $RecordedPatchedHash -or $ExpectedBootHash -ne $RecordedPatchedHash) {
            throw "Generated patched boot is not verified / $FirmwareVersion 自动修补镜像缺少有效校验记录。"
        }
    }
    if ($Slot -notin @('a','b')) { throw "Unable to determine active slot / 无法识别活动槽：$Slot" }

    Write-KpaSection 'Device information' '设备信息'
    Write-KpaStatus 'ADB serial' '设备序列号' ("$Serial") Gray
    Write-KpaStatus 'Model / board' '型号 / 主板' ("$Model / $Board") Gray
    Write-KpaStatus 'Build' '系统版本' ("$Build") White
    Write-KpaStatus 'Android / SDK' 'Android / SDK' ("$Android / $Sdk") Gray
    Write-KpaStatus 'Active slot' '活动槽' ("$Slot") Yellow
    Write-KpaStatus 'Boot state' 'AVB 状态' ("$BootState") Gray
    Write-KpaStatus 'Flash locked' '锁状态' ("$FlashLocked") Gray
    Write-KpaSection 'Root and Magisk' 'Root 与 Magisk'
    if ($IsRooted) {
        Write-KpaStatus 'Root' 'Root 状态' (Get-KpaText 'Granted' '已获取 Root') Green
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
            Write-KpaStatus 'Zygisk' 'Zygisk' (Get-KpaText 'Active' '已生效') Green
        } elseif ($ZygiskEnabled) {
            Write-KpaStatus 'Zygisk' 'Zygisk' (Get-KpaText 'Enabled; not verified' '已开启，尚未确认生效') Yellow
        } else {
            Write-KpaStatus 'Zygisk' 'Zygisk' (Get-KpaText 'Disabled' '未开启') Yellow
        }
    } else {
        Write-KpaStatus 'Root' 'Root 状态' (Get-KpaText 'Not detected' '未检测到') Yellow
        Write-KpaHint 'This is expected before the first Root flash. Continue after checking the device and image summary.' '首次获取 Root 前属于正常状态，请核对设备与镜像摘要后继续。' DarkGray
    }
    Write-KpaSection 'Matched boot image' '已匹配的刷写镜像'
    Write-KpaStatus 'Firmware' '固件匹配' ("$FirmwareVersion") White
    Write-KpaStatus 'Image' '目标镜像' ("$(Split-Path -Leaf $PatchedBoot)") Yellow
    Write-KpaStatus 'Image size' '镜像大小' ("$((Get-Item -LiteralPath $PatchedBoot).Length) bytes") Gray
    Write-KpaStatus 'SHA256' 'SHA256 校验' (Get-KpaText 'Passed' '通过') Green
    Write-Host ('  ' + $ExpectedBootHash.Substring(0, 32)) -ForegroundColor DarkGray
    Write-Host ('  ' + $ExpectedBootHash.Substring(32)) -ForegroundColor DarkGray
    Write-Host ''
    Write-KpaStatus 'Target' '目标分区' ("boot_$Slot") Yellow

    if ($PreflightOnly) {
        Write-KpaSection 'Preflight completed' '预检完成'
        Write-Host 'No root or flashing command was executed. ||| 未执行任何 Root 或刷写命令。' -ForegroundColor Green
        exit 0
    }

    if ($IsRooted) {
        Write-KpaSection 'Existing Root actions' '已有 Root 操作'
        Write-Host (Get-KpaText '  [1] Configure Magisk and modules' '  [1] 配置 Magisk 和模块') -ForegroundColor White
        Write-Host (Get-KpaText '      Repair manager, enable Zygisk, install modules. No boot write.' '      修复管理器、开启 Zygisk、安装模块；不刷写 boot。') -ForegroundColor Gray
        Write-Host ''
        Write-Host (Get-KpaText '  [2] Reflash Root boot' '  [2] 重新刷写 Root boot') -ForegroundColor Yellow
        Write-Host (Get-KpaText '      Write the matched image. Confirmation is required.' '      写入匹配的镜像，执行前需要再次确认。') -ForegroundColor Gray
        Write-Host ''
        Write-Host (Get-KpaText '  [0] Exit without changes' '  [0] 退出，不做修改') -ForegroundColor White
        Write-Host ''
        if (-not $CoreUpToDate) {
            Write-Host 'NOTICE: Updating the APK alone does not update Magisk Core. Choose [2] to update Core via the bundled Root boot. ||| 注意：仅更新 APK 不会升级 Magisk Core；要升级核心，请选择 [2] 刷写工具包中的 Root boot。' -ForegroundColor Red
        }
        $Action = Read-Host 'Choose 0, 1 or 2 / 请选择 0、1 或 2'
        if ($Action -eq '0') {
            Write-Host 'No changes made / 未做任何修改。' -ForegroundColor Green
            exit 0
        }
        elseif ($Action -eq '1') {
            if (-not (Read-KpaYes 'Configure Magisk, Zygisk and bundled modules, then reboot?' '配置 Magisk、Zygisk 和随包模块，然后重启？')) {
                Write-Host 'Cancelled safely; no changes were made. ||| 已安全取消，未执行修改。' -ForegroundColor Green
                exit 0
            }
            Write-Host 'Installing/updating Magisk manager / 正在安装或更新 Magisk 管理器...'
            if ((Get-KpaManagerCode) -le $BundledMagiskCode) {
                & $Adb install -r $MagiskApk
                if ($LASTEXITCODE -ne 0) { throw 'Magisk APK installation failed / Magisk APK 安装失败。' }
            }
            Ensure-KpaManager
            Wait-KpaShellRoot
            $ZygiskConfigured = Enable-KpaZygiskOptional
            & $Adb shell rm -f /data/local/tmp/enable_zygisk.sh | Out-Null
            Install-BundledModulesDisabled
            Write-Host (Get-KpaText 'Magisk and module setup completed. Rebooting...' 'Magisk 与模块配置完成，正在重启……') -ForegroundColor Green
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

    Write-KpaSection 'Enter Fastboot' '进入 Fastboot'
    Write-KpaHint 'The handheld will restart and display FASTBOOT MODE. Keep USB connected.' '掌机将重启并显示 FASTBOOT MODE，请保持 USB 连接。'
    if (-not (Read-KpaYes 'Device checks passed. Enter Fastboot and continue Root?' '设备检查通过。进入 Fastboot 并继续 Root？')) {
        Write-Host 'Cancelled safely; no partition was written. ||| 已安全取消，未写入任何分区。' -ForegroundColor Green
        exit 0
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
    if (-not (Read-KpaYes 'Flash the verified Root boot?' '刷写已验证的 Root boot？')) {
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
    Write-KpaStep 1 3 'Look at the handheld and complete Magisk additional setup' '查看掌机并完成 Magisk 额外设置'
    Write-KpaStep 2 3 'Allow Magisk to restart the device when requested' 'Magisk 要求重启时允许重启'
    Write-KpaStep 3 3 'Unlock the screen and allow USB debugging again, then return here' '重启后解锁屏幕，再次允许 USB 调试，然后回到电脑'
    Write-Host 'Keep USB connected. After restart, unlock the screen and approve USB debugging if prompted. ||| 保持 USB 连接；重启后解锁屏幕，按提示允许 USB 调试。'
    if (-not (Read-KpaYes 'Has Magisk setup and the requested restart completed?' 'Magisk 设置及所需重启是否已经完成？')) {
        throw (Get-KpaText 'Stopped before post-Root verification.' '已停止，尚未执行 Root 后校验。')
    }
    Wait-KpaAndroid

    $RepairBefore = $script:KpaManagerRepairUsed
    Ensure-KpaManager
    if (-not $RepairBefore -and $script:KpaManagerRepairUsed) {
        & $Adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 | Out-Null
        if (-not (Read-KpaYes 'Has the additional Magisk setup and restart completed?' 'Magisk 额外设置及重启是否已经完成？')) {
            throw (Get-KpaText 'Stopped before the final Magisk verification.' '已停止，尚未执行最终 Magisk 校验。')
        }
        Wait-KpaAndroid
        Ensure-KpaManager
    }
    Write-KpaSection 'Shell Root authorization' 'Shell Root 授权'
    Write-KpaHint 'Keep the handheld unlocked. When Shell requests superuser access, tap Allow.' '保持掌机解锁；Shell 请求超级用户权限时点击“允许”。'
    Write-KpaHint 'If no request appears, open Magisk > Superuser and allow Shell. The script waits and can retry.' '若没有弹窗，请打开 Magisk → 超级用户并允许 Shell；脚本会等待并支持重试。' DarkGray
    Wait-KpaShellRoot
    $ZygiskConfigured = Enable-KpaZygiskOptional
    & $Adb shell rm -f /data/local/tmp/enable_zygisk.sh
    Install-BundledModulesDisabled
    Write-KpaSection 'Apply configuration' '应用配置'
    Write-Host (Get-KpaText 'Rebooting to finish setup...' '正在重启以完成配置……')
    & $Adb reboot
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Android reboot failed.' 'Android 重启失败。') }
    Wait-KpaAndroid

    Ensure-KpaManager
    Wait-KpaShellRoot
    $FinalRoot = (& $Adb shell su -c id 2>&1 | Out-String)
    Invoke-KpaAdbTransfer -TransferArguments @('push', $StatusScript, '/data/local/tmp/check_root_status.sh')
    if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Status script transfer failed.' '状态检查脚本传输失败。') }
    $FinalStatus = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c 'sh /data/local/tmp/check_root_status.sh'"
    & $Adb shell rm -f /data/local/tmp/check_root_status.sh | Out-Null
    $Zygisk = $FinalStatus -match '(?m)^ZYGISK_PROCESS=running\s*$'
    if ($FinalRoot -notmatch 'uid=0') { throw 'Final root verification failed / 最终 Root 验证失败。' }
    if (-not $Zygisk) { Write-Host (Get-KpaText 'Zygisk is not running. Check Magisk settings; installed modules are retained.' 'Zygisk 未运行，请检查 Magisk 设置；已安装的模块会保留。') -ForegroundColor Yellow }

    Write-Host ''
    Write-KpaSection 'Completed' '操作完成'
    Write-Host (Get-KpaText 'Root and module installation completed.' 'Root 与模块安装完成。') -ForegroundColor Green
    Write-Host ''
    Write-KpaStatus 'Active rooted slot' 'Root 活动槽' ("$Slot") Gray
    Write-KpaStatus 'Firmware' '固件' ("$FirmwareVersion") Gray
    Write-Host ''
    Write-Host (Get-KpaText 'Enable the modules you need in Magisk > Modules.' '请在 Magisk → 模块中启用需要的模块。')
    Write-Host ''
    Write-Host (Get-KpaText 'Log saved beside this script:' '日志已保存在脚本所在文件夹：')
    Write-Host ('  ' + (Split-Path $Log -Leaf))
    Write-Host ''
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
