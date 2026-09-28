# KONKR Pocket Advance Root Toolkit

[English](README_EN.md) | [简体中文](README_CN.md)

> [!WARNING]
> Direct KPA-Root flashing has been verified on `BW03_20260730` and `BW03_20260828`. The same device also completed two consecutive automatic official OTA patching loops, `0730 → 0813` and `0813 → 0828`. Direct Fastboot flashing of `BW03_20260813` has not been tested separately. Flashing may still cause boot failure, data loss, or device damage. Proceed at your own risk.

## Supported devices

- Model: `GT78-VN`
- Board: `k85v1_64`
- Firmware: bundled for `BW03_20260730`, `BW03_20260813` and `BW03_20260828`; later builds can be generated from a continuous official incremental OTA chain
- Root solution: Magisk 30.7 with Zygisk

Scripts display device, firmware, lock state and target partition, select the active slot, and verify image hashes. Unsupported devices or mismatched firmware are not flashed.

## Buttons and boot modes

- While powered off, hold Power + `MODE` to open the boot-mode menu.
- Press `MODE` to cycle through `Recovery Mode`, `Fastboot Mode` and `Normal Mode`.
- Press `LC` to confirm the selected boot mode.
- In Recovery, use the volume wheel to move up or down; `MODE` can also cycle through the choices.
- Press Power to confirm in Recovery.
- Fastboot Volume Up / YES corresponds to the `MODE` button to the right of `L2`.

## 1. Unlock the bootloader

Run `1_Unlock_EN.cmd`. Unlocking normally erases all user data, so back up first.

Enter `YES` to verify the real lock state in Fastboot. An already-unlocked device receives no unlock command and reboots automatically. If Fastboot confirms that it is still locked, enter `YES` again before unlocking. The command may erase data immediately. If an on-device confirmation appears, select Volume Up / YES.

## 2. Obtain Root

Run `2_Root_EN.cmd`. The script detects the current firmware, verifies and reuses an existing image first, and flashes only the active slot.

When an image is missing, the script queries the official OTA service, preserves the server filename under `ota-cache`, applies each adjacent incremental OTA to an earlier stock boot, and creates both the current stock boot and a Magisk 30.7 patched boot. It stops without flashing if a continuous official chain is unavailable. Existing images are never overwritten.

An automatically generated new version has not been tested on hardware. Successful reconstruction and verification do not eliminate the risk of a boot-chain change or boot failure.

Check the detected firmware again before flashing. Direct KPA-Root operation is verified on 0730 and 0828. Direct Fastboot flashing of 0813 remains separately untested.

After device checks pass, enter `YES` before the script enters Fastboot. After Fastboot verification, enter `YES` again before flashing. Once Android starts, the script installs Magisk and modules, enables Zygisk, and reboots to verify the result. Later prompts that wait for Magisk setup also use `YES` to continue.

Complete Magisk additional setup and any requested restart before continuing on the PC. Tap Allow for Shell superuser requests. If no prompt appears, open Magisk > Superuser and allow Shell.

Manager versions are checked after installation and restarts. Missing, stub or older managers receive one automatic repair; newer versions are preserved. Failed verification stops the workflow.

If Root already exists, the summary shows the Magisk Core, Magisk manager and bundled versions, plus the Zygisk setting and process state. It then offers:

- `[1]` Update or repair the manager and enable Zygisk without flashing boot.
- `[2]` Force-flash the matching Root boot.
- `[0]` Exit safely.

Updating the APK does not update Magisk Core. Choose `[2]` when the installed Core is older than the bundled version.

### Bundled modules

Includes `KPA MYuppy Font`, `KPA RGB Control`, `Play Integrity Fork`, `Shamiko` and `Dolby Atmos Razer Phone 2` (landscape graphical equalizer fix). New modules are disabled by default; existing modules retain their state. Enable them in Magisk and reboot to activate.

### Dolby Atmos

Upstream project：[Dolby Atmos Razer Phone 2](https://github.com/reiryuki/Dolby-Atmos-Razer-Phone2-Magisk-Module)

Fixes the graphical equalizer display in landscape.

Before use, go to **Settings → Sound → Sound enhancement** and enable **BesLoudness (speaker volume booster)**.

> Enabling Dolby changes the reported device identity to Razer Phone 2, which may affect vendor apps.

Play Integrity Fork and Shamiko do not configure hiding lists automatically or guarantee passing Play Integrity.

## 3. Restore before OTA

Run `3_Restore_EN.cmd` before installing an OTA. The script detects the current firmware and restores the matching stock boot only to the active slot. Enter `YES` at each confirmation; no slot selection is required.

Restore also writes the boot partition and uses the same OTA reconstruction feature as the Root script. If the stock boot for the installed firmware is missing, it rebuilds that version step by step from an earlier stock boot and official adjacent incremental OTAs. Restore proceeds only after verification, so later normal OTA releases usually do not require a newly packaged toolkit.

Automatic reconstruction requires Internet access, a continuous official incremental chain and a working ADB connection. If the vendor changes the service or package format, or the chain is incomplete, the script stops without flashing.

Confirm that Android boots normally before checking for and installing the OTA. After the OTA boots successfully from its new slot, run the Root script again; it can reconstruct and patch a missing image for the new firmware. Never flash an older patched boot into a newer firmware build.

The [KPA Tools Root edition](https://github.com/tbc0309/KPA-Tools/releases/latest) is recommended. KPA Root Helper can automate pre-OTA stock restoration, post-update patching and verification of the new slot, while keeping the old slot on its matching stock boot. Restart only after the green **Ready to restart** notice appears in System Update.

Hardware validation completed: KPA-Root on 0730 and 0828; KPA Root Helper official OTA loops from 0730 to 0813 and from 0813 to 0828. A direct KPA-Root Fastboot flash of 0813 has not been tested separately.

Restore menu:

- `[1]` Restore stock boot, then optionally relock.
- `[2]` Relock only, without flashing an image.

Already-locked devices exit. Restore is skipped when the current boot SHA256 matches stock. Unreadable partitions are reported as unknown; missing Root does not prove stock boot.

Relock only when all partitions are matching official images. Enter `YES` twice when prompted. Data may be erased immediately; complete device setup after reboot.

> [!WARNING]
> Relocking the bootloader is not recommended. Restoring stock boot does not prove that every other partition is official and unmodified. Relocking with a mismatched or modified partition may prevent the device from booting.

Stock image mapping:

- `boot_0730_stock.img` → `BW03_20260730`
- `boot_0813_stock.img` → `BW03_20260813`
- `boot_0828_stock.img` → `BW03_20260828`

Never mix stock or patched boot images from different firmware versions.

## Official Fastboot firmware downloads

- 中文：[AYANEO 服务支持下载](https://ayaneo.com.cn/support/download)
- English: [AYANEO Support Download](https://www.ayaneo.com/support/download)

The pages directly list the KONKR Pocket Advance flashing tool, guide, and Fastboot ROM. The Chinese page includes the flashing-tool guide and 0730 package; the English page lists the 0730 Fastboot ROM.

> [!WARNING]
> This is an MTK Fastboot flashing package, not an in-system card-update OTA. It writes multiple partitions and may erase data. Follow the matching official tool and guide exactly, and never disconnect USB while flashing.

Select **`Firmware Upgrade`** in SP Flash Tool. Do not use `Download Only` or `Format All + Download`. The official package provides the A-slot boot partitions; `Download Only` may preserve the previously active slot and leave the handheld returning to Fastboot after flashing. If that happens, flash the package again with **`Firmware Upgrade`**. Manually forcing slot A is not part of the normal recovery procedure. The first boot may take 5–10 minutes.

## Requirements

1. Battery level of at least 50%.
2. Open **Settings → System → Developer options**, enable **OEM unlocking** and **USB debugging**, and authorize this computer.
3. Use a data-capable USB cable and connect exactly one Android device. Wireless ADB is not used for flashing.
4. ADB, Fastboot, and a signed Android USB driver are included. The script guides the user through tool checks, driver installation, USB debugging authorization, and device preflight; no preinstallation is required.
5. ADB, Fastboot, Android startup, and Root authorization waits report progress and allow another wait cycle or a safe exit. Unauthorized, offline, or multiple devices never proceed to flashing.
6. Do not disconnect USB while an image is being flashed.

Each script writes a timestamped log in the current folder.
