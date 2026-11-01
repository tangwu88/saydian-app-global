# 客户端六项审查问题修复（2026-11-01）

## 基线与范围

用户授权按优先级修复 AUD-01–06、完成回归、记录并提交 Git。基线 `1c974ac`，工作树干净，已 fetch origin；分支 `codex/client-audit-fixes-20261101`。该本地历史无同名远端可 fast-forward，没有盲目拉入其他产品分支。原 10-31 审查和红灯结果保留，不覆盖历史。

本轮修改客户端与测试，版本保持 `1.0.1+1020`。不修改国内系统、美国服务器、签名凭据、商店审核、真实健康值或设备算法。初始磁盘余量约 5.2GiB；未删除归档/缓存/手机数据来换取构建空间。

## 修复结果与防复发

| ID | 实际修复 | 验证与限制 |
| --- | --- | --- |
| AUD-01 / P1 | 按时间及 ID 的稳定游标遍历 pending；本轮拒绝的记录保留原 payload、状态及错误结果，后续有效记录仍可上传。每次最多 1000 页×10条，达到上限保存独立、按 owner 隔离的扫描位置，下次继续；到尾后重置以便重试先前失败记录。扫描游标不是服务端 ACK，也不是服务器同步游标 | 原队首反例、部分 ACK、网络失败重试、跨服务实例续扫、换号取消、SQLite 真正读取与关闭重开、扫描 metadata 持久化和 owner 隔离均通过。主机 SQLite FFI 不等同 iPhone SQLCipher 恢复验收 |
| AUD-02 / P2 | 安全 vault 同一串行队列内比较后清除，比较 access/refresh/member/account 身份；Global logout/delete 绑定起始会话，重试时跟踪本次实际使用的刷新会话，旧请求不能撤销或清除新登录。Controller 退出/注销也检查原所有者和代次，不再无条件删除新会话 | A→B、同账号不同登录、退出失败、注销延迟、安全存储并发比较清除及原 refresh 隔离测试通过 |
| AUD-04 / P2 | 11 个商城私有页面通过共同 GlobalAccountBoundary 绑定登录代次和所有者；一旦失效就卸载内容/文本控制器/图片缓存，旧页面不能转而采用新账号。同步关闭旧导航栈上的弹窗，私有 State 的迟到加载、草稿清理和提交先检查 mounted | 原订单残留反例、退出后 B 登录、独立弹窗残留反例及原商城报价/下单/售后/地址/页面回归通过。新增“弹窗在页面树外”的保护；不是服务器越权渗透测试 |
| AUD-03 / P2 | 按当前云策略的候选记录判定状态，本机生理记录不再使 cloud complete 成立；已登录的 localOnly 使用独立的本机保存文案，九份语言资源同步生成 | 空库、仅本机、云记录、混合四种状态及原本机反例通过；不扩大 iOS 上传/分享指标 |
| AUD-05 / P2 | 删除 CoolWear 两处 Debug 原始压力值/设备时间输出；原有固定阶段和必要计数保留。加强 Android ring 与 iOS ring 日志隐私门禁 | 两 APK 的 DEX 不含旧原始值日志字符串；源码隐私门禁通过。其他 SDK 原始日志已有拦截保护沿用，封闭二进制内部不是完整可审计源码 |
| AUD-06 / P2 | ECG 改为 AbortableRequest + 流式限额：成功响应 25MiB，错误体 256KiB，20s 请求截止。gzip 分成 1KiB 压缩输入块，输出在累计前检查 32MiB 上限及 20s 截止；损坏 gzip 变成安全 API 错误；保留 hash/采样率/数量/账号复核 | 精确上限、超限取消、静默超时、持续小流量总截止、小压缩夹具超额、坏 gzip、HTTP 声明超限/错误体上限、旧波形完整回读及换号回包等通过。不对生产服务压测；iOS ECG 禁止范围不变 |

主要文件：`sync_service.dart` / `local_health_store.dart`；`secure_vault.dart` / `global_api_client.dart` / `api_client.dart` / `app_controller.dart`；新 `global_account_boundary.dart` 和两组商城页面；`device_pages.dart` 和 l10n；`CoolWearRingBridge.java`；新 `bounded_bytes.dart` 和 `global_health_api.dart`。

数据库没有新增 schema 版本或删除/改写健康 payload；仅增加独立 metadata 键 `queue_scan_cursor`。旧程序忽略此键，原 `sync_cursor` 的 ACK 语义保留。永久数值错误的既有隔离机制保留，新增元数据/服务端拒绝不会被假装成功或直接丢弃。

## 回归结果

工具：Flutter 3.44.9 / Dart 3.12.2；Node 使用已有 `/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node`。日志留在本机权限受限目录 `/private/tmp/saydian-client-fixes-20261101/`，不提交凭据、数据库、健康值、原始设备日志或二进制。

| 检查 | 实际结果 |
| --- | --- |
| `flutter --no-version-check analyze --no-pub` | 最终 No issues，退出 0 |
| `TZ=UTC flutter --no-version-check test --no-pub --reporter=expanded` | 最终 1142/1142，退出 0（约 30s） |
| `TZ=Asia/Shanghai flutter --no-version-check test --no-pub --reporter=expanded` | 最终 1142/1142，退出 0（约 27s） |
| 最后定向四文件：client_review_regressions、bounded_bytes、ecg_resource_transport、sync_service | 37/37，退出 0；包含追加的 SQLite 扫描 metadata 重开检查 |
| 原审查命令兼容入口 `tool/audit/client_review_regressions_test.dart` | 转发到普通 test/ 的原正确断言；没有删断言、skip 或把坏结果改为期望 |
| 四组 Node 原生/认证离线门禁 | 93 项，92 通过，1 Windows ACL 在 macOS 跳过，0 失败 |
| `python3 -m unittest discover -s scripts/release -p 'test_*.py'` | 25/25，退出 0；发布工具夹具不是实际生产发布 |
| `dart format --output=none --set-exit-if-changed lib test tool/audit/client_review_regressions_test.dart` | 最终通过 |
| `git diff --check` / 新文档链接、结果 JSON | 最终通过 |

原四个安全反例已提升为 `test/client_review_regressions_test.dart`，常规 flutter test / 既有双时区 CI 自动执行；旧 tool/audit 路径仅为兼容转发。额外测试在 `test/bounded_bytes_test.dart`、`test/ecg_resource_transport_test.dart` 和 `test/sync_service_test.dart`。静态商城 Fake 仅补齐 owner identity 与监听接口；动态退出测试仍使用真实 AppController。

最终又检查了退出开始前的异步读会话窗口：先标记转换再读快照，并将快照传给网络层，避免在准备期间换号后以新账号发撤销请求。增加两个“旧快照禁止出站”的用例；1142 双时区全量与 37 项定向使用该最终逻辑。SQLite 用例还覆盖扫描 metadata 重开/owner 隔离。

## 构建与原生验证

Android 命令（在仓库根目录）使用 `SAIDIAN_DISABLE_REMOTE_PUSH=true JPUSH_VENDOR_CHANNELS=none`；Release 另加 `SAIDIAN_ALLOW_QA_RELEASE=true`：

```sh
flutter --no-version-check build apk --debug --flavor play --target-platform=android-arm,android-arm64 --dart-define=SAIDIAN_PLAY_STORE=true --no-pub
flutter --no-version-check build apk --release --flavor play --target-platform=android-arm,android-arm64 --dart-define=SAIDIAN_PLAY_STORE=true --no-pub
```

- Play Debug 最终构建 16.3s、QA Release 25.1s 成功，均含 armeabi-v7a / arm64-v8a。初次 Debug 20.4s、加固中间轮 Debug 8.2s / Release 82.7s、iOS Profile49.1s / Debug24.5s 均保留为过程记录；最终会话快照加固后重新构建，以本节最终结果为准。
- 实际 APK SHA/大小见 [结果汇总](audit/20261101-client-fix-results.json)。两包 DEX 均无原 `manual stress sample; ... value=` 字符串；这是一项产物检查，不是所有运行日志或厂商二进制的绝对无泄露认证。
- `SAIDIAN_DISABLE_REMOTE_PUSH=true JPUSH_VENDOR_CHANNELS=none ./gradlew :app:testPlayDebugUnitTest :app:testSideloadDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --console=plain`：BUILD SUCCESSFUL / 14s，两渠道 XML 各 38 项、0失败/错误/跳过。
- 保留 Flutter 对 camera_android_camerax / jpush_flutter_android 的 Kotlin Gradle Plugin 未来兼容警告；本次未擅自升级依赖。

两次 iOS 构建串行，`SAIDIAN_DISABLE_REMOTE_PUSH=true`；沿用已有 Xcode27 私有 xcconfig 设置本次 `IPHONEOS_DEPLOYMENT_TARGET=15.0`，不修改跟踪的最低部署版本：

```sh
flutter --no-version-check build ios --profile --no-codesign --no-pub
flutter --no-version-check build ios --debug --no-codesign --no-pub
```

- Profile 成功：40.1s / Runner.app 64.4MB。
- Debug 成功：16.6s，实际 Info.plist 为 cn.saydian.app.global / SayDian / 1020。没有声称无签名构建可直接安装或作为正式包上传。
- 保留 CocoaPods/Swift Package Manager 和 WechatOpenSDK 对新 Apple Silicon 模拟器架构的警告。目标为实体 device SDK，不是模拟器运行验收。

## 失败、修正与未执行项

1. 初次 analyzer 13 项：生成的私有内容 Widget 无人使用的 key 参数及 if 括号风格；已移除不需要的私有参数、修正格式，最终零问题。
2. 原 AUD-04 目标断言转绿后触发 Flutter 测试框架“foundation debug variable 未复位”：把测试平台覆盖在 widget 用例开始时复位，没有修改原隐私断言。
3. 扩展夹具误用 HealthRecord.copyWith 的不存在 metric 参数，改为通过测试工厂构造对应指标。该轮编译失败保留，后续测试已通过。
4. 新 iOS 日志扫描起初把 `QRingMeasurementValues(metric,value) != nil` 的布尔结果误认成直接输出原始 value；修正扫描为直接输出参数，仍禁止原值、userInfo 和设备身份，最终 92 通过/1跳过。
5. 格式化使个别单行 if 触发括号规则，已修正并重跑 analyzer；不是通过降低门禁来消除问题。两个旧 UI 路径/空 glob 的查找失败按实际文件清单修正。
6. 连接的 GitHub 工具有写权限；仓库实际 visibility=public。后续仅发布已核对源码/合成测试/脱敏记录，不改变可见性。工具树参数核对阶段的 schema/binding/422 失败没有修改任何分支；后续读取工具完整声明，使用正确 tree_elements/base_tree_sha 和完整内容后，空变更树与原树相同，验证工具路径可用。以后先读 ALL_TOOLS 中完整声明，不按 REST 参数名猜接口。
7. iPhone15pm 当前 unavailable，XR connected；未触碰 XR 的其他 App 测试。已请用户连接指定 iPhone15pm，以便保留数据覆盖安装。未获得连接前，新的设备采集/同步、SQLCipher 覆盖安装、独立冷启动不计通过。
8. 未执行 Harmony HAP、正式签名/上传、商店送审、线上账号/支付/OTP、生产服务器压测或远端 CI 通过核验。Git 发布与后续状态另记，不把本机通过当远端通过。

## Git 交付

提交前核对实际 diff、敏感资料排除及完整源树。使用独立国际版分支，不合并/强推 main、不覆盖 R12 分支。远端发布后的 commit、完整 tree 对比和当前 CI 状态将在这里追加。六项当前为 **源码已修复、自动回归已验证**；实体设备与正式签名验收单列，不与问题源码状态混为一项。

后续若制作正式上传包，必须核对商店已占用构建号并递增（既有 1020 已上传，不能重新上传同号）。本轮维持开发版本标识，以 Git 源提交区分，不把本轮 QA/无签名产物当新正式包。


### GitHub 实际发布回执（2026-11-01）

- 本地源码提交 `55b3c2dd99c60a3c211ffe2985505110167411f5`；通过已授权 GitHub 连接创建等价远端源码提交 [`14ae5c0b522cd33b6bf88ffe2d6a6eb7839a5140`](https://github.com/tangwu88/saydian-app-global/commit/14ae5c0b522cd33b6bf88ffe2d6a6eb7839a5140)。工具提交元数据不同，不伪称 commit SHA 相同；原本地历史保留。
- 独立分支 [`codex/client-audit-fixes-20261101`](https://github.com/tangwu88/saydian-app-global/tree/codex/client-audit-fixes-20261101)，父提交为既有国际源码 `26bc11ad...`。累计差异包括本轮修复以及原来未发布的审查/交接资料，没有推送国内仓库、移动 main 或覆盖 R12 分支。
- API 返回完整 tree `5a64955c8f210361405fac8b1bec122c837d4f16`，与本地源码提交完全相同；实际 fetch 后 `git diff --exit-code HEAD origin/codex/client-audit-fixes-20261101` 退出 0，远端 SHA 和 tree 再次一致。不是只比较文件数量。
- 已触发源码 push CI [`41252587354`](https://github.com/tangwu88/saydian-app-global/actions/runs/41252587354)，head 为上述远端源码提交。初次发布核对时（历史快照）UTC/Shanghai 两个 Harmony **主机契约** job 已 success，quality 已进入 pub get，Android/iOS 云端 job 仍待执行；因此不声称云端全量 CI 已通过。上述本机检查和构建结果是已执行证据。
- 本段及机器结果中的 Git 回执是后续文档提交，不改产品代码；云端 CI 的验收对象仍为源码 commit。最终以新文档树再次 fetch/diff 核对，并将当前本地分支跟踪到规范远端；旧本地提交另留 `codex/client-audit-fixes-local-20261101`，不 reset 或 force push。


### CI 终态与用户暂缓真机（2026-11-01 增补）

- 官方 API 实读源码 CI `41252587354` 已 `completed / success`，验收 head 为 `14ae5c0b522cd33b6bf88ffe2d6a6eb7839a5140`，完成时间为 **2026-11-01 07:48:21（Asia/Shanghai）** / `2026-10-31T23:48:21Z`。
- 五个 job 全部成功：quality、android、ios、Harmony contracts (UTC)、Harmony contracts (Asia/Shanghai)。此前排队/pub get 的状态只保留为过程快照，不再是当前结论。平台 CI/主机契约成功不是实体设备采集或 Harmony HAP 验收。
- 用户明确答复：“暂时无法连接，先完成代码、自动回归和 Git 提交”。因此本轮真机阶段按用户安排暂缓，不再要求现在连接手机；未执行新的覆盖安装、蓝牙、采集、SQLCipher 实机或美国同步验收，不将 XR 的其他 App 测试用于替代。
- 六项修复的源码、本机自动回归、两端构建和源码云端 CI 均已完成。原四条安全反例仍在普通测试内；新设备验收等手机可用时再安排。
- 本次增补只修改文档/汇总，不改变 `14ae5c0b...` 的产品代码；已核对 lib/android/ios/pubspec/workflow 差异为零，因此没有重复构建或重新触发完整 CI。补充记录独立提交 Git，最后核对远端与本地完整文件树。
