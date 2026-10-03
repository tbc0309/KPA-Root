## 中文

本版本以 KONKR Pocket Advance 正式版为主，重新整理公共脚本和机型参数表。机型身份、固件、OTA、原版 boot 和预装模块均独立配置，工具包根目录只保留六个中英文 CMD 入口。

完善 A/B 槽安全检查：线刷后即使 `misc` 中两槽优先级相同，也以 Android 实际运行槽为来源，并在 Fastboot 中再次核对 `current-slot`，不会依据不明确的优先级猜测刷写目标。

KPA 包同步更新字体与 RGB 模块，支持 Magisk 更新检测。RGB 升级保留用户配置，优化后台状态采样、写入重试和退出关灯，同时保持默认灯效节奏。

工具包可在缺少 boot 时，通过官方相邻增量 OTA 合成当前版本原版 boot，再使用 Magisk 30.7 自动修补。已知版本的原版和 Magisk 30.7 修补 boot 均已内置：KPA 三个版本、AIR Mini 六个版本，避免已知版本因 OTA 下载失败而无法获取 Root 或恢复；未内置新版本仍需联网合成。预装模块由各机型白名单决定并默认停用。

应网友需求，本版本同时提供明确标注 `TEST` 的 AYANEO Pocket AIR Mini 测试包。两个包共用经过回归测试的公共安全流程，但机型识别、固件、OTA、镜像、模块白名单、窗口标题和发布名称相互独立。

> [!WARNING]
> AIR Mini 测试包目前只完成官方镜像、boot 哈希、OTA 参数、增量链和合成流程的离线校验，尚未进行 AIR Mini 真机解锁、Root、恢复、实体按键或模块运行测试，不属于已经验证的正式支持。

## English

This release focuses on the stable KONKR Pocket Advance package and reorganizes shared scripts and device parameter tables. Device identity, firmware, OTA data, stock boots, and module choices are independently configured, while the toolkit root contains only the six Chinese and English CMD launchers.

Hardened A/B slot validation. Even when a line flash leaves equal priorities in `misc`, the toolkit uses the slot currently running Android and verifies Fastboot `current-slot` instead of guessing from ambiguous priority metadata.

The KPA package includes updated font and RGB modules with Magisk update detection. RGB preserves user configuration on upgrade and improves background sampling, write retries and shutdown cleanup without changing the default effects.

When a boot image is missing, the toolkit can reconstruct its stock boot through official adjacent incremental OTAs and patch it with Magisk 30.7. Stock and Magisk 30.7 patched boots are bundled for all three known KPA builds and six AIR Mini builds, avoiding OTA downloads for those builds. Future unbundled builds still require Internet access for reconstruction. Each device has its own module allowlist, and newly installed modules remain disabled by default.

At community request, this release also provides an explicitly labeled AYANEO Pocket AIR Mini `TEST` package. Both archives use the same regression-tested shared safety flow while keeping identity rules, firmware, OTA parameters, images, module allowlists, launcher titles, and package names isolated per device.

> [!WARNING]
> The AIR Mini test package has only completed offline validation of official images, boot hashes, OTA parameters, the incremental chain, and reconstruction. Hardware unlock, Root, restore, physical-button behavior, and module operation remain untested, so this is not verified production support.
