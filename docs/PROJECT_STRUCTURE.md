# Project structure

The repository separates release tooling, documentation, tests and the end-user toolkit. Device-specific values are data files; shared scripts contain no model IDs, firmware hashes or module choices.

> [!IMPORTANT]
> A profile directory records configuration and validation evidence; it is not automatically a declaration of hardware-tested support. `pocket-advance` is hardware-tested. `air-mini` is experimental and has only offline factory-image, boot-hash, OTA-chain, and reconstruction validation.

```text
assets/                 # reviewed fixed release assets
docs/                   # images, architecture and development notes
scripts/                # release dependency downloaders
tests/                  # automated regression tests
toolkit/
  1_Unlock_CN.cmd ... 3_Restore_EN.cmd
  scripts/           # entry scripts and shared program libraries
  packages/          # Magisk and optional modules
  tools/             # Android platform tools, USB driver and OTA extractor
  devices/
    pocket-advance/
      device.psd1       # identity, hardware rules and per-device release names
      firmware.psd1     # versions and verified stock hashes
      ota.psd1          # official OTA request parameters
      modules.psd1      # preinstall allowlist
      images/           # verified stock boot images and checksums
      ota/              # runtime OTA cache and generated-image indexes
      docs/             # device-specific bilingual documentation
    air-mini/
      device.psd1
      firmware.psd1
      ota.psd1
      modules.psd1
      images/
      ota/
      docs/
```

Folder names use short, stable model identifiers. To add another model, copy `toolkit/devices/template`, create the four `.psd1` parameter tables, add verified stock boot images and update the model documentation. Magisk boot images, logs and OTA caches are runtime output and are excluded from releases.

Each profile document must clearly separate:

1. Source material and offline validation.
2. Operations verified on real hardware.
3. Operations that remain experimental or untested.
4. Device-specific recovery requirements and stop conditions.
