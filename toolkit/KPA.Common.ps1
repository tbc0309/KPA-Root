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
    Microsoft.PowerShell.Utility\Write-Host ('-- ' + (Get-KpaText $English $Chinese) + ' ' + ('-' * 48)) -ForegroundColor Cyan
    Microsoft.PowerShell.Utility\Write-Host ''
}

function Write-KpaStatus([string]$English, [string]$Chinese, [string]$Value, [ConsoleColor]$Color = 'Gray') {
    $Label = Get-KpaText $English $Chinese
    $Width = 0
    foreach ($Character in $Label.ToCharArray()) { if ([int]$Character -gt 255) { $Width += 2 } else { $Width++ } }
    Microsoft.PowerShell.Utility\Write-Host ('  ' + $Label + ':' + (' ' * [Math]::Max(2, 24 - $Width)) + $Value) -ForegroundColor $Color
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
    Write-Host 'The Android USB driver is not installed. Windows will request administrator approval. ||| 尚未安装 Android USB 驱动，Windows 即将请求管理员授权。' -ForegroundColor Yellow
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
    foreach ($File in @($Adb, $Fastboot)) {
        if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw ((Get-KpaText 'Required tool is missing: ' '缺少必要工具：') + $File) }
    }
    Write-KpaStatus 'Platform tools' 'ADB / Fastboot 工具' 'OK' Green
    if (-not (Test-KpaUsbDriver)) { Install-KpaUsbDriver }
    Write-KpaStatus 'Android USB driver' 'Android USB 驱动' 'OK' Green

    # Root operations require one stable USB transport, not a duplicate wireless ADB endpoint.
    & $Adb disconnect 2>&1 | Out-Null
    & $Adb start-server 2>&1 | Out-Null
    Write-Host 'Waiting for one USB device. Unlock the screen and approve this computer if prompted. ||| 正在等待一台 USB 设备。如掌机弹出提示，请解锁屏幕并允许此电脑调试。' -ForegroundColor Yellow
    $LastState = ''
    for ($Attempt = 0; $Attempt -lt 60; $Attempt++) {
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
            if ($State -eq 'unauthorized') { Write-Host 'Authorization required on the handheld. ||| 请在掌机上允许 USB 调试授权。' -ForegroundColor Yellow }
            elseif ($State -eq 'offline') { Write-Host 'ADB is offline; restarting the ADB service. ||| ADB 设备离线，正在重启 ADB 服务。' -ForegroundColor Yellow; & $Adb kill-server 2>&1 | Out-Null; & $Adb start-server 2>&1 | Out-Null }
            else { Write-Host 'No USB device detected. Check the data cable and enable USB debugging. ||| 未检测到 USB 设备，请检查数据线并开启 USB 调试。' -ForegroundColor Yellow }
            $LastState = $State
        }
        Start-Sleep -Seconds 2
    }
    throw (Get-KpaText 'Timed out while waiting for an authorized USB ADB device.' '等待已授权的 USB ADB 设备超时。')
}

function Wait-KpaFastbootDevice([string]$Fastboot) {
    Write-Host 'Waiting for Fastboot USB connection... ||| 正在等待 Fastboot USB 连接……' -ForegroundColor Yellow
    for ($Attempt = 0; $Attempt -lt 60; $Attempt++) {
        $Devices = @(& $Fastboot devices 2>$null | Where-Object { $_ -match '\S' })
        if ($Devices.Count -eq 1) {
            if (($Devices[0] -split '\s+')[0] -ne $script:KpaSerial) { throw (Get-KpaText 'A different Fastboot device was connected.' 'Fastboot 设备与原掌机不一致，已停止。') }
            Write-KpaStatus 'Fastboot connection' 'Fastboot 连接' 'OK' Green
            return
        }
        if ($Devices.Count -gt 1) { throw (Get-KpaText 'Multiple Fastboot devices were detected.' '检测到多台 Fastboot 设备。') }
        if ($Attempt -eq 5) { & "$env:SystemRoot\System32\pnputil.exe" /scan-devices | Out-Null }
        Start-Sleep -Seconds 2
    }
    throw (Get-KpaText 'Fastboot was not detected. Reconnect USB and check Device Manager.' '未检测到 Fastboot，请重新连接 USB 并检查设备管理器。')
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
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    $NextReport = 0
    while ($Timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ((Get-KpaProbe $Adb "-s $script:KpaSerial shell getprop sys.boot_completed") -eq '1') {
            Write-Host 'Android startup verified. ||| 已确认 Android 启动完成。' -ForegroundColor Green
            return
        }
        if ($Timer.Elapsed.TotalSeconds -ge $NextReport) {
            Write-Host ((Get-KpaText 'Waiting; unlock the screen and approve USB debugging if prompted. Elapsed: ' '等待中；如有提示请解锁屏幕并允许 USB 调试。已等待：') + [int]$Timer.Elapsed.TotalSeconds + ' s')
            $NextReport += 15
        }
        Start-Sleep -Seconds 2
    }
    throw (Get-KpaText 'Android startup could not be verified before timeout. Check the handheld.' '等待超时，尚未确认 Android 启动完成，请检查掌机。')
}

function Complete-KpaUnlock {
    Write-KpaSection 'Verifying unlock and restarting' '验证解锁并重启'
    $Timer = [Diagnostics.Stopwatch]::StartNew()
    while ($Timer.Elapsed.TotalSeconds -lt 120) {
        $State = Get-KpaProbe $Fastboot "-s $script:KpaSerial getvar unlocked"
        if ($State -match 'unlocked:\s*yes') {
            & $Fastboot -s $script:KpaSerial reboot
            if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Unlock verified, but reboot failed.' '解锁已确认，但重启失败。') }
            Wait-KpaAndroid
            return
        }
        if ($State -match 'unlocked:\s*no') { throw (Get-KpaText 'The device is still locked.' '设备仍处于锁定状态。') }
        if ((Get-KpaProbe $Adb "-s $script:KpaSerial shell getprop ro.boot.flash.locked") -eq '0') {
            Wait-KpaAndroid
            return
        }
        Start-Sleep -Seconds 2
    }
    throw (Get-KpaText 'Unlock command returned, but the final state could not be verified.' '解锁命令已返回，但无法确认最终状态，请检查掌机。')
}
