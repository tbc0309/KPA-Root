# AYANEO Pocket AIR Mini module compatibility

> [!WARNING]
> This table is a static compatibility review only. No listed module has been installed or run on AIR Mini hardware through this toolkit.

This experimental profile uses an explicit module allowlist. New modules are installed disabled and must be enabled manually in Magisk only after the tester accepts the risk.

| Module | Preinstall | Review result |
| --- | --- | --- |
| Play Integrity Fork | Yes | Declares Android 7+ support. Android 11 / API 30 and arm64 meet its requirements. Requires Zygisk for its normal mode. |
| Shamiko | Yes | Declares Android 8.1+ and Magisk 27005+ support. The toolkit bundles Magisk 30.7. Requires Zygisk. |
| KPA MYuppy Font | No | Replaces the complete Android 12 `fonts.xml`, not only font files. AIR Mini uses Android 11; a profile-specific font map must be built and tested first. |
| KPA RGB Control | No | Uses KONKR-specific RGB LED nodes, thermal-zone indices and AYAHOME performance-mode behavior. |
| Dolby Atmos Razer Phone 2 | No | Changes audio libraries/configuration, VINTF, SELinux policy, Dolby services/apps and audio databases. AIR Mini has a different Android 11 audio stack and built-in MTK audio enhancements. |
| KPA Touch Guard | No | Not part of the KPA Root bundle. It also depends on the KONKR touch device name and MODE input event, which have not been verified on AIR Mini. |

The allowlist is stored in `modules.psd1`. This prevents hardware- or OS-specific modules from being installed merely because two devices share the same SoC or board identifiers.
