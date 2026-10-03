# Device profiles

Each supported model uses a short folder name that matches `Id` in `device.psd1`.

| Folder | Device | Validation status |
| --- | --- | --- |
| `pocket-advance` | KONKR Pocket Advance | Hardware-tested Root, restore preflight, and two consecutive official OTA patching cycles |
| `air-mini` | AYANEO Pocket AIR Mini | **Experimental; offline image and OTA validation only, with no AIR Mini hardware Root/restore test** |
| `template` | New-device example | Configuration template only |

> [!WARNING]
> The presence of a device profile does not by itself mean production-ready hardware support. Read the profile's `docs/` directory and its validation status before any unlock or flash operation.

Runtime profile contents:

- `device.psd1`: identity matching, Fastboot product rule, boot size and image directory.
- `PackageName` and `LauncherTitle` in `device.psd1`: per-device archive name and CMD window-title prefix used by single-device builds.
- `firmware.psd1`: supported firmware versions and verified stock boot hashes.
- `ota.psd1`: model-specific official OTA request parameters.
- `modules.psd1`: explicit preinstall module allowlist; an empty list is valid.
- `images/`: verified stock and Magisk 30.7 patched boot images and checksums for catalog builds. Future builds are generated on demand.
- `ota/`: model-specific OTA cache and generated image indexes when required.
- `docs/`: model-specific Chinese and English instructions.

Shared scripts identify a profile with model, device, board, serial number and build ID. A device must match exactly one profile before any Fastboot operation is allowed. `PreinstallModules` is an explicit per-model allowlist; sharing a chipset does not imply module compatibility.

When adding a model, do not weaken another model's matching rules and do not share boot images or hashes between profiles.
