# Boot reconstruction comparison

> [!WARNING]
> These results are offline image comparisons for the experimental AIR Mini profile. They do not verify that any reconstructed or patched boot has been flashed or booted on AIR Mini hardware.

## Source verification

The `boot.img` extracted from the supplied `MP40AY2-20251020-251020_1536.zip` is byte-identical to `images/boot_1020_stock.img`:

`2EBDD31A58B59D1D139EDC1BDF6D998B5A3ED309CBDE4211775C73D1FF666216`

Starting with that image, the verified official incremental chain reconstructs:

`1020 → 1027 → 1030 → 1103 → 1110`

The OTA server returns no `1110 → 1125` package for the supplied serial. Consequently, `1125` cannot be reconstructed from the available official incremental chain and is retained from the official 2025-11-25 full-flash package.

## Reconstructed 1110 versus factory 1125

Both images are valid 32 MiB Android boot v2 images with a 2048-byte page size and the same encoded OS/security-patch field.

| Component | 1110 | 1125 | Result |
| --- | --- | --- | --- |
| Kernel | 9,673,715 bytes | 9,677,999 bytes | Changed |
| Ramdisk | 8,603,861 bytes | 8,603,806 bytes | Changed |
| DTB | 138,966 bytes | 138,966 bytes | Identical |
| Second / recovery DTBO | Empty | Empty | Identical |

The decompressed ramdisks contain the same file set. Only three entries differ:

- `prop.default`: build dates, display version and FOTA version changed from 1110 to 1125.
- `sepolicy`: binary SELinux policy changed.
- `system/bin/recovery`: recovery executable changed.

The DTB is exactly identical, while the kernel payload is a genuinely different build. Therefore, the 1125 boot is not merely the reconstructed 1110 boot with its version text changed; using the official 1125 boot as its own baseline is correct.
