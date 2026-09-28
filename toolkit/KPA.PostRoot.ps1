function Wait-KpaShellRoot {
    # Show authorization instructions only when access is missing.
    if ((Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c id") -match 'uid=0') { return }
    while ($true) {
        Write-Host (Get-KpaText 'Unlock the handheld and allow Shell in Magisk. Waiting up to two minutes.' '请解锁掌机，在 Magisk 中允许 Shell。最多等待两分钟。') -ForegroundColor Yellow
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while ($timer.Elapsed.TotalSeconds -lt 120) {
            $probe = Get-KpaProbe $Adb "-s $script:KpaSerial shell su -c id"
            if ($probe -match 'uid=0') { return }
            Start-Sleep -Seconds 4
        }
        $choice = Read-Host (Get-KpaText 'Root not authorized. Enter R to retry or Q to stop' '尚未获得 Root 授权。输入 R 重试，Q 停止')
        if ($choice -ieq 'Q') { throw (Get-KpaText 'Cancelled; module installation requires Root.' '已取消；安装模块必须获得 Root 权限。') }
    }
}

function Invoke-KpaAdbTransfer([string[]]$TransferArguments) {
    # Windows PowerShell treats native stderr as an error record, even on success.
    # Scope this preference locally; callers must still check the process exit code.
    $ErrorActionPreference = 'Continue'
    & $Adb @TransferArguments 2>&1 | Out-Null
    $global:LASTEXITCODE = $LASTEXITCODE
}

function Invoke-KpaRootScript([string]$RemotePath) {
    if ($RemotePath -notmatch '^/data/local/tmp/[A-Za-z0-9_.-]+\.sh$') { throw 'Invalid remote script path' }
    # Keep the entire command inside su; adb otherwise exposes shell operators to uid 2000.
    $output = (& $Adb -s $script:KpaSerial shell "su -c 'sh $RemotePath'" 2>&1 | Out-String)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output.Trim() }
}

function Enable-KpaZygiskOptional {
    while ($true) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Invoke-KpaAdbTransfer -TransferArguments @('-s', $script:KpaSerial, 'push', $ZygiskScript, '/data/local/tmp/enable_zygisk.sh')
                if ($LASTEXITCODE -ne 0) { throw (Get-KpaText 'Script transfer failed.' '脚本传输失败。') }
                $result = Invoke-KpaRootScript '/data/local/tmp/enable_zygisk.sh'
                if ($result.ExitCode -eq 0 -and $result.Output -match '(?m)^ZYGISK_ENABLED=1\s*$') {
                    Write-Host (Get-KpaText 'Zygisk enabled; a restart is required.' 'Zygisk 已开启，重启后生效。') -ForegroundColor Green
                    return $true
                }
                Write-Host $result.Output -ForegroundColor Yellow
            } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
            if ($attempt -lt 3) {
                Write-Host (Get-KpaText 'Check Shell Root authorization; retrying Zygisk...' '请检查 Shell Root 授权，正在重试开启 Zygisk……') -ForegroundColor Yellow
                Start-Sleep -Seconds 4
            }
        }
        $choice = Read-Host (Get-KpaText 'Zygisk setup failed. R: retry; S: skip and install modules' 'Zygisk 开启失败。R：重试；S：跳过并安装模块')
        if ($choice -ieq 'S') {
            Write-Host (Get-KpaText 'Zygisk skipped. Modules will be installed disabled; modules requiring Zygisk need it enabled later.' '已跳过 Zygisk。模块仍会安装并默认停用；依赖 Zygisk 的模块需稍后开启 Zygisk 才能使用。') -ForegroundColor Yellow
            return $false
        }
    }
}
