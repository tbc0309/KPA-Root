# KONKR Pocket Advance Root Toolkit

[English](README_EN.md) | [简体中文](README_CN.md)

> [!WARNING]
> Only `BW03_20260828` has been tested on the current device. `BW03_20260730` and `BW03_20260813` have not been tested on hardware. Flashing may cause boot failure, data loss or, in extreme cases, device damage. This toolkit provides no safety guarantee; proceed at your own risk.

## Supported devices

- Model: `GT78-VN`
- Board: `k85v1_64`
- Firmware: `BW03_20260730`, `BW03_20260813`, `BW03_20260828`
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

Already-unlocked devices exit immediately. Enter `CONTINUE` to enter Bootloader, then `UNLOCK` after preflight. The command may erase data immediately. If an on-device confirmation appears, select Volume Up / YES.

## 2. Obtain Root

Run `2_Root_EN.cmd`. The script detects firmware 0730, 0813 or 0828, verifies the matching image, and flashes only the active slot.

Check the detected firmware again before flashing. Images are provided for 0730 and 0813, but they have not been validated on physical hardware and are not guaranteed to boot or recover correctly.

Enter `ROOT` after preflight. After Android starts, the script installs Magisk and modules, enables Zygisk, and reboots to verify the result.

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

Run `3_Restore_EN.cmd` before installing an OTA. The script detects the current firmware and restores the matching stock boot only to the active slot. After preflight, enter `RESTORE`; no slot selection is required.

Restore also writes the boot partition. The 0730 and 0813 restore paths have not been tested on hardware; selecting the wrong version or a faulty image may prevent the device from booting.

Confirm that Android boots normally before checking for and installing the OTA. After the OTA boots successfully from its new slot, extract and patch the new firmware's boot image before restoring Root.

Restore menu:

- `[1]` Restore stock boot, then optionally relock.
- `[2]` Relock only, without flashing an image.

Already-locked devices exit. Restore is skipped when the current boot SHA256 matches stock. Unreadable partitions are reported as unknown; missing Root does not prove stock boot.

Relock only when all partitions are matching official images. Enter `Y`, then `LOCK-ERASE`. Data may be erased immediately; complete device setup after reboot.

> [!WARNING]
> Relocking the bootloader is not recommended. Restoring stock boot does not prove that every other partition is official and unmodified. Relocking with a mismatched or modified partition may prevent the device from booting.

Stock image mapping:

- `boot_0730_stock.img` → `BW03_20260730`
- `boot_0813_stock.img` → `BW03_20260813`
- `boot_0828_stock.img` → `BW03_20260828`

Never mix stock or patched boot images from different firmware versions.

## Official firmware downloads

- [Official download page](https://www.ayaneo.com/support/download)

Select “Android Console”, followed by “KONKR Pocket ADVANCE”.

> [!WARNING]
> Treat the package currently provided by the official site as a card-update package, not a verified full line-flash recovery package. A card update may not overwrite every low-level partition and is not guaranteed to restore the complete factory state. Do not rely on it as an unbrick package when Android and Recovery are inaccessible.

## Requirements

1. Battery level of at least 50%.
2. USB debugging enabled and this computer authorized.
3. Use a data-capable USB cable and connect exactly one Android device. Wireless ADB is not used for flashing.
4. ADB, Fastboot, and a signed Android USB driver are bundled. The launcher checks them automatically and requests Windows administrator approval only when the driver must be installed.
5. The script reports missing, unauthorized, offline, or multiple devices separately and will not continue to flashing.
6. Do not disconnect USB while an image is being flashed.

Each script writes a timestamped log in the current folder.
