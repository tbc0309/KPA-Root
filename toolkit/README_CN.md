# KONKR Pocket Advance Root 工具包

[English](README_EN.md) | [简体中文](README_CN.md)

> [!WARNING]
> 目前仅 `BW03_20260828` 在当前这台机器上完成实机测试。`BW03_20260730` 和 `BW03_20260813` 未实机验证，刷写可能造成无法启动、数据丢失，极端情况下可能损坏设备。本工具不提供安全保证，请自行承担风险。

## 支持设备

- 型号：`GT78-VN`
- 主板：`k85v1_64`
- 固件：`BW03_20260730`、`BW03_20260813`、`BW03_20260828`
- Root 方案：Magisk 30.7 + Zygisk

脚本显示设备、固件、锁状态及目标分区，自动选择活动槽并校验镜像。未知设备或不匹配的固件不会刷写。

## 按键与启动模式

- 关机状态下同时按住“开机键 + MODE”，进入启动模式菜单。
- 使用 `MODE` 在 `Recovery Mode`、`Fastboot Mode` 和 `Normal Mode` 之间循环选择。
- 按 `LC` 确认启动模式。
- 进入 Recovery 后，使用音量滚轮上下选择；也可以按 `MODE` 循环选择。
- Recovery 中按开机键确认。
- Fastboot 的“音量+ / YES”对应 `L2` 右侧的 `MODE` 按键。

## 1. 解锁 Bootloader

运行 `1_Unlock_CN.cmd`。解锁通常会清除全部用户数据，请先备份。

已解锁时直接退出。输入 `CONTINUE` 进入 Bootloader，预检通过后输入 `UNLOCK`。命令可能立即清除数据；如掌机出现确认界面，按音量+ / YES。

## 2. 获取 Root

运行 `2_Root_CN.cmd`。脚本自动识别 0730、0813 或 0828，校验对应镜像，只刷当前活动槽，不修改另一槽。

开始刷写前请再次核对预检中的固件版本。0730 和 0813 仅准备了对应镜像，尚未在实体机器上验证，不能保证正常启动或恢复。

预检通过后输入 `ROOT`。Android 启动后，脚本安装 Magisk、开启 Zygisk、安装模块并重启验证。

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

安装 OTA 前运行 `3_Restore_CN.cmd`。脚本识别当前固件，只向活动槽恢复匹配的原版 boot。预检通过后输入 `RESTORE`，不需要选择槽位。

恢复同样会写入 boot 分区。0730 和 0813 的恢复流程没有经过实机测试；选择错误版本或镜像异常可能导致设备无法启动。

恢复后先确认 Android 正常启动，再检查并安装 OTA。OTA 在新槽正常启动后，应提取并修补新版本 boot，再重新获取 Root。

恢复菜单：

- `[1]` 恢复原版 boot，完成后可选择加锁。
- `[2]` 仅加锁，不刷写镜像。

已加锁时直接退出。当前 boot 的 SHA256 与原版一致时跳过恢复；无法读取分区时显示“未知”。没有 Root 权限不能证明 boot 是原版。

加锁前必须确认所有分区均为匹配的官方原版，依次输入 `Y`、`LOCK-ERASE`。命令可能立即清除数据；重启后需重新初始化。

> [!WARNING]
> 不建议重新锁定 Bootloader。恢复原版 boot 并不能证明其他分区均为官方原版；如果存在不匹配或已修改分区，重新锁定可能导致设备无法启动。

原版镜像对应关系：

- `boot_0730_stock.img` → `BW03_20260730`
- `boot_0813_stock.img` → `BW03_20260813`
- `boot_0828_stock.img` → `BW03_20260828`

严禁混用不同固件版本的原版或修补 boot。

## 官方刷机包下载

- [官方下载页](https://ayaneo.com.cn/support/download)

进入页面后选择“Android 掌机”，再选择“KONKR Pocket Advance”。

> [!WARNING]
> 官网目前提供的包应按卡刷更新包使用，不是经过确认的完整线刷恢复包。卡刷不保证覆盖所有底层分区，也不一定能把设备恢复到完整原厂状态。设备无法进入 Android 或 Recovery 时，不应把该包当作线刷救砖包。

## 运行条件

1. 电量不少于 50%。
2. 开启 USB 调试并授权本电脑。
3. 使用可传输数据的 USB 线，只连接一台安卓设备；刷写流程不会使用无线 ADB。
4. 工具包已内置 ADB、Fastboot 和签名 Android USB 驱动。启动时会自动检查；缺少驱动时会弹出 Windows 管理员授权窗口并自动安装，无需用户预装。
5. 若授权被拒绝、设备未授权、离线或同时连接多台设备，脚本会给出对应提示，不会继续刷写。
6. 镜像刷写过程中不要断开 USB。

每个脚本都会在当前文件夹生成带时间戳的日志。
