# 2026-10-18 国际版 iPhone 戒指同步接续

## 范围、现场与保护

用户要求开启 iOS 真机调试，分别验证 LuckRing / QRing 的设备读取、本地待传、美国服务器 ACK、回读及重复同步去重，发现问题立即修复。
用户随后选择先测试 QRing，并提供 U19S 资质文件；资质与两戒指验收分别记录，不扩大 iOS 活动/睡眠产品范围。

起始 HEAD `7aa515c4f5fc76bd89a70f1e212a3eabae0dfd2a`，本地分支 `codex/global-update-20261018`，跟踪 `origin/codex/ios-debug-restart-20261017`。
起始工作树干净，fetch / ff-only pull 成功，Already up to date；运行输入相对 `69e1ecf` 无差异，保留原分支及所有发布材料。
指定设备仍为 iPhone 15 Pro Max，UDID `00008130-001C098C2290001C`，实时 USB wired / iOS 26.6 / DDI available / Developer Mode enabled。

同一手机已有另一个 Say Ring Debug 会话，本轮没有中断其 Flutter/LLDB 或卸载其他 App。
Health 未运行时，通过 devicectl 将本 App 的 Application Support 复制到新私有目录：两个加密库共 540672 bytes，无 sidecar。
不解密数据库、不导出 Keychain、不回写旧副本，不清空账号、设备绑定或健康记录；没有覆盖安装。

## 现装 1019 的原生附加

devicectl apps 查询本轮多次成功但返回空列表（包括 include-all / 指定 Bundle），不能据此判断 App 不存在。
该 Bundle 的数据容器可读；按 Bundle 启动并核对 NSBundle，而非根据另一个 Runner 进程猜产品。

`devicectl device process launch --start-stopped cn.saydian.app.global --enable-dart-profiling --enable-checked-mode --verify-entry-points` 成功。
LLDB `device select` 指定 UDID、`device process attach -p 44228` 成功；临时 main 断点下读取实际 `cn.saydian.app.global / 1.0.1 / 1019`。
本机同步源码仍为 1018，因此不降级安装、不将旧源码注入 1019。临时断点已禁用并继续运行，安装路径与本轮启动结果匹配。

原计划复用的 `build/ios-debug-20261016-us/Runner.app` 和旧私有临时目录已经不存在，没有将其他历史包冒充当前包。
一次 Flutter attach 只到等待 VM 阶段，随即停止：本机工具源码确认 Debug attach 会初始化 DevFS / 同步 kernel，未对不匹配源码继续该路径。
没有发生该次 attach 的连接、文件同步、热重载或重启，不能报告 Flutter 热重载通过。

使用本 App 明确命名的 mDNS 服务，结合官方 iproxy 和现有 LLDB 接通 VM，不修改系统权限或安全配置。
直接运行 iproxy 的两次失败分别是缺少 loader library 路径、随后缺少 glue library；按 Flutter 自身做法设置三个 SDK library 目录后成功。
VM getVM HTTP 200 / main isolate 存在；实际 AppController 唯一、已初始化、已登录且不是预览，实际 API 实例为 `https://app.saydian.com`。
通过既有实例字段核对当前资料不是审核专用账号，不输出用户名、会话令牌或真实健康值。

独立 DevTools 本地服务 HTTP 200。面板打开请求未返回而主动终止等待，不声称已目视核对面板。
普通 Dart evaluate 因缺少当前 1019 的表达式编译服务失败；随后只读取 VM 对象字段、调用现有编译方法，不注入 1018 kernel。
原生 LLDB、专属 VM USB 转发及 DevTools 服务保持运行；本轮无 Flutter 热重载验收，不能当独立发布形态冷启动验证。

## 已发现并修复：QA 回读使用历史域名

P1 / 测试链路隔离问题：`ios_wellness_sync_qa_test.dart` 的 `_cloudIds` 写死旧 `.cn` 服务器。
美国 App/API 上传后，测试会将当前会话用于旧域名回读，既不能验收美国服务器又存在跨环境发送会话的风险；本轮没有运行这条旧请求。
这不是已证明的产品上传故障，也不是修改生产 API 的理由。

新增 `integration_test/support/health_sync_readback.dart`，统一使用 `GlobalEnvironment.configuredOrigin` 和已校验的 API resolve。
原测试改用该 helper，保持 metric、200 条分页、原始 opaque cursor、完整 ACK / 原内容回读 / 去重断言不变。
新增三个回归测试：美国隔离路径及查询、游标原值和编码、真实 QA 不可退回旧硬编码域名。产品源码和接口契约未改。

## 验证、失败与缓存清理

- 起始磁盘约 555 MiB。首次定向测试因 OS Error 28 / No space left on device 在编译文件复制阶段失败，退出 1；未计通过。
  首次 analyzer 只有 helper 的 null-aware lint，改用 Dart 空值感知 map 元素后消除，没有忽略规则。
- 确认当前仓库 `.dart_tool/flutter_build` 为可重建缓存、约 1.4 GB、lsof 无使用者。
  强制删除命令被工具拒绝而未执行；改用非强制、显式目录删除成功，仅删除该缓存。可通过构建重新生成，原始材料/签名/归档/安装包未删除。
  后续空间约 5.4 GiB；该读数包括失败测试收尾和其他系统变化，不把全部增加量归因于这一个缓存。
- `dart format` 本轮三文件 / 0 改动，`git diff --check` 通过。
  定向 3/3；最终 analyzer 零问题 / 2.9 秒。
- `TZ=UTC flutter test --no-pub --reporter expanded` 1108/1108 / 87 秒。
  `TZ=Asia/Shanghai` 同命令 1108/1108 / 64 秒。
  `python3 -m unittest discover -s scripts/release -p 'test_*.py'` 25/25 / 26.229 秒，均为夹具，不是真实发布或回滚。
- 本轮改动仅验收脚本/helper/测试与记录，没有修改产品二进制输入。
  未新构建 Android/iOS、执行原生 XCTest 或恢复鸿蒙构建；既有产品 CI 不冒充本轮真机业务结果。

## 实机业务边界

现装 App 注册了 veepoo / yucheng / urion / coolwear / qring 五个桥接通道，QRing 并非未注册。
通过现有 AppController 两次扫描均为空、未连接、无权限错误或控制器异常；不能因此确定是固件、路由或服务器问题。
已请用户先在其他配套 App 断开 QRing（不解绑/清库），返回国际版搜索页，再核对真实广播；不得假造设备或默认能力。
另行调用现有 QRing 桥接的扫描，Future 正常完成、原生返回空 List（0 设备），没有错误对象。
至少该次空结果并非“原生有结果、被上层路由丢掉”的证据；仍需排除其他配套 App 占用、戒指未广播和手机当前前台状态。
通过现装 API 的 `supportsDailySummaries()` 只读调用正常完成、结果 true，VM 最终复核仍 HTTP 200 / main 在线。
此能力证明不等于设备上传 ACK、记录存在或待传已清空；没有为了该检查发送任何健康记录。

尚无本轮 QRing / LuckRing 新样本，未得到本轮真实设备 ACK、美国服务端原内容回读或同 ID 去重闭环。
没有为验证而上传旧域名缓存、将审核账号用于戒指测试、生成虚假记录或改变原时间/数值/ID；待设备连接后继续。
App Store 现有审核、服务器部署、医疗功能边界本轮均未改动。提供的 U19S 资质核对另见设备资质记录。

私有设备 JSON、日志、原生调试输出、VM 地址与加密库留本机 0700 目录 / 0600 文件，不进 Git 或普通交接包。

## 继续：R12 发现缺口与修改前记录

接续基线 `c030bba`，当前分支已跟踪同名 origin 分支；工作树干净，fetch / ff-only pull 均无新代码。
指定 iPhone 仍 USB wired、开发者模式开启；只重新附加国际 App 原进程，实际 Bundle/版本仍为 `cn.saydian.app.global / 1.0.1 (1019)`。
同机 Say Ring 有独立 LLDB 会话，本轮未中断；本 App 首次激活恰逢附加暂停而超时，继续运行后重试成功。原生表达式首轮因未声明选择器返回类型失败，改显式类型后只读成功。
未恢复旧端口对应的 Flutter attach；仅复核原有本 App VM 端口仍 getVM/main 正常，重新建立其专属 USB 转发及 DevTools（HTTP 200）。未注入本机 kernel、未覆盖安装。

先后扫描存在前后台切换；再次明确前台等待完整 20 秒，控制器正常完成但结果仍为 0、无权限异常。
原生 CoreBluetooth state=5（poweredOn），原生扫描缓存实际 5 台；其中一台广播前缀 R12，被现有 Flutter/iOS/Android 名称规则同时遗漏。
用户明确回复已唤醒、且该 R12 就是本次 QRing 目标。其他附近设备的名称、UUID、广播内容不进入 Git。
系统已有 QRing 候选查询完成为 0；美国 `supportsDailySummaries()` 实际完成 true。
当前账号健康库 `pending()`（上限 200）返回 0；不是新 R12 上传成功的证明，也没有因此清队列、上传旧缓存或修改历史记录。

P1：搜索不到用户确认的 R12。复现为正常扫描 → 原生能发现 → 现有名称过滤拒绝 → App 0 候选；预期仅作为 QRing 候选进入，能力必须继续真实握手。
参考 Say Ring 的只读实现记录确认其已补 R12 路由，但不照搬通用 R 前缀、睡眠 AI 或监测设置扩展。
拟修改 Flutter / iOS / Android 三处同源名称策略，窄幅接受 R12 本名及 `_` / `-` 分隔后缀；保留 LuckRing 冲突优先级和其他未知型号拒绝。
新增 Dart 路由/去重回归、iOS Foundation 真执行夹具与 Android 原生用例。数据值、SDK 二进制、上传 API、iOS 功能范围不变；随后逐项追加实际检查结果。

现装源码差异已通过 VM 只读哈希核对：101 个本 App Dart script 中 82 个与当前 checkout 完全一致，19 个不同，包含控制器、UI、Urion 与 iOS 策略。
因此 1019 不能视为“1018 只改构建号”；本轮不以旧基线构建直接覆盖未知改动。当前其他已知本地 checkout 也未完整匹配，需定位该安装来源后再合入并做最终实机验证。

用户随后明确确认 1019 来自另一台电脑；尚未提供其源码目录、分支或包。只读 VM 源码用于哈希核对，没有重建/提交缺失的 19 个文件，也不以本机旧基线覆盖它们。

### R12 修改与已执行回归

- 改动前先新增定向断言，实际失败：`Expected WearableTransport.qring / Actual null / R12`，退出 1。
  随后三处策略均窄幅修复，普通 R 前缀、R120/R123、未知别名仍不放开；没有给名字赋予能力。
- `dart format` 两文件实际格式化，最终 `--output=none --set-exit-if-changed` 两文件 / 0 改动；`git diff --check` 通过。
  `flutter test --no-pub test/wearable_routing_test.dart test/qring_transport_test.dart test/ios_sync_qa_boundary_test.dart --reporter expanded` **31/31**。
- `flutter analyze --no-pub` 零问题 / 3.1 秒；全量 `TZ=UTC` **1109/1109 / 129 秒**，`TZ=Asia/Shanghai` **1109/1109 / 93 秒**。
  使用 `--no-pub --reporter expanded`；异常处理测试的受控错误日志不是现场产品错误或真实 API 请求。
- 八个 `test/native/*.m` 分别以 `xcrun clang -fobjc-arc -framework Foundation` 编译执行，全通过；新增名称策略 24 断言。
  `xcrun swiftc ios/Runner/WearablePayloadMapper.swift test/native/ios_wellness_policy_main.swift` 编译及执行通过。不是 iOS XCTest 或 SDK 实物握手。
- Android 实际 `RingNamePolicy.java` 加私有无凭据夹具以 JDK17 `javac` 编译、`java` 真执行 **24 检查通过**。
  首次误在 javac 完成前执行，报 ClassNotFoundException；等待编译退出 0 后重跑通过。不是 Android 原生 JUnit、APK 或 BLE 验收。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'` **25/25 / 22.368 秒**，仅发布夹具，不是生产发布。

### 构建检查与安装停线

构建前保留本机旧 1014 `Runner.app`（约 171 MiB）到私有目录；原发布 archive/IPA 与手机 1019 不动。
本轮只使用当前仓库 1018 基线作编译检查，正常 `lib/main.dart`、`.com` API/更新地址、禁用未配置推送、`--no-pub --no-codesign`；不是可安装/分发版本。
Xcode27 编译复用私有 `XCODE_XCCONFIG_FILE` 的最低 15.0 兼容设置，没有修改跟踪的产品最低系统版本、签名或 App Store 归档。
Debug 实际成功，Xcode 100.9 秒，Bundle `cn.saydian.app.global`、build 1018；Runner SHA256 `cd7888a528ad62bdc140da90c971f424a4823ade0605cd9a03de7d37efc1426f`。
Profile 实际成功，Xcode 105.0 秒、约 64.4 MB，同 Bundle/build，Runner SHA256 `30d3ff4c22ea0d751fa8d381fdea8520183220f280f967af3fbf7bb8ec11a36f`。
两个编译结果均为 1018 基线无签名检查，未覆盖手机。原生 XCTest 因不能覆盖未知 1019 或其账号现场，本轮不执行；未构建鸿蒙、未执行 Android 真机测试或商店上传。

Android 原生首次 `./gradlew :app:testSideloadDebugUnitTest :app:testPlayDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline --max-workers=1 --console=plain` 失败。
Gradle wrapper 原锁定 9.1.0 不在缓存，正常从官方分发站下载；离线随后因 Kotlin DSL plugin 6.2.0 缺缓存失败，不是 R12 测试断言失败。保持依赖版本不变，在线重试同一任务。

在线重试约 5 分钟仍未执行到原生测试。通过 stdout 文件核对本轮 Gradle client 后，仅对该 client 发 SIGINT，退出 130，未终止共享 daemon 或其他项目。
随后显式请求两个原生测试任务及 `:app:assembleSideloadDebug :app:assembleSideloadRelease`，双 ARM、QA Release、禁用未配置推送，离线重试 12 秒失败。
实际阻断为 `:camera_android_camerax` 的 `com.android.tools.build:gradle:8.13.1` jar 缺缓存，另有项目评估监听器 NPE；没有修改依赖版本绕过。
本轮 Android 完整原生测试、Debug/Release APK 均未产出/通过；仅前述实际 Java 策略检查通过。待恢复依赖后重跑，不能用它替代完整平台或设备验收。

调试面板打开返回 queued，不计目视页面验收。主机回归期间 VM 请求超时，之前曾观察 App 进入后台，不据此确定故障原因。
收尾 CoreDevice 仍确认原 1019 相同进程/安装路径存活；旧 VM 端口随后 connection refused，重新激活 App 成功但未发现新的专属 mDNS 服务，完整 Flutter Debug/热重载未恢复。
原生 LLDB 附加不等于 VM 当前可达或业务通过；没有为了恢复调试将 1018 注入/安装到 1019。

### 用户改为先更新本地

用户随后要求“先更新本地代码到最新”，本轮先停止安装/闭环后续流程，保存 R12 最小修复和真实测试边界，再同步当前跟踪分支。
重新 fetch 并核对所有 origin heads；已配置远端仍以 `c030bba` 为最新日期提交，当前跟踪分支没有新增内容。`origin/main` 为历史 `ada5df2`，不能按分支名将旧代码合并成最新。
保留全部本地改动为 checkpoint 后再执行 ff-only pull；不强推、不重置、不覆盖手机。另一台 1019 的源码/分支尚未出现在已配置远端，需该电脑推送真实修改后再同步。
