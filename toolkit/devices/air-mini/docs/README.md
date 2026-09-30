# AYANEO Pocket AIR Mini

> [!WARNING]
> **This is an experimental Root profile with no AIR Mini hardware validation.** Bootloader unlock, patched-boot flashing and booting, stock-boot restore, physical-button behavior, A/B OTA handling, and module operation have not been tested on an AIR Mini. Back up all data and keep the matching official full-flash package and recovery tools ready before testing.

This test profile was derived from official `MP40AY2` factory images and the bundled `com.ayaneo.update` OTA client. It matches `GT78-VN`, serial prefix `BW02`, and build prefix `MP40AY2`; the scripts stop if identity matching is incomplete or ambiguous.

## Validation status

Verified offline:

- Official 2025-10-20 and 2025-11-25 full-flash packages and stock-boot hashes.
- Stock-boot indexes for 1020, 1027, 1030, 1103, 1110, and 1125.
- Official OTA request parameters and the adjacent incremental chain through 1110.
- Boot reconstruction through official adjacent incremental OTAs.

Not verified on AIR Mini hardware:

- Bootloader unlock and post-unlock boot.
- Magisk-patched boot flashing, booting, and Root verification.
- Stock-boot restore, A/B behavior, and subsequent OTA handling.
- Physical confirmation buttons and module runtime behavior.

## Device profile

- Hardware platform: MediaTek MT6785 / `k85v1_64`
- Android: 11 / API 30
- Product identifiers: `GT78-VN`, serial prefix `BW02`, build prefix `MP40AY2`
- Boot partition: A/B, 32 MiB
- Display: 1280 × 960
- Official factory baselines: 2025-10-20 and 2025-11-25

## Test workflow

1. Back up all user data and prepare the matching official full-flash package and recovery tools.
2. In **Settings → System → Developer options**, enable **OEM unlocking** and **USB debugging**, and disable **Verify apps over USB**.
3. In **Settings → Security**, disable **Google Play Protect**, then connect the PC and authorize USB debugging.
4. Run `1_Unlock_EN.cmd` only when unlocking is required. Unlocking normally erases user data.
5. After Android starts again and USB debugging is re-enabled, run `2_Root_EN.cmd` and verify every displayed identity, build, slot, and image value.
6. Run `3_Restore_EN.cmd` before restoring stock boot or preparing an official OTA.

The AIR Mini prompt says **Press Volume Up to select `YES`**, but this physical-button behavior is not hardware-verified. Follow the bootloader screen. Stop on any unsupported identity, ambiguous match, failed hash, unexpected lock state, slot mismatch, or unknown state.

## OTA chain

The official server returned the following incremental chain. All downloaded archives passed their advertised size, MD5 and SHA-256 checks before boot reconstruction:

`20251020 → 20251027 → 20251030 → 20251103 → 20251110`

The server returned no later incremental package after `20251110`. The `20251125` stock boot therefore comes directly from the later official full-flash package; it was not synthesized from the `20251110` boot.

All six stock boot images are stored in `images/`. Magisk hashes remain empty until the images are patched by the bundled Magisk 30.7 pipeline on an Android patch host; a Windows-only patcher was deliberately not accepted as equivalent without matching the known KPA reference output.

The KPA and Pocket AIR Mini share board-level identifiers. Device selection must therefore also validate the serial and build prefixes; board/model alone are not unique.

## Modules

The test allowlist selects only Play Integrity Fork and Shamiko. Both are installed disabled by default, and neither has been run on AIR Mini hardware. KPA-specific font, RGB, and Dolby modules are excluded. See [`MODULE_COMPATIBILITY.md`](MODULE_COMPATIBILITY.md) for the static review or [`MODULE_COMPATIBILITY_CN.md`](MODULE_COMPATIBILITY_CN.md) for Chinese.
