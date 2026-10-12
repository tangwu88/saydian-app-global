# 鸿蒙模拟调试更新：2026-10-12（Asia/Shanghai）

## 范围与结果

当前鸿蒙分支同步、最新包校验、覆盖安装和调试恢复。本轮没有新业务代码，不修改版本、不合并其他分支、不重置用户数据、不操作服务器或真实手表。

- 工作目录 `D:\Dev\SaydianHealthHarmony`，分支 `codex/harmony-health-20261004`，开始时工作区干净，HEAD `5196e31`。
- `git fetch --prune origin`、`git pull --ff-only origin codex/harmony-health-20261004` 完成，当前分支领先 / 落后 **0 / 0**，没有新增提交。其他客户端分支新增的 iOS 调试记录未包含鸿蒙改动，未合并该分支。
- 实际复核源码 `6c14193` 的 [完整 CI 37412007977](https://github.com/tangwu88/saydian-app-global/actions/runs/37412007977)：quality、Harmony UTC / Asia/Shanghai / Europe/Berlin、Android、iOS 全部成功。本轮没有重新构建或重复全量测试，不把旧 CI 记成新测试。
- 复用已验证 **SAYDIAN Health 0.1.5（10）x86_64 UI Debug**，包名 `cn.saydian.app.global.hm`、API 17、未签名；本机实际校验 **9964475 字节**、SHA-256 `08e0101d84c5d4b49fc42ca964ebca20fa0b272514c38aaa84dbd610a7b67567`，与 [2026-10-06 构建记录](QA-20261006-HARMONY-UPDATE.md) 一致。
- 原模拟器未运行，以独立进程启动 `SaydianHealthApi17` 可见窗口；HDC `127.0.0.1:5555` 就绪，覆盖安装及 `aa start` 成功，原实例数据保留。
- 本次新布局生成于 **2026-10-12 18:11:10**；首页正常、原账号登录显示保留、English 设置未修改，日期显示 **Oct 12**。UI 导出成功及更新时间均检查，不接受旧 `analysis.md`。
- 模拟器进程 **19208**、App PID **2460** 保持运行。采集的 **13 行** App 日志匹配 Uncaught / Unhandled / Fatal / JsError / TypeError / ReferenceError / SyntaxError 为 **0**，faultlogger 目录无文件；只代表此次采集窗口。
- 官方许可通过 CLI 确认；冷启动和 DirectSoundCapture 无驱动警告保留，不记为 App 崩溃。

## 命令与证据

```powershell
git status --short --branch
git remote -v
git fetch --prune origin
git pull --ff-only origin codex/harmony-health-20261004
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 install 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 shell aa start -a EntryAbility -b cn.saydian.app.global.hm
```

本机证据目录 `D:\Dev\SaydianHarmonyValidation\update-20261012`。截图、布局、运行日志可能含账号信息，仅留本机，不提交 Git。没有替换或删除此前构建和证据。

本次仅验收同步、包校验、安装、启动及会话 / 页面恢复，不替代完整功能或真机验收。鸿蒙真机 BLE、ECG 波形、充电与自动上传仍待验证；未签名包不能称真机可安装包，天气继续暂缓。
