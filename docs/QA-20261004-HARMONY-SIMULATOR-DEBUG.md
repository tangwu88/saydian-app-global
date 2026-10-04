# HarmonyOS 模拟调试：2026-10-04

## 范围与成功标准

SAYDIAN Health 0.1.5（10），`cn.saydian.app.global.hm`。在 Windows 官方 DevEco Studio 26.0.0.851 / HarmonyOS 5.0.5（API 17）x86_64 模拟器启动可见 Debug App；验证页面加载、返回、会话恢复、语言切换及未登录提示。只读现有服务端数据，不生成测量记录，不操作共享权限。

主实例 `SaydianHealthApi17` 保留原数据及登录，结束时停留健康首页且窗口保持打开。另建 `SaydianHealthGuestQA17`（2 GB）验证空白安装的未登录流程；完成后停止该实例。没有鸿蒙真机，BLE / ECG 测量 / 充电与上传验收仍待实表验证。

## 复现与修复

1. 未登录时，关爱和心电历史显示空数据，没有登录操作。原会话观察器还会在恢复或刷新凭据时清空展示，却不重新加载。现按账号与会话代次响应变化，切换账号时清理旧数据并重新加载；同一会话刷新凭据不重复清空或触发加载循环。未登录显示“请先登录 / 前往登录”。
2. 关爱概览重复显示页面标题。保留外层标题，内层仅显示当前详情指标。
3. V2 返回的 `value`、`deepHours`、`lightHours`、`remHours` 被直接显示为字段名。补齐通用指标和睡眠标签及八语言文案，保留服务端数值与明确单位；睡眠分段图按统一分钟比例显示小时与分钟，不修改原记录。

## 实际验证

| 检查 | 结果 |
| --- | --- |
| 可见模拟器冷启动、HDC 安装 / 启动 Debug | 通过；保留主实例已登录会话 |
| 已登录关爱概览、步数日 / 周 / 月、返回首页 | 通过；实际国际接口返回已授权成员数据 |
| 修复后关爱字段标签、睡眠分段 | UI 标签复核通过；小时 / 分钟单位及比例回归测试通过 |
| 百科三篇中文文章列表、正文和返回 | 通过；“心率的原理”正文仍仅两字，内容待完善；没有配图可验收 |
| 已登录心电历史 | 加载完成、暂无记录；无真实波形可验证，不声称波形验收通过 |
| 空白实例未登录关爱（英语） | 显示 Please sign in / Go to login；点击返回登录页 |
| 登录页八语言选择菜单、切换简体中文 | 通过；未输入凭据或提交登录 |
| 重启后简体中文、未登录 ECG 历史及返回登录 | 通过；显示“请先登录 / 前往登录” |
| 主进程 hilog、faultlogger | 当前 40 行 App 日志未发现 Uncaught / Unhandled / Fatal / JsError / TypeError / ReferenceError / SyntaxError；faultlogger 目录无文件。只代表本轮采集窗口 |
| Asia/Shanghai 全量主机测试 | 523 / 523 通过 |
| Europe/Berlin 全量主机测试 | 523 / 523 通过 |
| ARM64 / x86_64 Debug、Release | 四个构建通过；包元数据、ABI、CRC 检查通过 |
| 签名 | 四个产物未签名；模拟器可安装不代表真机可安装 |

服务器某条热量记录显示 76210 kcal，疑似数据或单位问题，列为待核查；本轮不改服务端数据，也不按猜测缩放。当前本人健康页在无手表连接时不显示设备指标卡片，真实设备能力与记录的展示仍列入真机清单。

## 重现命令与本机证据

在 `D:\Dev\SaydianHealthHarmony` 执行；原 F 盘仓库及已冻结交付包保留。构建的 r1 是中间版本，最终使用 r2。

```powershell
& ./harmony-native/scripts/build-windows.ps1 -Flavor simulator -SimulatorStage 'D:\Dev\SaydianHarmonySimulator\api17-debug-20261004-r2' -OutputDirectory 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2'
& ./harmony-native/scripts/build-windows.ps1 -Flavor arm64 -OutputDirectory 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2'
$env:TZ='Asia/Shanghai'; node --test harmony-native/tests/*.test.mjs
$env:TZ='Europe/Berlin'; node --test harmony-native/tests/*.test.mjs
python harmony-native/scripts/inspect-test-haps.py 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2'
& 'D:\Dev\DevEcoStudio26\tools\emulator\Emulator.exe' -start SaydianHealthApi17 -instancePath 'D:\Dev\HarmonyEmulatorInstances' -imageRoot 'D:\Dev\HarmonyEmulatorImages'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 install 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 shell aa start -a EntryAbility -b cn.saydian.app.global.hm
```

构建脚本要求新目录；重复构建须使用新 stage 和产物目录。主模拟器已在运行时无需再次启动。SDK BLE 已从模拟器包移除，独立适配器不提供假设备或模拟健康数据。

本机证据：`D:\Dev\SaydianHarmonyValidation\sim-debug-20261004`，含构建 / 测试 / UI 布局 / 截图 / 主进程日志；可能含本人及授权成员健康信息，留在本机，不提交 Git。

| 最终未签名产物 | 字节数 | SHA-256 |
| --- | ---: | --- |
| ARM64 Debug | 23299733 | b456febe88242f2f493545638570dba0b07c5ad2c2698edc1d63d492db76b27a |
| ARM64 Release | 16673631 | 7ee9290ea396b9b51c450c979cb70faef0a27f63ed8d33bf6e070f04db24997f |
| x86_64 UI Debug | 9964444 | 2b62cdcf2e42a6eceddc3b16b18dfebeefd0b6493d4245df5dca5dc5c61dac92 |
| x86_64 UI Release | 6425594 | d86cc124d19686e114e6f55269822a1f82b83bc4d037697aa51a3c826fefcb8d |

启动问题与处理：切换可见窗口时官方模拟器要求重新接受本机许可证，接受后冷启动成功；早期 HDC 安装在启动完成前返回 Device not found，设备就绪后成功。DirectSoundCapture 无驱动警告不影响本轮 UI 测试。首次签名检查缺少 outCertChain 参数，按官方帮助补齐后重验。未清空模拟器、用户会话或通用日志。
