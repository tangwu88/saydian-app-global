# U19 交接包刷新与独立校验（2026-10-03）

## 修改原因、范围与预期

- 用户要求继续更新已整理的 U19 交接包并提交 Git。只更新交接说明、索引和包内脱敏记录；不改 App/服务端运行时代码、健康数据、设备设置或线上发布配置。
- 本机先处理上一轮遗留的 `docs/CHANGE-TEST-LOG.md` rebase 冲突：保留交接包与同事 iPhone QA 两条记录，`git diff --cached --check` 通过，`git rebase --continue` 成功。旧提交重放为 `6a3c2a3`，未跳过同事提交。随后 `git fetch --prune origin`；当时 `origin/feature/u19-eb1` 为 `4736fcbe29030b9d004b67b6ccc0fd622def87f7`，本机仅领先一笔文档提交，没有再拉取或覆盖工作树。
- 本轮开始 `gh api` 再次显示 `tangwu88/saydian-app-global` 为 Public。按已确认的私有交付要求，用管理员身份恢复 Private 并复查；仓库反复变更可见性，项目负责人须单独核查访问历史和自动化。**未在 Public 状态上传交接资产。** 服务端仓库和服务端脏工作树未修改。
- 固定 App 源码为 `4736fcb`，较上一包的 `2c625e7` 仅新增/修改 iOS QA 文档、`integration_test/app_ui_smoke_test.dart` 与 `test/support/ios_inner_page_capture.dart`；Android 运行时代码未变。服务端仍固定独立分支 `ef51e665babdc3c9e5cd1b7a7dbb24e918c84695`，不是线上部署版本。Android QA APK 延用 9 月 30 日已重建核验的相同字节版本。

## 本轮验证与失败记录

| 操作 | 结果与边界 |
| --- | --- |
| `flutter analyze --no-pub` | 通过，`No issues found`，约 69 秒。 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter compact` | 929/929 通过。 |
| `TZ=UTC flutter test --no-pub --reporter compact` | 929/929 通过。 |
| 首次 `git archive --output=(Join-Path ...)` | PowerShell 将输出路径错误传给 Git，命令报 `not a valid object name`，没有生成 App ZIP；改为先赋值绝对路径、再用 `git archive -o $archivePath <commit>`，导出成功。未改源码。 |
| Android 构建/原生测试 | 本轮未重复执行。前一包记录的 Android 原生 22/22、双 ARM Debug/QA Release 构建和 APK SHA 匹配只适用于未变的 Android 运行时代码；不能冒充本轮新执行。 |
| iOS/Harmony/真机/服务端回读 | 本轮未执行。Windows 不能验证 iOS 构建；未连接 U19 或 Android 手机，也未部署服务端分支。 |

## 交接包和完整性

- 文件：`F:/xcodeplace/国内电商/交接产物/SAYDIAN-Health-U19-交接包-20261003.zip`，**94,239,881 字节**，外层 SHA-256：**`E7AC9101ECD464092C2ED7DC65B9BE2E58133717890327C25D63A22C8E7D4DA5`**。旧 `20260930` 包保留作历史快照，不覆盖。
- 外层含 10 个文件：`START-HERE.md`、`SHA256SUMS.txt`、App 源码 ZIP、服务端源码 ZIP、内部 QA APK，以及 `records/` 中 5 份脱敏交接/QA 记录。`7z t` 显示 `Everything is Ok`。独立解压到另一目录，清单记录 9 项、实际 9 项，逐文件 SHA-256 **9/9** 相符，无缺失、多余或不匹配。
- App 源码 ZIP 从固定提交 `git archive` 导出，1363 条目；服务端源码 ZIP 728 条目。两份 ZIP 均通过 `7z t`。路径扫描未发现绝对路径、`..`、`.git`、真实 `.env`、私钥/签名文件或构建缓存；服务端只含两份 `.env.example` 配置模板。包内 5 份记录扫描 GitHub/API Token、邮箱地址和蓝牙 MAC 模式，均为 0 命中。此范围检查不等于对 APK 二进制的完整密钥审计。
- APK 为 `SAYDIAN Health 0.1.23+1007`、`cn.saydian.app.global` 内部 QA 包，SHA-256 `4DCD31B3CA86C703943A2D908E4C22530B57465DE502EC3686704316EA436E38`；不是生产签名包，不可直接上架或替换线上下载页。
- 源码 ZIP 不含 `.git` 历史；继续开发必须克隆私有仓库，先检查分支、工作树及远端，按 `START-HERE.md` 和记录逐项复验，不把快照覆盖现有工作区。

## 新纳入的未解决问题

- **Bug 名称：** iOS U19 当天同步 `StateError`（暂列 P1，待堆栈确认）。**复现线索：** iPhone 15 Pro Max 的 `0.1.23 (1007)` 有线 Debug 会话，在 U19 日汇总读取日志 `[U19Sync] daily: index=0 dayOffset=0` 后两次出现 `[U19Sync] StateError`。**预期：** 完成当天读取并明确保存/待同步状态。**实际：** 读取失败，尚无堆栈、原始包及页面状态证据，不能断言根因或同步成功。**影响：** U19 每日数据闭环未验收。下一位同事先取脱敏堆栈、原始命令状态与设备时钟，再定向修复并真机回归；不得用旧历史值冒充新结果。
- iPhone 离线夹具 34 个内页可渲染、双时区测试通过，但逐页真机自动化在 VM 通道断开后未完成；详见包内 `records/QA-20260930-IOS-PAGE-DEBUG.md`。Flutter USB Debug/热重载曾通过，不等于 U19 iOS 蓝牙实测。
- Android U19 GATT 服务发现偶发超时、服务端日汇总能力的隔离部署/迁移/真实非零样本回读、Harmony 真机、生产签名与在线更新仍未验收。GitHub Actions 账单/额度阻断及仓库可见性反复变化仍需负责人处理。

## 接手顺序

1. 先核对仓库 **Private**、本包外层 SHA 与 `SHA256SUMS.txt`，阅读 `START-HERE.md`、本记录和两端 QA；修改前 fetch，不覆盖并发工作。
2. iOS 真机获取 U19 `StateError` 脱敏堆栈并复现；Android 用最终 QA 包完成连接—时间同步—当天读取—断线重连，期间不自动启动充气测量。
3. 服务端在独立隔离环境完成日汇总能力、非零样本上传、`acceptedIds`、折叠回读和账号隔离；不得把分支存在当作已部署。
4. 复核 Android/iOS/Harmony 构建、真实设备与 CI 后再判断是否可进入发布流程。本包只供内部交接和 QA。
