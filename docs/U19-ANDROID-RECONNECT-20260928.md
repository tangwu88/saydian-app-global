# U19 Android 真机重连记录（2026-09-28）

## 范围与基线

- 用户目标：将当前华为手机重新连接 U19 系列手表，并排查重连失败。
- 修改前分支：`feature/u19-eb1`，HEAD `6761372cb4d7e8c9f56f8444fd972fc36c096740`；`origin` 为 `tangwu88/saydian-app-global`。已执行 `git fetch origin --prune`，相对 `origin/main` 为本地领先 1、落后 0。工作树已有 U19 开发改动，未覆盖或合并其他分支。
- 精确目标为现场按 EB1 厂商广播校验发现的 U19S；列表中另有名称相近的 U19M，但未把名称当作协议兼容证据，也未连接它。
- 仅改 Android U19 GATT 收尾与服务发现时序；Veepoo、玉成通道、健康算法、账号和服务端协议均未改动。

## 问题与过程

| 阶段 | 复现、预期和实际结果 | 结论 |
| --- | --- | --- |
| 现状 | U19S 已连接时可读设备信息和 55% 电量。手动断开后扫描仍能发现目标；连续两次重连都收到 GATT `status=0/state=2`，但无 `onServicesDiscovered`，25 秒超时。预期是订阅通知并读到设备信息后才显示已连接。 | P1，未误报连接成功；重启 App 后可恢复，怀疑连接收尾或服务发现时序，不把猜测写成已证明根因。 |
| 第一轮修复 | `UrionGattTransport.kt` 将 `disconnect()` 与 `close()` 分开，等待断开回调，最多 2 秒后关闭。Debug 构建、覆盖安装通过；安装后与进程内重试仍发生服务发现超时。 | 仅延后关闭不足以解决，失败记录保留。 |
| 第二轮修复 | GATT 连上后延后 600 毫秒发起服务发现；7 秒仍无回调时在同一连接内重试一次；原有 25 秒最终超时和“未完成初始化不显示连接成功”规则保留。 | Android 官方文档将 `discoverServices()` 定义为异步操作，返回 `true` 只表示请求已发起，必须等待 `onServicesDiscovered` 才能使用服务。 |
| 真机复验 | 第二轮 Debug 构建与覆盖安装通过。冷启动恢复一次、手动断开后重连两次均完成服务发现、通知订阅和设备信息读取；最后保持 U19S 已连接。一次扫描未出现目标，刷新后出现；未改连其他手表。 | 当前华为手机/U19S 样机的两次手动重连通过，尚不能外推到所有 U19 型号、手机或固件。 |

## 修改与验证

- 文件：`android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattTransport.kt`。
- 预期：断开后旧 GATT 不残留；短暂服务发现无回包时有一次有限重试；迟到回调不能把旧连接标为成功。
- 已执行：`flutter build apk --debug --target-platform=android-arm64`，随后 `flutter build apk --debug --target-platform=android-arm64 --no-pub`；两次 Debug 构建均成功。两次 `adb install -r` 经手机端安装确认后返回 `Success`，未卸载或清理应用数据。
- 真机证据：第一轮修复后在手机日志 `00:18`、`00:21` 仍超时；第二轮在 `00:26` 冷启动恢复、`00:30` 和 `00:36` 手动连接均出现 `services status=0`、`notifications status=0`、`ready`。原始截图和日志只留本机忽略的 `build/`，不纳入 Git。
- 静态/自动化：`flutter analyze --no-pub` 返回 `No issues found`；`flutter test --no-pub --reporter compact` 返回 `All tests passed`，850 项。
- QA Release：设置 `SAIDIAN_ALLOW_QA_RELEASE=true` 后运行 `flutter build apk --release --target-platform=android-arm64 --no-pub`，构建成功，输出 `build/app/outputs/flutter-apk/app-release.apk`（45.2 MB）。这是本机 QA 构建，未安装、未签生产证书、未发布。构建有插件未来 Kotlin 兼容警告，不是本次编译失败。
- 构建后又收紧一个防御条件：退役 GATT 只在真正收到断开状态时提前关闭，迟到的“已连接”回调由 2 秒兜底处理，避免重新引入立即关闭竞态。该最终源码已重新完成 Android Debug 和 QA Release 构建；这一个细小补丁未再次覆盖安装，手机保持此前已实测的第二轮调试包。
- 最终本地 QA Release APK SHA-256：`aaf852805ee3fcffe2ad22981aa8d38170a3a50081621bedc1f2581f8f1e9f66`；Debug APK SHA-256：`2a92a67415c33173f21d5b33c27b2a8fa1b001805808e0b859dfa2f859c54dac`。二进制文件不入 Git。
- 最后检查：构建后重新进入设备页，U19S 仍显示已连接、电量 55%。
- 数据边界：U19 每日汇总包日期与手机当地日期不一致，客户端以 `date=true` 拒绝，未上传或伪造记录。用户确认手表界面语言为中文，但尚未提供手表日期；本轮未执行时间同步、测量、设置写入或服务端数据验收。
- 尚待执行/复核：iOS/Harmony 构建及真机、两种 U19 型号/固件、3 轮连接—完整同步—断开—重连。每日汇总待核对手表日期与手机时区后再验；现有两次手动重连不冒充完整同步验收。

## 后续修改前提醒

先更新并检查 `origin`、本文件及工作树。不要因设备名称包含 U19 就强制走 EB1 通道；也不要把 GATT 物理连上当作手表连接完成。重连测试必须以 `ready` 和页面状态共同验证，不能仅凭 `status=0/state=2`。
