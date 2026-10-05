# 鸿蒙模拟器更新：2026-10-05（Asia/Tokyo）

## 范围与结果

按当前鸿蒙调试任务执行“更新”：安全同步当前分支、校验已验证测试包、覆盖安装并恢复可见模拟器。没有新的鸿蒙源代码提交，未修改业务代码、版本或服务器。

- 仓库 `D:\Dev\SaydianHealthHarmony`；分支 `codex/harmony-health-20261004`。
- 源码基线 `c5388c221888701fcacd3b1b0025d9e94fadd321`。开始时工作区干净，fetch 后当前分支与远端差异 0 / 0，`pull --ff-only` 返回 Already up to date。
- 其他客户端分支新增 iOS / 文档 / 交接工具提交，未包含鸿蒙目录改动；未合并其他分支。
- 复用上一轮 r2 的 x86_64 UI Debug 包：SAYDIAN Health **0.1.5（10）**、`cn.saydian.app.global.hm`、API 17，**未签名**。无代码变化，不重复构建或全量测试。
- 实际重新计算 SHA-256 与上一轮记录一致，字节数 **9964444**；摘要 `2b62cdcf2e42a6eceddc3b16b18dfebeefd0b6493d4245df5dca5dc5c61dac92`。
- 主实例 `SaydianHealthApi17` 原来未运行；重新冷启动后 HDC `127.0.0.1:5555` 就绪。覆盖安装与启动成功，当前首页正常、简体中文及原登录状态保留。没有重置数据或提交登录。
- 本轮主进程 PID 2655，采集的 19 行 App hilog 未匹配 Uncaught / Unhandled / Fatal / JsError / TypeError / ReferenceError / SyntaxError；faultlogger 目录无文件。只代表本轮采集窗口。
- 模拟器可见窗口保持运行；原已冻结 HAP 和交接包保留。

## 命令与证据

```powershell
git status --short --branch
git remote -v
git fetch origin
git pull --ff-only origin codex/harmony-health-20261004
git rev-list --left-right --count HEAD...origin/codex/harmony-health-20261004
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\tools\emulator\Emulator.exe' -start SaydianHealthApi17 -instancePath 'D:\Dev\HarmonyEmulatorInstances' -imageRoot 'D:\Dev\HarmonyEmulatorImages'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 install 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 shell aa start -a EntryAbility -b cn.saydian.app.global.hm
```

首次启动因模拟器重新要求许可证确认而退出；通过官方 `-license accept` 确认后再次启动成功。失败与重试日志分别保存，未覆盖失败证据。Cold boot 与 DirectSoundCapture 无驱动警告保留，不记为 App 崩溃。

本机日志、UI 布局和截图存于 `D:\Dev\SaydianHarmonyValidation\update-20261005`，不提交包含账号信息的原始证据。实际复核上一轮源码的 [Git 检查 37179800097](https://github.com/tangwu88/saydian-app-global/actions/runs/37179800097)，quality、Harmony UTC / Asia/Shanghai / Europe/Berlin、Android、iOS 均已完成并成功；这些是上次提交的检查，本轮未重复执行。

## 验证边界

本次只验收同步、包校验、安装、冷启动、会话保留及页面打开。上一轮详细功能验证见 [模拟调试记录](QA-20261004-HARMONY-SIMULATOR-DEBUG.md)。BLE、真实 ECG 波形、充电与自动上传仍需鸿蒙真机；未签名 ARM64 包不能称为真机可安装包。天气继续暂缓。
