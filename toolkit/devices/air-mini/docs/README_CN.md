# AYANEO Pocket AIR Mini 测试说明

> [!WARNING]
> **这是尚未经过 AIR Mini 真机验证的 Root 测试功能。** 尚未完成真机 Bootloader 解锁、Root boot 刷写、原版 boot 恢复、实体按键及模块运行测试。请勿将其视为稳定版；测试前必须备份数据，并准备官方完整线刷包和恢复工具。

该配置仅匹配 `GT78-VN`、`BW02` 序列号前缀和 `MP40AY2` 系统版本。机型信息不完全匹配时，脚本会停止操作。

## 当前验证状态

已完成的离线检查：

- 两个官方完整线刷包及其中原版 boot 的哈希校验。
- 1020、1027、1030、1103、1110、1125 原版 boot 索引。
- 官方 OTA 请求参数和 `1020 → 1027 → 1030 → 1103 → 1110` 增量链。
- 从相邻增量 OTA 自动合成 boot 的流程及结果校验。

尚未完成的真机验证：

- Bootloader 解锁及解锁后的启动验证。
- Magisk 修补 boot 的实际刷写、启动和 Root 验证。
- `3_Restore` 恢复原版 boot、A/B 槽行为和 OTA 后续流程。
- 音量键确认方式，以及 Play Integrity Fork、Shamiko 的实际运行。

## 测试前准备

1. 备份全部用户数据并确保电量充足。
2. 准备对应版本的官方完整线刷包、SP Flash Tool 和恢复教程。
3. 进入“设置 → 系统 → 开发者选项”，开启 OEM 解锁和 USB 调试，同时关闭“通过 USB 验证应用”。
4. 进入“设置 → 安全”，关闭“Google Play 保护机制”。
5. 使用可靠数据线连接电脑，并在掌机上允许 USB 调试。

## 使用顺序

1. 首次使用运行 `1_Unlock_CN.cmd`；已确认解锁时跳过。
2. 解锁并重新进入系统后，再次完成开发者选项和 USB 调试设置。
3. 运行 `2_Root_CN.cmd`，核对机型、系统版本、活动槽和目标镜像。
4. 只有明确输入 `YES` 才会开始涉及解锁、写入或重启的危险操作。
5. 如需恢复原版 boot 或准备官方 OTA，先运行 `3_Restore_CN.cmd`。

脚本针对 AIR Mini 仅显示“按音量+选择 `YES`”。这一按键提示尚未经过 AIR Mini 真机确认，应以掌机 Bootloader 屏幕显示为准。

## 镜像与模块

Root 时会根据当前系统现场生成并校验 Magisk boot，不携带预制修补镜像。包内只提供 Play Integrity Fork 和 Shamiko，安装后默认停用；不包含 Pocket Advance 专用的字体、RGB 和杜比模块。

上述两个模块只完成了静态兼容性审查，尚未在 AIR Mini 实机运行。详细依据见 [`MODULE_COMPATIBILITY_CN.md`](MODULE_COMPATIBILITY_CN.md)。

## 必须停止的情况

如脚本报告机型不支持、身份不唯一、镜像校验失败、Bootloader 状态异常、活动槽不一致或未知状态，请停止操作并保留日志，不要绕过检查或强制刷写。
