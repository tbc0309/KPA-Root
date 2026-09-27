## 中文

新增缺失 boot 自动生成：从官方 OTA 相邻增量链合成当前版本原版 boot，并用 Magisk 30.7 自动修补。已有镜像始终优先复用且不会覆盖，下载保留服务器原始文件名。

提供中文、英文解锁、Root 和恢复脚本。内置 Magisk 及五个默认停用的模块。

**仅 0828 经过 Root 实机测试；0730、0813 及自动生成的后续版本未验证。自动合成成功不代表刷写安全。刷写可能导致数据丢失、无法启动或设备损坏。不建议重新锁定 Bootloader。**

## English

Added automatic generation for a missing boot image. The toolkit reconstructs the current stock boot through official adjacent incremental OTA packages and patches it with Magisk 30.7. Existing images are always reused and never overwritten; downloads retain their server filenames.

Includes Chinese and English unlock, Root and restore scripts, Magisk, and five modules installed disabled by default.

**Only 0828 Root has been tested on hardware. 0730, 0813 and automatically generated later builds are unverified. Successful reconstruction does not make flashing safe. Flashing may cause data loss, boot failure or device damage. Bootloader relocking is not recommended.**
