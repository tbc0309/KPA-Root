# KONKR Pocket Advance Root 工具包

[English](README_EN.md) | [简体中文](README_CN.md)

> [!WARNING]
> `BW03_20260730` 和 `BW03_20260828` 已完成 KPA-Root 直接刷写验证；同一台实机还连续完成了 `0730 → 0813`、`0813 → 0828` 两次官方 OTA 自动修补闭环。刷写仍可能造成无法启动、数据丢失或设备损坏，请自行承担风险。

## 支持设备

- 型号：`GT78-VN`
- 主板：`k85v1_64`
- 固件：内置 `BW03_20260730`、`BW03_20260813`、`BW03_20260828` 原版及 Magisk 30.7 修补 boot，已知版本无需下载 OTA，并支持从官方连续增量 OTA 自动生成后续版本 boot
- Root 方案：Magisk 30.7 + Zygisk

脚本显示设备、固件、锁状态及目标分区，自动选择活动槽并校验镜像。未知设备或不匹配的固件不会刷写。

## 1. 解锁 Bootloader

运行 `1_Unlock_CN.cmd`。解锁通常会清除全部用户数据，请先备份。

输入 `YES` 后进入 Fastboot 核对真实锁状态；已经解锁时不发送解锁命令并自动重启。确认仍为锁定状态后，再次输入 `YES` 才执行解锁。命令可能立即清除数据；如掌机出现确认界面，按音量+ / YES。

## 2. 获取 Root

运行 `2_Root_CN.cmd`。脚本自动识别当前固件，优先校验并复用已有镜像，只刷当前活动槽，不修改另一槽。

镜像缺失时，脚本查询官方 OTA，保留服务器原始文件名并下载到当前机型的 `ota/cache`，再从已有原版 boot 逐个应用相邻增量包，生成当前版本原版 boot 和 Magisk 30.7 修补 boot。没有连续的官方增量链时会停止，不会刷写。已有原版镜像不会覆盖。

自动生成的新版本未经实机验证。即使合成和校验成功，仍可能因固件启动链变化而无法启动。

开始刷写前请再次核对预检中的机型、固件版本、活动槽和目标镜像。

设备检查通过后输入 `YES` 才会进入 Fastboot；Fastboot 再次验证通过后，再输入一次 `YES` 才会刷写。Android 启动后，脚本安装 Magisk、开启 Zygisk、安装模块并重启验证。后续需要等待用户完成 Magisk 设置时，也统一输入 `YES` 继续。

在掌机完成 Magisk 额外设置及所需重启，再回电脑继续。Shell 请求超级用户权限时点击“允许”；没有弹窗时，进入 Magisk → 超级用户，允许 Shell。

安装后及重启后检查管理器版本。缺失、占位版或旧版自动修复一次，保留更高版本；修复失败则停止。

如果已经 Root，摘要会显示 Magisk Core、Magisk 管理器、工具包版本、Zygisk 设置和进程状态，并提供以下选择：

- `[1]` 不刷 boot，仅更新或修复管理器并开启 Zygisk。
- `[2]` 强制重新刷写匹配的 Root boot。
- `[0]` 安全退出。

更新 APK 不会升级 Magisk Core；如果核心版本低于工具包版本，应选择 `[2]`。

### 内置模块

内置 `KPA MYuppy Font`、`KPA RGB Control`、`Play Integrity Fork`、`Shamiko` 和 `Dolby Atmos Razer Phone 2`（横屏图形均衡器修复版）。新安装的模块默认停用，已有模块保留原状态。在 Magisk 中启用并重启后生效。

### Dolby Atmos

原项目：[Dolby Atmos Razer Phone 2](https://github.com/reiryuki/Dolby-Atmos-Razer-Phone2-Magisk-Module)

修复横屏图形均衡器显示。

使用前，请进入 **设置 → 声音 → 音效改善**，开启 **BesLoudness（喇叭音量助推器）**。

> 启用 Dolby 后，系统机型信息会显示为 Razer Phone 2，可能影响厂商应用。

Play Integrity Fork 和 Shamiko 不自动配置隐藏列表，也不保证通过 Play Integrity。

## 3. OTA 前恢复

安装 OTA 前运行 `3_Restore_CN.cmd`。脚本识别当前固件，只向活动槽恢复匹配的原版 boot。每次确认统一输入 `YES`，不需要选择槽位。

恢复脚本同样会写入 boot 分区，并与 Root 脚本共用 OTA 合成功能。当前固件缺少原版 boot 时，脚本会从已有的较早原版 boot 和官方相邻增量 OTA 逐版合成当前版本，校验成功后才允许恢复，因此后续正常 OTA 通常不需要重新下载新版工具包。

自动合成需要联网、有效的官方连续增量链和正常的 ADB 连接；如果官方更改接口或包格式、增量链不完整，脚本会停止且不会刷写。

恢复后先确认 Android 正常启动，再检查并安装 OTA。OTA 在新槽正常启动后，再次运行 Root 脚本；缺少对应镜像时会自动合成并修补新版本 boot。不要把旧版本修补 boot 刷入新版本系统。

建议配合 [KPA助手 Root 版](https://github.com/tbc0309/KPA-Tools/releases/latest) 使用。其 KPA Root Helper 可自动完成 OTA 前恢复、更新后新槽修补与校验，并保留旧槽对应版本的原版 boot。系统更新页显示绿色“可以重启”后再重启。

已完成实机验证：KPA-Root 的 0730、0828 Root；KPA Root Helper 的 0730→0813、0813→0828 官方 OTA 闭环。

恢复菜单：

- `[1]` 恢复原版 boot，完成后可选择加锁。
- `[2]` 仅加锁，不刷写镜像。

已加锁时直接退出。当前 boot 的 SHA256 与原版一致时跳过恢复；无法读取分区时显示“未知”。没有 Root 权限不能证明 boot 是原版。

加锁前必须确认所有分区均为匹配的官方原版，并按提示两次输入 `YES`。命令可能立即清除数据；重启后需重新初始化。

> [!WARNING]
> 不建议重新锁定 Bootloader。恢复原版 boot 并不能证明其他分区均为官方原版；如果存在不匹配或已修改分区，重新锁定可能导致设备无法启动。

原版镜像对应关系：

- `boot_0730_stock.img` → `BW03_20260730`
- `boot_0813_stock.img` → `BW03_20260813`
- `boot_0828_stock.img` → `BW03_20260828`

严禁混用不同固件版本的原版或修补 boot。

## 官方线刷包下载

- 中文：[AYANEO 服务支持下载](https://ayaneo.com.cn/support/download)
- English: [AYANEO Support Download](https://www.ayaneo.com/support/download)

打开页面即可看到 KONKR Pocket Advance 线刷工具、教程和 Fastboot ROM。中文页列出线刷工具教程和 0730 线刷包；英文页列出 0730 Fastboot ROM。

> [!WARNING]
> 这是 MTK Fastboot 线刷包，不是系统内卡刷 OTA。它会写入多个分区并可能清除数据，必须严格使用官网配套工具和教程；刷写期间不要断开 USB。

SP Flash Tool 必须选择 **`Firmware Upgrade`**，不要使用 `Download Only`，也不要使用 `Format All + Download`。官方固件只提供 A 槽启动分区镜像；使用 `Download Only` 可能保留刷机前的活动槽状态，造成刷完持续进入 Fastboot。出现这种情况时，应改用 **`Firmware Upgrade`** 重新完整线刷，不把手动切换 A 槽作为正式恢复流程。首次启动可能需要 5～10 分钟。

## 按键与启动模式

- 关机状态下同时按住“开机键 + MODE”，进入启动模式菜单。
- 使用 `MODE` 在 `Recovery Mode`、`Fastboot Mode` 和 `Normal Mode` 之间循环选择。
- 按 `LC` 确认启动模式。
- 进入 Recovery 后，使用音量滚轮上下选择；也可以按 `MODE` 循环选择。
- Recovery 中按开机键确认。
- Fastboot 出现确认界面时，按音量+（`L2` 右侧 `MODE`）选择 `YES`。

## 运行条件

1. 电量不少于 50%。
2. 进入“设置 → 系统 → 开发者选项”，开启 OEM 解锁和 USB 调试，同时关闭“通过 USB 验证应用”；再进入“设置 → 安全”，关闭“Google Play 保护机制”，并授权本电脑。
3. 使用可传输数据的 USB 线，只连接一台安卓设备；刷写流程不会使用无线 ADB。
4. 工具包已内置 ADB、Fastboot 和签名 Android USB 驱动。脚本按“检查工具 → 安装驱动 → 等待 USB 调试授权 → 设备预检”的顺序引导，无需预装。
5. 等待 ADB、Fastboot、Android 启动和 Root 授权时都会定期显示状态；超时可选择继续等待或安全退出。设备未授权、离线或同时连接多台设备时不会继续刷写。
6. 镜像刷写过程中不要断开 USB。

每个脚本都会在当前文件夹生成带时间戳的日志。
