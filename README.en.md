# KPA Root

[English](README.en.md) | [简体中文](README.md)

Bootloader unlock, Root, stock-boot restore, and post-OTA patching toolkit primarily developed for **KONKR Pocket Advance (KPA)**, with Chinese and English documentation and launchers.

KPA has completed hardware Root testing across multiple firmware versions, restore preflight testing, and two consecutive official OTA automatic-patching cycles. Before any write, the toolkit verifies device identity, firmware, active slot, bootloader state, and image hashes. It can also reconstruct a missing stock boot through official adjacent incremental OTAs.

> [!CAUTION]
> This toolkit can reconstruct and patch boot images from official incremental OTAs, so it will generally support later official firmware without waiting for a toolkit update. When a new OTA is available, first run `3_Restore_EN.cmd` to restore the stock boot for the current system. Complete the official OTA, then run `2_Root_EN.cmd` to restore Root on the updated system. Using the **KPA Tools Root edition** is recommended: before the OTA, open Root Manager and select **Prepare for OTA**. After preparation completes, install the official OTA normally; KPA Root Helper will automatically patch and verify Root for the updated system.

> [!WARNING]
> Direct KPA-Root flashing has been verified on `BW03_20260730` and `BW03_20260828`. The same device also completed two consecutive automatic official OTA patching loops, `0730 → 0813` and `0813 → 0828`. Any boot write may still cause boot failure, data loss, or device damage. Proceed at your own risk.

![Android home screen](docs/images/kpa-android-home.png)

![Magisk status on the handheld](docs/images/kpa-current-screen.png)

## Supported devices

KONKR Pocket Advance is the primary supported device. At community request, the project also provides an AYANEO Pocket AIR Mini `TEST` package so owners of that device can help validate it.

> [!WARNING]
> **The AIR Mini test package has not been tested on AIR Mini hardware for unlocking, Root flashing, restore, physical-button behavior, or module operation.** Only official factory packages, stock-boot hashes, OTA parameters, the incremental chain, and boot reconstruction have been checked offline. It is not verified production support; back up all data and keep the official full-flash package and recovery tools ready before testing.

| Device | Firmware and validation | Preinstalled modules |
| --- | --- | --- |
| KONKR Pocket Advance | Stock boot for 0730, 0813 and 0828; hardware-tested Root, restore preflight and automatic OTA patching | Font, RGB, Play Integrity Fork, Shamiko and Dolby Atmos |
| AYANEO Pocket AIR Mini | **Experimental; Root and restore have not been hardware-tested**. Stock boots for 1020, 1027, 1030, 1103, 1110 and 1125; OTA chain and images verified offline only | Play Integrity Fork and Shamiko (static compatibility review only) |

Root uses Magisk 30.7 with Zygisk. The host is Windows; ADB, Fastboot and the USB driver are included. Magisk boot is not bundled and is generated and verified from the matching stock boot during Root.

Before any change, the scripts verify the model, firmware, active slot, bootloader state, image size and SHA-256. Root and restore operations target only the active slot; the user never selects A or B manually.

## Before you start

- Use Windows 10 or Windows 11, keep the handheld charged, and maintain a stable USB connection.
- Back up all important data. Unlocking the bootloader normally erases user data.
- Open **Settings → System → Developer options**, enable **OEM unlocking** and **USB debugging**, and disable **Verify apps over USB**.
- Then open **Settings → Security**, disable **Google Play Protect**, connect the PC, and authorize USB debugging.
- AIR Mini testers should also prepare the official full-flash package. Stop immediately on an identity mismatch, failed verification, slot mismatch, or unknown state.

## Workflow

### 1. Unlock the bootloader

Complete the **Before you start** checklist above and keep the handheld unlocked with its screen visible.

Run `1_Unlock_EN.cmd`.

Unlocking normally erases all user data. Back up first.

### 2. Obtain Root

Run `2_Root_EN.cmd`.

Check the firmware version again before flashing.

The script always reuses and verifies an existing image first. Only when the current firmware image is missing, it queries and downloads official adjacent incremental OTAs, reconstructs the current stock boot from an earlier stock boot, and patches it with the bundled Magisk 30.7. After preflight and user confirmation, it flashes only the active slot, installs Magisk, enables Zygisk and verifies Root.

Automatic generation requires Internet access, a complete official incremental chain and a working ADB connection. OTA archives retain their server filenames under the matching `devices/<device>/ota/cache` directory. Existing stock boot images are never regenerated or overwritten.

Each device's `modules.psd1` controls its module allowlist. Pocket Advance uses all five modules. The AIR Mini test profile selects only Play Integrity Fork and Shamiko; the KPA-specific RGB, font and Dolby modules are not installed. The two selected modules have not been run on AIR Mini hardware.

Missing modules are installed with a Magisk `disable` marker, so they remain disabled by default. Existing installations are skipped without changing their state. Enable a module manually in Magisk and reboot when needed.

### Module notes

#### Dolby Atmos

Included only in the Pocket Advance module allowlist.

Upstream project：[Dolby Atmos Razer Phone 2](https://github.com/reiryuki/Dolby-Atmos-Razer-Phone2-Magisk-Module)

Fixes the graphical equalizer display in landscape.

Before use, go to **Settings → Sound → Sound enhancement** and enable **BesLoudness (speaker volume booster)**.

> Enabling Dolby changes the reported device identity to Razer Phone 2, which may affect vendor apps.

### 3. Restore stock boot

Run `3_Restore_EN.cmd`.

Restore also writes the boot partition and uses the same OTA reconstruction feature as the Root script. If the stock boot for the installed firmware is missing, it rebuilds that version step by step from an earlier stock boot and official adjacent incremental OTAs. Restore proceeds only after verification, so later normal OTA releases usually do not require a newly packaged KPA-Root toolkit.

Automatic reconstruction requires Internet access, a continuous official incremental chain and a working ADB connection. If the vendor changes the service or package format, or the chain is incomplete, the script stops without flashing.

The script restores the stock boot matching the current firmware and active slot. It can optionally relock the bootloader; relocking normally erases user data again.

> [!WARNING]
> Relocking the bootloader is not recommended. Restoring stock boot alone cannot prove that every other partition is official and unmodified. Relocking with a mismatched or modified partition may prevent the device from booting.

## OTA and later system updates

### Using KPA-Root scripts only

1. Before the OTA, run `3_Restore_EN.cmd` to restore the active slot's matching stock boot. Relocking the bootloader is not required.
2. Boot the stock system normally and install the official OTA.
3. After the first successful boot into the new firmware, run `2_Root_EN.cmd`.
4. The script detects the new build. If its boot is missing, it reconstructs it from an earlier stock boot and official adjacent incremental OTAs, then patches and flashes the current active slot.

Never flash a patched boot from an older firmware into a newer build.

### Using KPA Tools Root edition

The [KPA Tools Root edition](https://github.com/tbc0309/KPA-Tools/releases/latest) is recommended for KONKR Pocket Advance. KPA Root Helper restores the active slot's stock boot before System Update, then backs up, patches, and verifies the new slot after the official OTA while keeping the old slot on its matching stock boot. Restart only after the green **Ready to restart** notice appears on the System Update screen. This automated flow is not currently claimed as verified for AIR Mini.

![KPA Tools Root Manager](docs/images/kpa-tools-root-manager.png)

| Updating or patching: do not restart | Patch verified: restart allowed |
| --- | --- |
| ![OTA updating notice](docs/images/kpa-ota-updating.png) | ![OTA ready notice](docs/images/kpa-ota-ready.png) |

## Official Fastboot firmware

- 中文：[AYANEO 服务支持下载](https://ayaneo.com.cn/support/download)
- English: [AYANEO Support Download](https://www.ayaneo.com/support/download)

The download pages directly list the KONKR Pocket Advance flashing tools, instructions, and Fastboot ROM. The Chinese page includes the flashing-tool guide and 0730 package; the English page lists the 0730 Fastboot ROM.

> [!WARNING]
> The official download is an MTK Fastboot flashing package, not an in-system card-update OTA. It writes multiple partitions and may erase data. Follow the matching official tool and instructions exactly, and never disconnect USB while flashing.

### Flashing mode

Select **`Firmware Upgrade`** in SP Flash Tool. Do not use `Download Only` or `Format All + Download`.

![SP Flash Tool Firmware Upgrade](docs/images/sp-flash-tool-firmware-upgrade.png)

The official package provides the A-slot boot partitions. `Download Only` does not complete the required A/B slot transition for this package and may preserve the previously active slot, causing the handheld to return to Fastboot after flashing. If this happens, flash the package again with **`Firmware Upgrade`**. Manually forcing slot A is not part of the normal recovery procedure. The first boot may take 5–10 minutes; do not force the device off early.

An official line flash may leave equal A/B priorities in `misc`. KPA-Root does not use those priorities to select a flash target: it reads the slot currently running Android, then verifies Fastboot `current-slot` before allowing the operation to continue.

## Buttons and boot modes

The following boot-mode and physical-button flow is verified on **KONKR Pocket Advance**:

- While powered off, hold Power + `MODE` to open the boot-mode menu.
- Press `MODE` to cycle through `Recovery Mode`, `Fastboot Mode` and `Normal Mode`, then press `LC` to confirm.
- In Recovery, use the volume wheel to move up or down; `MODE` can also cycle through the choices. Press Power to confirm.
- Press Volume Up (`MODE` to the right of `L2`) to select `YES`.

For AIR Mini, the script displays **Press Volume Up to select `YES`**. Neither that prompt nor the physical-button behavior has been verified on AIR Mini hardware; follow the instructions shown by the device bootloader.

## Release builds

Font, RGB, Play Integrity Fork and Shamiko are downloaded from upstream stable releases. Dolby uses the pinned UI fix archive with SHA-256 verification. Building requires 7-Zip; running the toolkit does not.

- `build-release.ps1 -Version 1.1.0` creates the stable KONKR Pocket Advance-only archive.
- `scripts/Build-AirMiniTest.ps1 -Version 1.1.0` creates the AYANEO Pocket AIR Mini-only `TEST` archive and applies the profile-specific archive name and six launcher window titles automatically.

See [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) for the repository and device-profile layout.

Copyright © 2026 IMNKS.COM.

[IMNKS.COM](https://imnks.com/) · [GitHub](https://github.com/tbc0309)
