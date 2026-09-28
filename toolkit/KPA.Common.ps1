$script:KpaDriverInf = Join-Path $PSScriptRoot 'drivers\android_winusb\android_winusb.inf'

function Select-LanguageText([string]$Text) {
    if ($null -eq $Text) { return '' }
    if ($Text.Contains(' ||| ')) {
        $Pair = $Text.Split(@(' ||| '), 2, [System.StringSplitOptions]::None)
        if ($Language -eq 'CN') { return $Pair[1] }
        return $Pair[0]
    }
    $Chinese = [regex]::Match($Text, '[\u3400-\u9fff]')
    if (-not $Chinese.Success) { return $Text }
    $Separator = $Text.LastIndexOf(' / ', $Chinese.Index)
    if ($Separator -lt 0) { return $Text }
    if ($Language -eq 'CN') { return $Text.Substring($Separator + 3) }
    $English = $Text.Substring(0, $Separator)
    $ChineseSide = $Text.Substring($Separator + 3)
    if ($ChineseSide -match '[:：]\s*(.+)$') { $English += ': ' + $Matches[1] }
    return $English
}

function Write-Host {
    param([Parameter(Position=0, ValueFromPipeline=$true)][object]$Object = '', [ConsoleColor]$ForegroundColor, [switch]$NoNewline)
    process {
        $Parameters = @{ Object = (Select-LanguageText ([string]$Object)) }
        if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $Parameters.ForegroundColor = $ForegroundColor }
        if ($NoNewline) { $Parameters.NoNewline = $true }
        Microsoft.PowerShell.Utility\Write-Host @Parameters
    }
}

function Read-Host {
    param([Parameter(Position=0)][string]$Prompt)
    Microsoft.PowerShell.Utility\Write-Host ''
    Microsoft.PowerShell.Utility\Read-Host (Select-LanguageText $Prompt)
}

function Get-KpaText([string]$English, [string]$Chinese) {
    if ($Language -eq 'CN') { return $Chinese }
    return $English
}

function Write-KpaBanner([string]$English, [string]$Chinese) {
    Microsoft.PowerShell.Utility\Write-Host ('=' * 78) -ForegroundColor DarkCyan
    Microsoft.PowerShell.Utility\Write-Host ('  ' + (Get-KpaText $English $Chinese)) -ForegroundColor Cyan
    Microsoft.PowerShell.Utility\Write-Host ('=' * 78) -ForegroundColor DarkCyan
    Microsoft.PowerShell.Utility\Write-Host ''
}

function Write-KpaSection([string]$English, [string]$Chinese) {
    Microsoft.PowerShell.Utility\Write-Host ''
    Microsoft.PowerShell.Utility\Write-Host ('-' * 64) -ForegroundColor DarkCyan
    Microsoft.PowerShell.Utility\Write-Host ('  ' + (Get-KpaText $English $Chinese)) -ForegroundColor Cyan
    Microsoft.PowerShell.Utility\Write-Host ('-' * 64) -ForegroundColor DarkCyan
    Microsoft.PowerShell.Utility\Write-Host ''
}

function Write-KpaStatus([string]$English, [string]$Chinese, [string]$Value, [ConsoleColor]$Color = 'Gray') {
    $Label = Get-KpaText $English $Chinese
    $Width = 0
    foreach ($Character in $Label.ToCharArray()) { if ([int]$Character -gt 255) { $Width += 2 } else { $Width++ } }
    Microsoft.PowerShell.Utility\Write-Host ('  ' + $Label + ':' + (' ' * [Math]::Max(2, 24 - $Width)) + $Value) -ForegroundColor $Color
}

function Read-KpaYes([string]$English, [string]$Chinese) {
    $Prompt = (Get-KpaText $English $Chinese) + (Get-KpaText ' Type YES; anything else cancels.' ' 输入 YES，其他输入取消。')
    return ((Read-Host $Prompt) -ceq 'YES')
}

function Write-KpaStep([int]$Current, [int]$Total, [string]$English, [string]$Chinese) {
    Microsoft.PowerShell.Utility\Write-Host ('  [' + $Current + '/' + $Total + '] ' + (Get-KpaText $English $Chinese)) -ForegroundColor White
}

function Write-KpaHint([string]$English, [string]$Chinese, [ConsoleColor]$Color = 'Yellow') {
    Microsoft.PowerShell.Utility\Write-Host ('       ' + (Get-KpaText $English $Chinese)) -ForegroundColor $Color
}

function Read-KpaRetry([string]$English, [string]$Chinese) {
    while ($true) {
        $Choice = Read-Host ((Get-KpaText $English $Chinese) + (Get-KpaText ' [R=retry, Q=stop]' ' [R=继续等待，Q=安全退出]'))
        if ($Choice -ieq 'R') { return $true }
        if ($Choice -ieq 'Q') { return $false }
    }
}

function Test-KpaAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-KpaUsbDriver {
    $DriverList = (& "$env:SystemRoot\System32\pnputil.exe" /enum-drivers 2>&1 | Out-String)
    return ($DriverList -match '(?im)^\s*(Original Name|原始名称)\s*:\s*android_winusb\.inf\s*$')
}

function Install-KpaUsbDriver {
    if (-not (Test-Path -LiteralPath $script:KpaDriverInf -PathType Leaf)) {
        throw (Get-KpaText 'The bundled Android USB driver is missing.' '缺少内置 Android USB 驱动。')
    }
    Write-KpaHint 'The Android USB driver is missing. Accept the Windows administrator prompt.' '缺少 Android USB 驱动。接下来请在 Windows 管理员提示中选择“是”。'
    $Arguments = @('/add-driver', ('"{0}"' -f $script:KpaDriverInf), '/install')
    if (Test-KpaAdministrator) {
        & "$env:SystemRoot\System32\pnputil.exe" @Arguments
        $ExitCode = $LASTEXITCODE
    } else {
        $Process = Start-Process -FilePath "$env:SystemRoot\System32\pnputil.exe" -ArgumentList $Arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        $ExitCode = $Process.ExitCode
    }
    if ($ExitCode -notin @(0,3010) -or -not (Test-KpaUsbDriver)) {
        throw (Get-KpaText 'Android USB driver installation failed or was cancelled.' 'Android USB 驱动安装失败或已取消。')
    }
    & "$env:SystemRoot\System32\pnputil.exe" /scan-devices | Out-Null
}

function Initialize-KpaUsbEnvironment([string]$Adb, [string]$Fastboot) {
    Write-KpaSection 'Environment check' '运行环境检查'
    Write-KpaStep 1 3 'Check ADB and Fastboot tools' '检查 ADB 与 Fastboot 工具'
    foreach ($File in @($Adb, $Fastboot)) {
        if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw ((Get-KpaText 'Required tool is missing: ' '缺少必要工具：') + $File) }
    }
    Write-KpaStatus 'Platform tools' 'ADB / Fastboot 工具' 'OK' Green
    Write-KpaStep 2 3 'Check the Windows USB driver' '检查 Windows USB 驱动'
    if (-not (Test-KpaUsbDriver)) { Install-KpaUsbDriver }
    Write-KpaStatus 'Android USB driver' 'Android USB 驱动' 'OK' Green

    # Root operations require one stable USB transport, not a duplicate wireless ADB endpoint.
    Write-KpaStep 3 3 'Connect and authorize the handheld' '连接并授权掌机'
    Write-KpaHint 'On the handheld: Settings > System > Developer options > enable OEM unlocking and USB debugging.' '掌机操作：设置 → 系统 → 开发者选项 → 开启 OEM 解锁和 USB 调试。'
    Write-KpaHint 'Use a data-capable USB cable, unlock the screen, then tap Allow when prompted.' '使用支持数据传输的 USB 线，解锁屏幕；弹出授权时点击“允许”。'
    Write-KpaHint 'Wireless ADB is disconnected automatically to prevent selecting the wrong device.' '脚本会自动断开无线 ADB，避免选错设备。' DarkGray
    & $Adb disconnect 2>&1 | Out-Null
    & $Adb start-server 2>&1 | Out-Null
    while ($true) {
        Write-KpaHint 'Waiting for one authorized USB device. You have three minutes.' '正在等待一台已授权的 USB 设备，本轮等待三分钟。'
        $LastState = ''
        for ($Attempt = 0; $Attempt -lt 90; $Attempt++) {
            $Rows = @(& $Adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
            $Authorized = @($Rows | Where-Object { $_ -match '\sdevice$' })
            $Unauthorized = @($Rows | Where-Object { $_ -match '\sunauthorized$' })
            $Offline = @($Rows | Where-Object { $_ -match '\soffline$' })
            if ($Authorized.Count -eq 1 -and $Rows.Count -eq 1) {
                $Serial = (($Authorized[0] -split '\s+')[0]).Trim()
                $script:KpaSerial = $Serial
                $env:ANDROID_SERIAL = $Serial
                Write-KpaStatus 'ADB connection' 'ADB 连接' ('OK  [' + $Serial + ']') Green
                return $Serial
            }
            if ($Authorized.Count -gt 1 -or ($Authorized.Count -eq 1 -and $Rows.Count -gt 1)) {
                throw (Get-KpaText 'Multiple ADB devices were detected. Disconnect all other Android devices.' '检测到多台 ADB 设备，请断开其他 Android 设备。')
            }
            $State = if ($Unauthorized.Count) { 'unauthorized' } elseif ($Offline.Count) { 'offline' } else { 'missing' }
            if ($State -ne $LastState) {
                if ($State -eq 'unauthorized') { Write-KpaHint 'Authorization is waiting on the handheld. Tap Allow.' '掌机正在等待授权，请点击“允许”。' }
                elseif ($State -eq 'offline') { Write-KpaHint 'ADB is offline. Restarting the ADB service.' 'ADB 设备离线，正在重启 ADB 服务。'; & $Adb kill-server 2>&1 | Out-Null; & $Adb start-server 2>&1 | Out-Null }
                else { Write-KpaHint 'No USB device yet. Check the cable and USB debugging.' '尚未检测到 USB 设备，请检查数据线和 USB 调试。' }
                $LastState = $State
            }
            if ($Attempt -gt 0 -and ($Attempt % 15) -eq 0) { Write-KpaHint ("Still waiting: $($Attempt * 2) s") ("仍在等待：$($Attempt * 2) 秒") DarkGray }
            Start-Sleep -Seconds 2
        }
        if (-not (Read-KpaRetry 'The device is not ready.' '设备尚未连接成功。')) { throw (Get-KpaText 'Stopped safely before any device change.' '已在修改设备前安全退出。') }
    }
}

function Wait-KpaFastbootDevice([string]$Fastboot) {
    Write-KpaSection 'Fastboot connection' '连接 Fastboot'
    Write-KpaHint 'The handheld should show FASTBOOT MODE. Keep USB connected; no button is needed yet.' '掌机应显示 FASTBOOT MODE。保持 USB 连接，此时无需按键。'
    while ($true) {
        for ($Attempt = 0; $Attempt -lt 90; $Attempt++) {
            $Devices = @(& $Fastboot devices 2>$null | Where-Object { $_ -match '\S' })
            if ($Devices.Count -eq 1) {
                if (($Devices[0] -split '\s+')[0] -ne $script:KpaSerial) { throw (Get-KpaText 'A different Fastboot device was connected.' 'Fastboot 设备与原掌机不一致，已停止。') }
                Write-KpaStatus 'Fastboot connection' 'Fastboot 连接' 'OK' Green
                return
            }
            if ($Devices.Count -gt 1) { throw (Get-KpaText 'Multiple Fastboot devices were detected.' '检测到多台 Fastboot 设备。') }
            if ($Attempt -eq 5 -or ($Attempt -gt 5 -and ($Attempt % 30) -eq 0)) { & "$env:SystemRoot\System32\pnputil.exe" /scan-devices | Out-Null }
            if ($Attempt -gt 0 -and ($Attempt % 15) -eq 0) { Write-KpaHint ("Still waiting: $($Attempt * 2) s") ("仍在等待：$($Attempt * 2) 秒") DarkGray }
            Start-Sleep -Seconds 2
        }
        if (-not (Read-KpaRetry 'Fastboot is not connected. Reconnect USB or check Device Manager.' '尚未连接 Fastboot。请重新插拔 USB 或检查设备管理器。')) { throw (Get-KpaText 'Stopped safely before flashing.' '已在刷写前安全退出。') }
    }
}

# Bound each status probe so a disconnected USB device cannot hang the monitor.
function Get-KpaProbe([string]$File, [string]$Arguments) {
    $Info = New-Object System.Diagnostics.ProcessStartInfo
    $Info.FileName = $File
    $Info.Arguments = $Arguments
    $Info.UseShellExecute = $false
    $Info.CreateNoWindow = $true
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Process = [Diagnostics.Process]::Start($Info)
    try {
        $Output = $Process.StandardOutput.ReadToEndAsync()
        $ErrorOutput = $Process.StandardError.ReadToEndAsync()
        if (-not $Process.WaitForExit(5000)) { $Process.Kill(); $Process.WaitForExit(); return '' }
        if ($Process.ExitCode -ne 0) { return '' }
        return ($Output.Result + $ErrorOutput.Result).Trim()
    } finally { $Process.Dispose() }
}

function Wait-KpaAndroid([int]$TimeoutSeconds = 300) {
    Write-KpaSection 'Waiting for Android' '等待 Android 启动'
    Write-Host (Get-KpaText 'Keep USB connected. Unlock the screen and allow USB debugging if prompted.' '保持 USB 连接；启动后解锁屏幕，如有提示请允许 USB 调试。') -ForegroundColor Yellow
    Write-Host ''
    while ($true) {
        $Timer = [Diagnostics.Stopwatch]::StartNew()
        $NextReport = 0
        while ($Timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            if ((Get-KpaProbe $Adb "-s $script:KpaSerial shell getprop sys.boot_completed") -eq '1') {
                Write-Host 'Android startup verified. ||| 已确认 Android 启动完成。' -ForegroundColor Green
                return
            }
            if ($Timer.Elapsed.TotalSeconds -ge $NextReport) {
                Write-Host ('  ' + (Get-KpaText 'Waiting: ' '已等待：') + [int]$Timer.Elapsed.TotalSeconds + ' s') -ForegroundColor DarkGray
                $NextReport += 30
            }
            Start-Sleep -Seconds 2
        }
        if (-not (Read-KpaRetry 'Android has not finished starting. Check the handheld.' 'Android 尚未完成启动，请检查掌机。')) { throw (Get-KpaText 'Stopped while waiting for Android.' '已停止等待 Android。') }
    }
}

function ConvertFrom-KpaBootLock([string]$BootArguments) {
    # Do not infer the lock state from AVB color or resetprop-modifiable properties.
    $States = @([regex]::Matches($BootArguments, '(?:^|\s)androidboot\.vbmeta\.device_state\s*=\s*"?(locked|unlocked)"?(?=\s|$)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    if ($States.Count -ne 1) { return 'unknown' }
    if ($States[0] -eq 'unlocked') { return '0' }
    return '1'
}

function Get-KpaBootLock {
    $Parts = @()
    foreach ($Path in @('/proc/cmdline', '/proc/bootconfig')) {
        $Text = Get-KpaProbe $Adb "-s $script:KpaSerial shell cat $Path"
        if (-not $Text) { $Text = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c 'cat $Path'" }
        $Parts += $Text
    }
    return ConvertFrom-KpaBootLock ($Parts -join "`n")
}

function Complete-KpaUnlock(
    [scriptblock]$WaitForAndroid = { Wait-KpaAndroid },
    [scriptblock]$GetAndroidLock = { Get-KpaBootLock }
) {
    Write-KpaSection 'Verifying unlock and restarting' '验证解锁并重启'
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    while ($Timer.Elapsed.TotalSeconds -lt 120) {
        $State = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar unlocked"
        if ($State -match 'unlocked:\s*yes') {
            & $Fastboot -s $script:KpaSerial reboot
            if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Unlock verified, but reboot failed.' '解锁已确认，但重启失败。') }
            & $WaitForAndroid
            return
        }
        if ($State -match 'unlocked:\s*no') { throw (Get-KpaText 'The device is still locked.' '设备仍处于锁定状态。') }
        if ((& $GetAndroidLock) -eq '0') {
            & $WaitForAndroid
            return
        }
        Start-Sleep -Seconds 2
    }
    throw (Get-KpaText 'Unlock command returned, but the final state could not be verified.' '解锁命令已返回，但无法确认最终状态，请检查掌机。')
}
