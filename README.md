# KPA Root

[English](README.en.md) | [简体中文](README.md)

面向 **KONKR Pocket Advance（KPA）** 的 Bootloader 解锁、Root、原版 boot 恢复和官方 OTA 后续修补工具包，提供中文与英文文档及启动脚本。

KPA 已完成多个固件版本的实机 Root、恢复预检以及两次连续官方 OTA 自动修补验证。工具会在操作前核对机型、固件、活动槽、Bootloader 状态和镜像哈希，缺少当前版本原版 boot 时还可通过官方相邻增量 OTA 自动合成。

> [!CAUTION]
> 本工具支持从官方增量 OTA 自动合成并修补 boot，通常可直接用于后续官方系统版本，无需等待工具包更新。发现新 OTA 时，先运行 `3_Restore_CN.cmd` 恢复当前系统的原版 boot，完成官方 OTA 更新后，再运行 `2_Root_CN.cmd` 为新系统恢复 Root。更推荐配合 **KPA 助手 Root 版**使用：OTA 前在 Root 管理中点击“准备 OTA”，待提示准备完成后正常安装官方 OTA，KPA Root Helper 会自动完成后续 Root 修补与校验。

> [!WARNING]
> `BW03_20260730` 和 `BW03_20260828` 已完成 KPA-Root 直接刷写验证；同一台实机还连续完成了 `0730 → 0813`、`0813 → 0828` 两次官方 OTA 自动修补闭环。任何 boot 写入仍可能导致无法启动、数据丢失或设备损坏，请自行承担风险。

![安卓桌面首页](docs/images/kpa-android-home.png)

![掌机 Magisk 状态](docs/images/kpa-current-screen.png)

## 支持范围

KONKR Pocket Advance 是本项目的主要支持机型。应网友需求，项目另行提供 AYANEO Pocket AIR Mini `TEST` 测试包，便于有对应设备的用户协助验证。

> [!WARNING]
> **AIR Mini 测试包尚未进行真机解锁、Root 刷写、恢复、实体按键或模块运行测试。** 当前只完成官方线刷包、原版 boot 哈希、OTA 参数、增量链和 boot 合成流程的离线校验。它不属于已经验证的正式支持；测试前必须备份数据并准备官方完整线刷包与恢复工具。

| 机型 | 固件与验证状态 | 预装模块 |
| --- | --- | --- |
| KONKR Pocket Advance | 内置 0730、0813、0828 原版 boot；已完成 Root、恢复预检和 OTA 自动修补实机验证 | 字体、RGB、Play Integrity Fork、Shamiko、Dolby Atmos |
| AYANEO Pocket AIR Mini | **测试功能，未进行真机 Root/恢复验证**；内置 1020、1027、1030、1103、1110、1125 原版 boot，OTA 链和镜像仅完成离线校验 | Play Integrity Fork、Shamiko（仅完成静态兼容性审查） |

Root 使用 Magisk 30.7 + Zygisk。运行环境为 Windows，ADB、Fastboot 和 USB 驱动均已包含。Magisk boot 不预置，在 Root 时从对应原版 boot 自动生成并校验。

脚本会在操作前检查设备型号、固件版本、活动槽、Bootloader 状态、镜像大小和 SHA-256。Root 与恢复只处理当前活动槽，用户不需要手动选择 A/B 槽。

## 开始前准备

- 使用 Windows 10 或 Windows 11，并保持掌机电量充足、USB 连接稳定。
- 备份全部重要数据；解锁 Bootloader 通常会清除用户数据。
- 掌机进入“设置 → 系统 → 开发者选项”，开启 OEM 解锁和 USB 调试，同时关闭“通过 USB 验证应用”。
- 再进入“设置 → 安全”，关闭“Google Play 保护机制”，并在连接电脑后允许 USB 调试。
- AIR Mini 测试者还应提前准备官方完整线刷包；出现身份不匹配、校验失败、槽位不一致或未知状态时立即停止。

## 使用顺序

### 1. 解锁 Bootloader

确认已经完成上面的“开始前准备”，并保持掌机解锁、屏幕可见。

运行：

- `1_Unlock_CN.cmd`

解锁通常会清除全部用户数据，请先备份。

### 2. 获取 Root

运行：

- `2_Root_CN.cmd`

刷写前请再次确认固件版本。

脚本优先使用并校验已有镜像。当前固件缺少镜像时，才会查询和下载官方相邻增量 OTA，从已有原版 boot 逐版合成当前版本原版 boot，再用随包 Magisk 30.7 自动修补。完成预检和用户确认后，只刷入当前活动槽；随后安装 Magisk、开启 Zygisk，并验证 Root 状态。

自动生成需要联网、有效的官方连续增量链以及正常的 ADB 连接。OTA 保留服务器原始文件名并缓存在对应机型的 `devices/<机型>/ota/cache`。已有原版 boot 不会被重新生成或覆盖。

预装模块由各机型的 `modules.psd1` 白名单决定。Pocket Advance 使用五个模块；AIR Mini 测试配置只选择 Play Integrity Fork 和 Shamiko，不会安装 KPA 专用的 RGB、字体或 Dolby 模块。AIR Mini 上的两个模块尚未经过真机运行验证。

缺失模块会自动安装，但默认写入 Magisk `disable` 标记，不会自动启用。已有模块会直接跳过，其启用状态不会改变。需要使用时，在 Magisk 中手动启用并重启。

### 模块说明

#### Dolby Atmos

仅列入 Pocket Advance 的模块白名单。

原项目：[Dolby Atmos Razer Phone 2](https://github.com/reiryuki/Dolby-Atmos-Razer-Phone2-Magisk-Module)

修复横屏图形均衡器显示。

使用前，请进入 **设置 → 声音 → 音效改善**，开启 **BesLoudness（喇叭音量助推器）**。

> 启用 Dolby 后，系统机型信息会显示为 Razer Phone 2，可能影响厂商应用。

### 3. 恢复原版 boot

运行：

- `3_Restore_CN.cmd`

恢复脚本同样会写入 boot 分区，并与 Root 脚本共用 OTA 合成功能。当前固件缺少原版 boot 时，脚本会从已有的较早原版 boot 和官方相邻增量 OTA 逐版合成当前版本，校验成功后才允许恢复，因此后续正常 OTA 通常不需要重新下载新版 KPA-Root 工具包。

自动合成需要联网、有效的官方连续增量链和正常的 ADB 连接；如果官方更改接口或包格式、增量链不完整，脚本会停止且不会刷写。

脚本恢复当前固件和活动槽对应的原版 boot。完成后可选择是否重新锁定 Bootloader；锁定通常会再次清除数据。

> [!WARNING]
> 不建议重新锁定 Bootloader。即使已经恢复原版 boot，也无法仅凭本工具确认其他分区全部为官方原版；锁定状态下若存在不匹配或已修改分区，可能导致设备无法启动。

## OTA 与后续系统更新

### 仅使用 KPA-Root 脚本

1. OTA 前运行 `3_Restore_CN.cmd`，恢复当前活动槽对应版本的原版 boot；不需要重新锁定 Bootloader。
2. 原版系统正常启动后安装官方 OTA。
3. OTA 完成并首次进入新系统后，运行 `2_Root_CN.cmd`。
4. 脚本会识别新固件；缺少对应 boot 时，从已有原版 boot 和官方相邻增量 OTA 自动合成，再修补并刷入当前活动槽。

不要把旧版本的修补 boot 刷入新版本系统。

### 配合 KPA助手 Root 版

KONKR Pocket Advance 建议安装 [KPA助手 Root 版](https://github.com/tbc0309/KPA-Tools/releases/latest)。KPA Root Helper 可在系统更新前恢复活动槽原版 boot，并在官方 OTA 完成后自动备份、修补和校验新槽，同时把旧槽保留为对应版本的原版 boot。系统更新页面显示绿色“可以重启”提醒后才能重启。该自动流程目前不作为 AIR Mini 的已验证功能。

![KPA助手 Root 管理](docs/images/kpa-tools-root-manager.png)

| 更新或修补中：不要重启 | 修补完成：可以重启 |
| --- | --- |
| ![OTA 更新中提醒](docs/images/kpa-ota-updating.png) | ![OTA 修补完成提醒](docs/images/kpa-ota-ready.png) |

## 官方线刷包

- 中文：[AYANEO 服务支持下载](https://ayaneo.com.cn/support/download)
- English: [AYANEO Support Download](https://www.ayaneo.com/support/download)

打开下载页即可看到 KONKR Pocket Advance 的线刷工具、教程和 Fastboot ROM。中文页同时列出线刷工具教程与 0730 线刷包；英文页列出 0730 Fastboot ROM。

> [!WARNING]
> 官方下载的是 MTK Fastboot 线刷包，不是 Android 系统内的卡刷 OTA。线刷会改写多个分区并可能清除数据；必须严格使用官网配套工具与教程，刷写期间不要断开 USB。

### 线刷模式提醒

SP Flash Tool 必须选择 **`Firmware Upgrade`**，不要使用 `Download Only`，也不要使用 `Format All + Download`。

![SP Flash Tool Firmware Upgrade](docs/images/sp-flash-tool-firmware-upgrade.png)

官方固件只提供 A 槽启动分区镜像；`Download Only` 不会正确完成这套固件所需的 A/B 槽切换处理，可能保留刷机前的活动槽状态，导致线刷完成后持续进入 Fastboot。遇到此情况应重新选择 **`Firmware Upgrade`** 完整线刷，不把手动切换 A 槽作为正式恢复流程。首次启动可能需要 5～10 分钟，请勿提前强制关机。

线刷后 `misc` 中的 A/B 优先级可能相同。KPA-Root 不依赖该优先级选择刷写槽：脚本先读取 Android 当前实际运行槽，进入 Fastboot 后再核对 `current-slot`，两者一致才允许继续。

## 按键与启动模式

以下启动模式和实体按键流程已在 **KONKR Pocket Advance** 上验证：

- 关机状态下同时按住“开机键 + MODE”，进入启动模式菜单。
- 使用 `MODE` 在 `Recovery Mode`、`Fastboot Mode` 和 `Normal Mode` 之间循环选择，按 `LC` 确认。
- 进入 Recovery 后，使用音量滚轮上下选择；也可以按 `MODE` 循环选择。按开机键确认。
- 按音量+（`L2` 右侧 `MODE`）选择 `YES`。

AIR Mini 脚本仅显示“按音量+选择 `YES`”；该提示及实际按键行为尚未经过 AIR Mini 真机验证，请以设备屏幕上的 Bootloader 提示为准。

## 构建发布包

字体、RGB、Play Integrity Fork 和 Shamiko 从上游正式发布下载；Dolby 使用仓库内固定的修复包并校验 SHA-256。构建需安装 7-Zip，运行工具包不需要。

- `build-release.ps1 -Version 1.1.0`：生成只包含 KONKR Pocket Advance 的正式包。
- `scripts/Build-AirMiniTest.ps1 -Version 1.1.0`：生成只包含 AYANEO Pocket AIR Mini 的 `TEST` 包，并按照机型参数自动设置压缩包名称和六个启动窗口标题。

项目结构与机型配置说明见 [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md)。

Copyright © 2026 我不是矿神。

[IMNKS.COM](https://imnks.com/) · [GitHub](https://github.com/tbc0309)
