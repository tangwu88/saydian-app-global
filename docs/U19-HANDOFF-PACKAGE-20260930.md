# U19 最新交接包生成与校验（2026-09-30）

## 修改原因、范围与来源

- 用户要求整理本任务、打包交给下一位同事，并提交上传到 Git。仅新增/更新交接说明、索引与本记录；没有改动 App 运行时代码、健康算法、服务端工作区或线上数据。
- 开始时 App `feature/u19-eb1` 与 `origin` 一致，HEAD 为 `00e899fa381ff92c622714212a5c67ebb6d1d6a1`。`origin` 是 `tangwu88/saydian-app-global`，登录的 GitHub 账号已核对为 `tangwu88`。服务端独立分支远端固定 `ef51e665babdc3c9e5cd1b7a7dbb24e918c84695`；本机服务端 `main` 落后远端且有三项未跟踪文件，未清理、拉取或打包其工作区状态。
- 上传前 `gh repo view` 发现国际 App 仓库再度为 `PUBLIC`，与已确认的私有交付边界冲突；使用仓库管理员账号将其改回 `PRIVATE` 并二次核对。变回私有不能撤销此前公开窗口，需项目负责人审视访问历史与合作方授权。服务端仓库可见性未修改。
- 打包期间同事连续推送 iOS 调试记录与 `ios/Podfile.lock` 的 `share_plus` 补项。先把本地交接文档作为可恢复提交 `40fbd9b`，再安全 rebase 到远端；`docs/CHANGE-TEST-LOG.md` 的单处冲突保留了双方条目，得到提交 `5585267`。第一次 `git rebase --continue` 因无交互编辑器失败，第一次带空格的编辑器路径又解析失败；改用 Git 自带 `true.exe` 的短路径后成功，没有跳过或丢弃任何提交。随后同事追加 22:24 iPhone Debug 会话记录，本分支干净时 `git pull --ff-only` 到 **`2c625e7a689b318b80ee667077fd8b48b2a21eb0`**。包的 App 源码快照固定于此提交，后续远端变化应由下一位同事自行 fetch 审阅，不隐式混入本包。

## 打包前复核

以下本机检查在合并同事最新 iOS 记录之前执行；随后纳入的提交仅涉及 `ios/Podfile.lock` 的 `share_plus` 补项和文档，Dart/Android 构建输入未改变。没有把这些 Windows 检查冒充合并后 iOS 构建；iOS 结果以同事独立真机记录为准。

| 命令 / 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 156 文件、0 变更。 |
| `flutter analyze --no-pub` | No issues found。 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter compact` | 929/929 通过。 |
| `TZ=UTC flutter test --no-pub --reporter compact` | 929/929 通过。 |
| `:app:testDebugUnitTest --offline --no-daemon` | BUILD SUCCESSFUL；XML 22/22，0 失败。旧 Kotlin/Gradle 插件弃用警告未在打包任务内更改。 |
| 双 ARM `flutter build apk --debug` 与内部 QA `--release` | 均构建成功；重建 Release SHA-256 与已有 QA 包 **完全相同**：`4DCD31B3CA86C703943A2D908E4C22530B57465DE502EC3686704316EA436E38`。参数为正式国际 API origin、空天气密钥；QA Release 不是生产签名。 |
| 本轮 iOS/Harmony 构建与 U19 真机 | Windows 无法执行 iOS/Harmony 原生构建；Android 手机不在 ADB 列表。本次没有测量、设置写入、真机同步或云端回读。另一个同事的 iPhone Debug/热重载证据见其独立记录，不等于 iOS U19 蓝牙验收。 |

## 交接 ZIP

- 本机文件：`F:/xcodeplace/国内电商/交接产物/SAYDIAN-Health-U19-交接包-20260930.zip`；大小 **94,232,068 字节**；SHA-256 **`0BE22359108C283A30E5B22A556BEA53A6F2F571AA79B2821BFD52CCDAA7F98C`**。
- 9 个外层条目：`START-HERE.md`、`SHA256SUMS.txt`、App 源码 ZIP、服务端源码 ZIP、上述 QA APK 与 `records/` 中四份脱敏交接/QA 记录。App 快照为 `2c625e7`，服务端快照为 `ef51e66`；均用 `git archive` 从固定提交导出，**不含 `.git` 历史**。APK、ZIP 及原始截图/日志不提交源码 Git 历史。
- `7z t` 对两份源码 ZIP 均为 `Everything is Ok`：App ZIP 1362 个条目（1104 文件）、服务端 ZIP 728 个条目（631 文件）。两份源码 ZIP 的路径扫描对绝对路径、`..`、`.git`、真实 `.env`、`.pem/.p12/.mobileprovision` 和构建缓存命名均为 0。
- 外层 ZIP `7z t` 为 `Everything is Ok`、9 文件；独立解压后按 `SHA256SUMS.txt` 逐项复算 **8/8**，缺失、多余、不匹配与不安全相对路径均为 0。所有记录的邮箱/MAC/GitHub Token 模式扫描无命中。固定 App 提交文本的私钥/GitHub Token/AWS Key 快速扫描无命中；服务端固定提交仅命中已在上轮核对过的 `integration-settings.test.ts` 合成 PEM 测试夹具。此快速扫描不能替代二进制 APK 的完整密钥审计。
- 在同事推送新 iOS 记录之前曾生成一个固定较早 App 提交的草稿 ZIP；已移至忽略的 `build/handoff-drafts/`，**未上传**。只有上述 SHA-256 的候选包可交付。

## 未验收与下一步

- GitHub Actions 当前因账号账单/支出额度在作业步骤前阻断；本机通过不能代替新 CI 通过。恢复账号后须重跑包含 Android ABI 门禁的完整 CI。
- Android 最终 QA 包没有完成新的 U19 真机安装—连接—同步—服务端回读；此前 GATT 服务发现间歇无回调仍为 P1。服务端日汇总分支的隔离部署、独立数据库迁移及真实非零样本闭环继续未验收。
- iPhone 当前有 Debug/热重载及新会话证据，但没有 iOS U19 蓝牙实测；HarmonyOS U19 真机、不同固件、生产签名/上架与在线更新均未验收。
- 下一位同事先从包内 `START-HERE.md` 和 `records/U19-HANDOFF-20260930.md` 开始，按 `AGENTS.md` 先更新远端。不得把固定源码快照直接覆盖已有工作区或把内部 QA 包发布到线上下载页。
