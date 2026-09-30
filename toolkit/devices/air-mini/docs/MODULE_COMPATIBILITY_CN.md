# AYANEO Pocket AIR Mini 模块兼容性

> [!WARNING]
> 本文仅记录静态兼容性审查结果。下列模块均未通过本工具在 AIR Mini 真机上完成安装和运行验证。

AIR Mini 测试配置使用独立的模块白名单。新模块安装后默认停用；测试者确认风险后，才能在 Magisk 中手动启用并重启。

| 模块 | 是否预装 | 审查结果 |
| --- | --- | --- |
| Play Integrity Fork | 是 | 上游声明支持 Android 7 及以上版本。AIR Mini 的 Android 11 / API 30 和 arm64 环境满足基础要求；正常工作模式需要 Zygisk。尚未进行 AIR Mini 真机验证。 |
| Shamiko | 是 | 上游声明需要 Android 8.1 及以上版本和 Magisk 27005 及以上版本；工具包内置 Magisk 30.7，并会开启 Zygisk。尚未进行 AIR Mini 真机验证。 |
| KPA MYuppy Font | 否 | 会替换完整的 Android 12 `fonts.xml`，并非只替换字体文件。AIR Mini 使用 Android 11，必须先制作并测试专用字体映射。 |
| KPA RGB Control | 否 | 依赖 KONKR Pocket Advance 专用的 RGB LED 节点、温区索引和 AYAHOME 性能模式行为，不适用于未经验证的 AIR Mini。 |
| Dolby Atmos Razer Phone 2 | 否 | 会修改音频库、音频配置、VINTF、SELinux 策略、Dolby 服务与应用以及音频数据库。AIR Mini 使用不同的 Android 11 音频环境，并带有 MTK 音效功能，不能直接套用。 |
| KPA Touch Guard | 否 | 不属于 KPA Root 当前内置模块，并且依赖 KONKR Pocket Advance 的触摸设备名称和 MODE 按键事件；这些条件尚未在 AIR Mini 上验证。 |

模块白名单保存在 AIR Mini 配置目录的 `modules.psd1` 中。即使两台设备使用相同 SoC 或主板标识，也不会因此自动共用硬件或系统相关模块。

当前 AIR Mini 测试白名单只包含 Play Integrity Fork 和 Shamiko。两者安装后保持停用，不能将静态审查结果视为真机兼容性结论。
