# KPA Root

[English](README.en.md) | [简体中文](README.md)

Bootloader unlock, Root and restore toolkit for KONKR Pocket Advance.

Chinese and English documentation and launchers are available.

![Android home screen](docs/images/kpa-android-home.png)

![Magisk status on the handheld](docs/images/kpa-current-screen.png)

> [!WARNING]
> Only `BW03_20260828` has been tested on the current device. `BW03_20260730` and `BW03_20260813` have not been tested on hardware. Flashing may cause boot failure, data loss or device damage. No safety guarantee is provided; proceed at your own risk.

## Supported devices

- Model: `GT78-VN`
- Board: `k85v1_64`
- Firmware: `BW03_20260730`, `BW03_20260813`, `BW03_20260828`
- Root: Magisk 30.7 with Zygisk
- Host: Windows; ADB and Fastboot are included

Before any change, the scripts verify the model, firmware, active slot, bootloader state, image size and SHA-256. Root and restore operations target only the active slot; the user never selects A or B manually.

## Buttons and boot modes

- While powered off, hold Power + `MODE` to open the boot-mode menu.
- Press `MODE` to cycle through `Recovery Mode`, `Fastboot Mode` and `Normal Mode`, then press `LC` to confirm.
- In Recovery, use the volume wheel to move up or down; `MODE` can also cycle through the choices. Press Power to confirm.
- Fastboot Volume Up / YES corresponds to the `MODE` button to the right of `L2`.

## Workflow

### 1. Unlock the bootloader

Run `1_Unlock_EN.cmd`.

Unlocking normally erases all user data. Back up first.

### 2. Obtain Root

Run `2_Root_EN.cmd`.

Check the firmware version again before flashing. The 0730 and 0813 images have not been tested on hardware and are not guaranteed to boot or recover correctly.

The script matches the 0730, 0813 or 0828 Magisk boot, flashes only the active slot, installs Magisk, enables Zygisk and verifies Root.

The package also includes:

- KPA MYuppy Font
- KPA RGB Control
- Play Integrity Fork
- Shamiko
- Dolby Atmos Razer Phone 2 (landscape graphical equalizer fix)

Missing modules are installed with a Magisk `disable` marker, so they remain disabled by default. Existing installations are skipped without changing their state. Enable a module manually in Magisk and reboot when needed.

### Dolby Atmos

Fixes the graphical equalizer display in landscape.

Before use, go to **Settings → Sound → Sound enhancement** and enable **BesLoudness (speaker volume booster)**.

> Enabling Dolby changes the reported device identity to Razer Phone 2, which may affect vendor apps.

### 3. Restore stock boot

Run `3_Restore_EN.cmd`.

Restore also writes the boot partition. The 0730 and 0813 restore paths have not been tested on hardware; an incorrect image or version may prevent the device from booting.

The script restores the stock boot matching the current firmware and active slot. It can optionally relock the bootloader; relocking normally erases user data again.

> [!WARNING]
> Relocking the bootloader is not recommended. Restoring stock boot alone cannot prove that every other partition is official and unmodified. Relocking with a mismatched or modified partition may prevent the device from booting.

## OTA warning

Restore the matching stock boot before every OTA. After the OTA, confirm the new firmware version and use a patched boot built for that version. Never flash an older boot into a newer firmware build.

## Official firmware

- [Official download page](https://www.ayaneo.com/support/download)

On the page, select “Android Console”, then “KONKR Pocket ADVANCE”.

> [!WARNING]
> Treat the package currently provided by the official site as a card-update package, not a verified full line-flash recovery package. A card update may not overwrite every low-level partition and is not guaranteed to restore the complete factory state. Do not rely on it as an unbrick package when Android and Recovery are inaccessible.

## Release builds

Font, RGB, Play Integrity Fork and Shamiko are downloaded from upstream stable releases. Dolby uses the pinned UI fix archive with SHA-256 verification. Building requires 7-Zip; running the toolkit does not.

See [`toolkit/README_EN.md`](toolkit/README_EN.md) for the complete English guide.

Copyright © 2026 IMNKS.COM.

[IMNKS.COM](https://imnks.com/) · [GitHub](https://github.com/tbc0309)
