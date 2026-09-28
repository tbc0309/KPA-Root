## 中文

同步最新版中文、英文解锁、Root 与恢复脚本，并更新 KPA助手 Root 管理和 OTA 状态实机截图。

完善 A/B 槽安全检查：线刷后即使 `misc` 中两槽优先级相同，也以 Android 实际运行槽为来源，并在 Fastboot 中再次核对 `current-slot`，不会依据不明确的优先级猜测刷写目标。

工具包可在缺少 boot 时，通过官方相邻增量 OTA 合成当前版本原版 boot，再使用 Magisk 30.7 自动修补。已有镜像优先复用且不会覆盖；内置五个默认停用的 Magisk 模块。

## English

Synchronized the latest Chinese and English unlock, Root, and restore scripts, and refreshed the hardware screenshots for KPA Tools Root Manager and OTA status notices.

Hardened A/B slot validation. Even when a line flash leaves equal priorities in `misc`, the toolkit uses the slot currently running Android and verifies Fastboot `current-slot` instead of guessing from ambiguous priority metadata.

When a boot image is missing, the toolkit can reconstruct its stock boot through official adjacent incremental OTAs and patch it with Magisk 30.7. Existing images are reused without being overwritten. Five Magisk modules are included and disabled by default.
