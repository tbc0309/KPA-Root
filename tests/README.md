# Test suite

Every `Test-*.ps1` file is independent and must pass in both Windows PowerShell 5.1 and PowerShell 7.

| Test | Coverage |
| --- | --- |
| `Test-AdbTransfer.ps1` | Native stderr and exit-code preservation during ADB transfers |
| `Test-BootLock.ps1` | Trusted bootloader-state parsing and ambiguous-state rejection |
| `Test-BundledBoots.ps1` | Nine offline stock/patched image pairs without runtime indexes; corrupt patched-image rejection |
| `Test-DeviceProfiles.ps1` | Device identity, firmware tables, module allowlists and confirmation-key hints |
| `Test-LayoutAndAssets.ps1` | Toolkit layout, required tools, stock boot sizes and SHA-256 hashes |
| `Test-Magisk.ps1` | Manager repair policy and CRLF-safe Magisk status parsing |
| `Test-OtaBoot.ps1` | OTA reconstruction prerequisites and verified stock-image reuse |
| `Test-PostRoot.ps1` | Root authorization waits and Zygisk retry/skip behavior |
| `Test-RootScriptArguments.ps1` | Separation and validation of remote script paths and module arguments |
| `Test-SafetyFlow.ps1` | Required confirmations before reboot, erase, lock and partition writes |
| `Test-SlotAuthority.ps1` | Android/Fastboot active-slot agreement without unsafe misc assumptions |
| `Test-UnlockMonitor.ps1` | Fastboot unlock verification, restart and post-reboot verification |
| `Test-WindowsPowerShell.ps1` | UTF-8 BOM, TLS 1.2, recursive parsing and Windows PowerShell 5.1 loading |

The release workflow discovers the suite with `tests/Test-*.ps1`; adding a test does not require editing the workflow.
