$ErrorActionPreference = 'Stop'
$Toolkit = Join-Path $PSScriptRoot '..\toolkit'

function Read-Source([string]$Name) {
    return Get-Content -LiteralPath (Join-Path $Toolkit $Name) -Raw
}

function Assert-Before([string]$Text, [string]$First, [string]$Second, [string]$Name) {
    $FirstIndex = $Text.IndexOf($First, [StringComparison]::Ordinal)
    $SecondIndex = $Text.IndexOf($Second, [StringComparison]::Ordinal)
    if ($FirstIndex -lt 0 -or $SecondIndex -lt 0 -or $FirstIndex -ge $SecondIndex) {
        throw "Safety order failed: $Name"
    }
}

$Common = Read-Source 'scripts\Common.ps1'
if ($Common -notmatch "-ceq 'YES'") { throw 'YES confirmation is not case-sensitive and centralized.' }
Assert-Before $Common 'enable OEM unlocking and USB debugging; disable Verify apps over USB.' '    Write-KpaUsbSecurityHints' 'Play Protect hint follows Developer options'
Assert-Before $Common '    Write-KpaUsbSecurityHints' 'Use a data-capable USB cable' 'USB security hints precede connection instructions'
if ([regex]::Matches($Common, '(?m)^\s+Write-KpaUsbSecurityHints\s*$').Count -ne 2) { throw 'USB security hints must appear during initial setup and post-unlock setup.' }

$Unlock = Read-Source 'scripts\Unlock.ps1'
Assert-Before $Unlock "Read-KpaYes 'Enter Bootloader?'" '& $Adb reboot bootloader' 'unlock Fastboot confirmation'
Assert-Before $Unlock "Read-KpaYes 'Erase user data and unlock the bootloader?'" '& $Fastboot -s $script:KpaSerial flashing unlock' 'data-wipe confirmation'

$Root = Read-Source 'scripts\Root.ps1'
Assert-Before $Root "Read-KpaYes 'Configure Magisk, Zygisk and bundled modules, then reboot?'" '& $Adb reboot' 'existing Root configuration confirmation'
Assert-Before $Root "Read-KpaYes 'Device checks passed. Enter Fastboot and continue Root?'" '& $Adb reboot bootloader' 'Root Fastboot confirmation'
Assert-Before $Root "Read-KpaYes 'Flash the verified Root boot?'" '& $Fastboot -s $script:KpaSerial flash' 'Root boot confirmation'
if ($Root -match 'Press Enter after|按回车') { throw 'Root workflow still contains an Enter confirmation.' }

$Restore = Read-Source 'scripts\Restore.ps1'
Assert-Before $Restore "Read-KpaYes 'Enter Bootloader?'" '& $Adb reboot bootloader' 'restore Fastboot confirmation'
Assert-Before $Restore "Read-KpaYes 'Restore the verified stock boot?'" '& $Fastboot -s $script:KpaSerial flash' 'stock boot confirmation'
Assert-Before $Restore "Read-KpaYes 'Relock the bootloader now?'" '& $Fastboot -s $script:KpaSerial flashing lock' 'relock confirmation'
Assert-Before $Restore "Read-KpaYes 'Confirm that ALL partitions are stock" '& $Fastboot -s $script:KpaSerial flashing lock' 'relock data-wipe confirmation'

$LegacyTokens = '(?-i:Type CONTINUE|输入 CONTINUE|LOCK-ERASE|Type ROOT|Type RESTORE|Type UNLOCK|输入 ROOT|输入 RESTORE|输入 UNLOCK)'
foreach ($Name in @('Unlock.ps1','Root.ps1','Restore.ps1')) {
    if ((Read-Source ("scripts\" + $Name)) -match $LegacyTokens) { throw "Legacy confirmation token found in $Name" }
}

Write-Output 'PASS: confirmations precede every reboot, flash, unlock and relock boundary'
