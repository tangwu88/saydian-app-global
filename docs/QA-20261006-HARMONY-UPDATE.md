# 鸿蒙更新与调试恢复：2026-10-06（Asia/Shanghai）

## 范围

安全同步现有鸿蒙分支、校验测试包并恢复模拟调试。复核后仅修正首页日期不跟随 App 语言的问题，不增加功能或修改版本，不合并其他分支，不操作服务器、账号授权或真实手表。

- 开始时工作区干净，HEAD `01480c7`，分支 `codex/harmony-health-20261004`。
- `git fetch --prune origin`、`git pull --ff-only origin codex/harmony-health-20261004` 完成，当前分支与远端差异 **0 / 0**，没有新增提交。
- 最初复用已验证 **SAYDIAN Health 0.1.5（10）x86_64 UI Debug**，包名 `cn.saydian.app.global.hm`、API 17、未签名；发现日期问题后重新构建，最终验证在下节记录。
- 实际校验原 HAP：**9964444 字节**，SHA-256 `2b62cdcf2e42a6eceddc3b16b18dfebeefd0b6493d4245df5dca5dc5c61dac92`，与上一轮记录一致。包文件在 `D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2`。
- 首次冷启动后覆盖安装、`aa start` 成功；随后复核发现模拟器退出，HDC 返回目标不存在。Emulator 日志记录退出，未据此断言 App 崩溃。
- 第一次 UI 导出失败，磁盘中的 `analysis.md` 实际生成于 **2026-10-05**；复制得到的旧快照保留作失败证据，**不计入本次页面验收**。
- 改用独立进程重新启动原实例，保留用户数据；首次安装与失败证据均未覆盖。

## 首页日期问题（P2）

- 复现：已登录 App 使用 English，进入健康首页；实际日期显示“10月6日”，预期日期随 App 语言显示。
- 原因：`Index.ets` 的 `todayText()` 固定拼接中文“月 / 日”。
- 修改：调用 `Date.toLocaleDateString(this.appLocale, { month: 'short', day: 'numeric' })`。只改变当前设备本地日期的展示格式，不改变记录日期、时区、接口参数或健康数值。
- 恢复后的新布局生成于 **2026-10-06 11:56:16**，原登录状态仍在；界面当前为 English，不把上次中文快照视作当前语言。

## 修复后的验证与产物

- Asia/Shanghai 与 Europe/Berlin 全量 Harmony 主机测试各 **523 / 523 通过**；无新增镜像实现的测试，日期显示通过真实模拟器复核。
- 官方 Windows 构建 ARM64 / x86_64 Debug、Release 四个包全部成功，包元数据、ABI 和 CRC 检查通过；官方 `hap-sign-tool.jar verify-app` 确认四个包均没有签名。
- 新 x86_64 Debug 已覆盖安装，原登录保留；英文首页真实显示 **Oct 6**，切换简体中文后显示 **10月6日**，随后恢复原英文设置。未退出账号或修改健康数据。
- 最终布局生成于 **2026-10-06 12:04:02**，模拟器进程 54792 保持运行，App PID 5593；最终采集的 57 行 App 日志异常匹配为 0，faultlogger 目录无文件。异常筛选为 Uncaught / Unhandled / Fatal / JsError / TypeError / ReferenceError / SyntaxError，仅代表本轮采集窗口。
- 本轮 ARM64 包未安装到真机；未重复无关的 Flutter / Android / iOS 本地构建，不把主机测试当成真机验收。
- 新产物独立保存在 `D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts`；以前所有已冻结包保留。

| 新未签名产物 | 字节数 | SHA-256 |
| --- | ---: | --- |
| ARM64 Debug | 23299764 | 50e0bc61a1b3b3b5b48549d6f88521a1414d5c9cd950cb1c4fe5a8f665ce402f |
| ARM64 Release | 16673599 | 3b60da4ff6dfeb089d1c132cacc2bcc02f74f47eb151808b24742e6173e21a18 |
| x86_64 UI Debug | 9964475 | 08e0101d84c5d4b49fc42ca964ebca20fa0b272514c38aaa84dbd610a7b67567 |
| x86_64 UI Release | 6425626 | 125c5445abf27bad9af0eaa4b1ffb76c9a735b600656d76823fee27d0377a5ba |

## 命令与证据

```powershell
git status --short --branch
git remote -v
git fetch --prune origin
git pull --ff-only origin codex/harmony-health-20261004
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 install 'D:\Dev\SaydianHarmonyValidation\sim-debug-20261004\artifacts-r2\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 shell aa start -a EntryAbility -b cn.saydian.app.global.hm
$env:TZ='Asia/Shanghai'; node --test harmony-native/tests/*.test.mjs
$env:TZ='Europe/Berlin'; node --test harmony-native/tests/*.test.mjs
& ./harmony-native/scripts/build-windows.ps1 -Flavor simulator -SimulatorStage 'D:\Dev\SaydianHarmonySimulator\api17-date-20261006-r1' -OutputDirectory 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts'
& ./harmony-native/scripts/build-windows.ps1 -Flavor arm64 -OutputDirectory 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts'
python harmony-native/scripts/inspect-test-haps.py 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts'
& 'D:\Dev\DevEcoStudio26\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 install 'D:\Dev\SaydianHarmonyValidation\update-20261006\artifacts\SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap'
```

本机证据目录：`D:\Dev\SaydianHarmonyValidation\update-20261006`。日志、布局、截图可能含账号信息，保留在本机，不提交 Git。官方许可确认通过 CLI 完成；冷启动、DirectSoundCapture 无驱动及旧崩溃检测日志不等于当前 App 崩溃。

功能和构建基线见 [2026-10-04 调试记录](QA-20261004-HARMONY-SIMULATOR-DEBUG.md)，上一轮更新见 [2026-10-05 记录](QA-20261005-HARMONY-UPDATE.md)。鸿蒙真机 BLE、ECG 波形、充电及自动上传仍待验收，天气继续暂缓。
