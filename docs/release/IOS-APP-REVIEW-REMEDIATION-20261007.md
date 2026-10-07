# SAYDIAN Health iOS 审核整改核查

## 当前状态与边界

2026-10-07 已实时读取 Health App Store Connect，App ID `6817980969`。
正式 `1.0.0 (1012)` / 提交 `2e3a3a88-babc-4310-ab78-e6db4ca02ca3` 为等待审核，没有已显示的拒审消息。
最新 TestFlight `1.0.1 (1013)` 为处理完成、正在测试；不是正式商店通过。

修改前国际分支 `codex/global-device-admin-20261001` 工作树干净，fetch / ff-only pull 无更新。
基线 `ca81486540ea3dd40c6cece417939c8567052d17`；保留旧 IPA、归档、素材及所有健康记录。
不修改 Say Ring、服务端、API 契约、签名或地区；安卓真机测试与鸿蒙构建保持停止。

## Say Ring 参考，不冒充 Health 的拒审

来源：另一个任务“导入赛电戒指 App”的实际审核记录，以及它的 `SAY-RING-IOS-WELLNESS-1062-20261007.md` 和 `APP-REVIEW-NOTES-1061.txt`。
Say Ring 1061 在 2026-10-06 遇到 1.4.1：硬件监管审批、准确性验证材料，以及商店描述中的就医提醒。
其更早记录还有 2.1(a) 登录问题和 5.1.2(i) 第三方 AI 明示授权问题。

两张苹果附件未取得，不推断截图具体内容；Say Ring 的账号、视频、硬件范围及未完成的 1062 不能作为 Health 的验收证据。
官方核对：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)，2026-10-07 读取 1.4.1、5.1.2(i)。
免责声明不替代准确性或监管证明，也不能保证一次通过。

## Health 实际风险

- P1：通用 AI 的 `AiChatPage → AppController.sendAiMessage → GlobalSaydianApiClient.sendAiMessage` 没有独立的数据目的地/供应商披露及授权。
  只读检查服务端主线 `6910b5a` 的 ContentService，消息可转发至配置的 AI；具体线上供应商未核实，不能编造。
  隐藏的健康付费报告授权不等于通用聊天授权，登录协议也不能替代第三方 AI 授权。
- P1：设备能力可打开血压、血糖、心电等生理功能；`health_interpretation.dart` 有疾病风险字段及读数范围解读。
  本仓库的已检查发布/设备资料未找到型号对应监管及准确性材料；不宣称全电脑无此材料，不把 SDK 文档或同步测试当医学验证。
- P2：原 `healthDisclaimer` 仅在用户不适时提示咨询专业人员，缺少作医疗决定前先咨询医生的明确提醒。

登录对照：Health 的 GlobalAuthPage 当前默认邮箱/密码，登录不显示验证码字段；API 解码接受 HTTP 2xx，服务端主线 envelope 的业务成功码为 200。
不套用 Say Ring 的旧登录错误或改动 Health 协议；这只是源码/公开契约检查，不是本轮真实审核账号登录验收。

## 本轮可独立实施的补齐

修改九个 ARB（八种用户语言及中文回退）和生成的运行时资源，补上非诊疗、医疗决定前咨询医生及不适就医提醒。
新增本地化回归，核对每种运行时文案与 ARB 一致。仅文案变化，不改读数、阈值、设备命令、记录或上传行为。
提示资源跨平台共用；此次不改变 Android 的业务功能范围。外语人工母语校审尚未执行。
现有健康页与 AI 空态使用该统一提示；不能据此声称 AI 授权问题或硬件合规已解决。

## 必须先选定的产品范围

用户随后回复“按推荐方案来执行下面工作”，已授权苹果首发收敛为活动与睡眠，关闭生理测量、风险解读及 AI，旧数据保留、Android 不变。
执行范围对全部 iOS 用户及构建生效，不使用审核账号判断、服务端开关或审核后恢复功能。
若选择保留生理功能，需要对应真实型号、实际销售地区的监管与准确性资料，以及可核验的 AI 供应商/独立授权说明。

若选定活动与睡眠范围，需同时改 UI、控制器、原生桥接、缓存读取、待上传队列、关爱及通知路由；不能只隐藏首页或仅对审核账号隐藏。
所有修改、截图及审核说明必须与最终新构建一致，原始健康库不可删除，不在批准后静默恢复功能。

### 授权后的实施轮次

- Bug / P1：首页隐藏不能保证活动与睡眠范围。旧记录详情、关爱、消息、设备命令和补传仍能触发生理功能及 AI。
  复现：有旧生理数据的账号打开历史，或断网恢复后重试上传。预期：iOS 只访问真实活动/睡眠数据；实际：当前代码仍处理全指标。
- 涉及文件：新增统一 iOS 范围策略；控制器、设备桥接/原生、队列查询及上传、相关页面和回归测试。
  原因：需要在数据和命令边界执行限制，不改 API 契约、不删除数据库、不改 Android 功能。
- 修改前已 fetch 核对 origin，基线仍为 `ca81486540ea3dd40c6cece417939c8567052d17`。
  已有文案和测试改动完整备份至 `/private/tmp/health-ios-wellness-prechange-20261007.xzJyyT`，没有覆盖或拉取脏工作树。
- 当前空间仅约 2.2 GiB，另一任务正在使用同一 iPhone 做 Profile 验证。先完成代码/主机测试；不抢占手机、不清理其缓存或归档。
- 初次桥接检索使用不存在的 `routed_wearable_bridge.dart`，重查实际文件 `wearable_routing.dart`；不据此认定桥接缺失。

## 英文公共安全文案（草案）

SAYDIAN Health is intended for general wellness reference, not diagnosis, treatment, emergency services, or medical decision support. Consult a doctor before making any medical decisions. If you feel unwell, seek medical care.

完整商店描述、硬件列表及审核步骤待产品范围和最终构建实测后定稿；不写“已关闭/已验证”而实际尚未实施。
审核凭据仅保留 Apple 受保护字段，不记录到 Git。保留真实邮箱/密码登录步骤，不照抄 Say Ring 的 OTP、最低年龄或无登录模式。

## 执行与待验

- 已读 AGENTS、国际交接、最新维护记录、复盘和完整回归清单；已核对另一个任务的实际反馈。
- 公共 `/global` auth/capabilities 为 200，协议版本 `global-appstore-2026-10-02`；仅公开能力检查，未登录或调用 AI/测量接口。
- 初轮检索遇到不存在的文件/路径和 zsh 无匹配模式，按实际路径重查；没有据此修改代码或认定功能缺失。
- Say Ring 有独立 iOS Profile 编译占用，未与其并发构建或清理缓存；当前空间约 7.3 GiB。
- 本轮格式、静态检查和测试结果在执行后追加；新版本号、签名 IPA、真机、新构建上传、截图及正式重新提交均尚未执行。
- 旧正式审核未撤回，TestFlight 1013 不重复上传。本记录不是重新送审或批准回执。

### 第一轮主机验证

- `flutter gen-l10n` 成功；`dart format test/global_l10n_test.dart` 1 文件有格式变化；`git diff --check` 通过。
- `flutter test --no-pub test/global_l10n_test.dart test/health_interpretation_test.dart --reporter expanded`：16/16 通过。
- `flutter analyze --no-pub`：零问题，6.4 秒。
- 首轮 `TZ=UTC flutter test --no-pub --reporter expanded`：1011 通过 / 1 失败，79 秒。`ui_shell_test.dart:359` 首页紧凑提示高度实际 69、要求 <=60。
  不是原始读数或同步错误；新中文文案过长。保留三项完整提醒，将“穿戴设备/日常/不用于/及时”等措辞精简，未放宽测试、减小字体或隐藏提醒。
- 首轮命令以 `&&` 串行，UTC 失败后 Asia/Shanghai 未运行，不算双时区通过；原始失败日志保留 `/private/tmp/health-review-20261007-utc.log`。

### 第二轮主机验证

- 重新生成运行时资源，`flutter test --no-pub test/global_l10n_test.dart test/ui_shell_test.dart --reporter expanded`：71/71 通过，6 秒；原 <=60 高度断言保持不变。
- `dart format --output=none --set-exit-if-changed test/global_l10n_test.dart`：0 改动；`git diff --check` 通过。
- 第二轮 `flutter analyze --no-pub`：零问题，4.8 秒；完整双时区回归结果在结束后追加。
- 第二轮 UTC 全量：1012/1012 通过，67 秒；Asia/Shanghai 全量：1012/1012 通过，73 秒。
  日志分别为 `/private/tmp/health-review-20261007-utc-r2.log` 和 `/private/tmp/health-review-20261007-shanghai-r2.log`。
  部分负向夹具打印预期异常，不是测试失败；不把此计为真机、原生桥接或监管准确性验收。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：25/25 通过，16.322 秒。
  门禁打印的发布成功、锁冲突、坏哈希及回滚文案均为本地模拟夹具，未实际部署、发布 APK 或改变线上清单。
- 本轮不卸载或驱动 iPhone，不生成签名包。未完成原生及构建矩阵，不以此次主机检查代替新版本的完整送审验收。
- 本轮代码和草案保留本地；功能范围未选定、完整发布验收未完成，因此未提交/推送源码、未修改 Apple 送审字段、未撤回旧提交。

## 活动与睡眠版实施（用户授权后的第二阶段）

- `IosWellnessPolicy.current` 对全部原生 iOS 账号和构建固定生效；无服务端、账号、审核或 Release 专用开关。
  仅允许 steps / distance / calories / sleep。Android 和 Web 不改变原业务范围。
- 首页、历史/详情/趋势、运动、关爱、通知、设备设置、AI 与健康报告入口使用同一策略；直接路由不能打开旧生理数据、AI 或 StoreKit 健康报告购买/恢复。
- 控制器、Routed/Yuc/Urion 桥接和原生入口拒绝生理测量、监测配置、预警与 ECG；活动、睡眠及设备通用设置保留真实能力门禁。
  Veepoo 原生不再读取/映射专门的生理历史表；第三方二进制及原始 SDK 保持只读。
  Veepoo 仍使用厂商组合历史读取 API，不能断言其内部 BLE 传输完全不包含生理字段；App 输出、存储新数据和上传在独立边界过滤。
- iOS 旧库保留、不迁移/删除/重写。显示与发送使用只读投影，去掉睡眠评分/风险、生理伴随字段、波形和运动心率；原时间/单位/来源/记录 ID 保持原值。
- 待传 SQL/内存查询在 limit 前筛选允许指标，防止旧生理队列阻塞活动记录；旧生理行保留待传、不伪报成功。
  ACK 只认本批实际提交 ID；投影不能覆写原历史行。日汇总用相同投影视图比较，旧附加字段不制造重复版本。
- Global HTTP 在发送前阻断 AI、文章库、报告、预警、ECG 及非活动/睡眠查询；关爱权限直接 API 也过滤，不依赖页面隐藏。
  国际 `/global` 路由及服务端契约未改。
- 2026-10-07 Chrome 实时核对 TestFlight 最新为 `1.0.1 (1013)` 处理完成/正在测试，因此本地新候选使用 `1.0.1 (1014)`。
  此时仍未上传 1014、未撤回旧正式审核、未修改正式商店版本；不能以版本号变化当提交成功。

### 磁盘、失败与修正

- 大型源码补丁首次因空间从约 2.2 GiB 降到约 116 MiB 失败，检查后确认未写入该补丁。
  仅删除本仓库无人持有的 ignored `.dart_tool/flutter_build`（约 1.6 GiB，可重建）；签名、归档、安装包、原始素材及其他任务缓存未删除。
  随后外部清理使可用空间恢复至约 21 GiB；不将此全部记作本任务清理成果。
- 首轮 analyzer 依次发现 5/1/2 项样式或无用导入提示，按实际行修正；后续零问题。
- 功能范围首轮 UTC 全量：988 通过 / 24 失败（89 秒）。旧 iOS 报告购买/生理上传夹具与新范围矛盾；模拟页面控制器缺新属性。
  修正 iOS 测试预期为不调用 API/SDK/StoreKit，允许指标使用 steps；原 Android 购买与旧平台功能测试保留。
- 定向首轮 93 通过 / 3 失败（6 秒）：新增 Widget 测试在 framework invariant 检查后才重置 platform override。
  将重置移入 try/finally；新增范围测试第二轮 9/9、Foundation 原生策略可执行测试通过。
- 全量第二轮 UTC 1022/1022（41 秒）、Asia/Shanghai 1022/1022（72 秒）通过；负向夹具的异常打印不是失败。
  日志 `/private/tmp/health-wellness-20261007-{utc,shanghai}-r2.log`。此轮后又补了命令/权限/去重边界，最终源码须再跑。
- `flutter build ios --debug --no-codesign --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功，Xcode 73.3 秒。
  厂商 SPM/WechatOpenSDK arm64 模拟器警告保留。开始前未检测到编译；启动后另一个 Say Ring 任务又开始独立 Profile 构建。
  没有清理共享 DerivedData 或终止另一个任务；后续 iOS 构建串行错开。Debug 编译不代表签名、安装或真机通过。

最终双时区、跨端构建、原生执行、保留数据覆盖安装及正式包/送审资料验收继续追加；未执行项仍为待验。

### 补充边界与设备验收准备

- 补充 Routed stopMeasurement、GlobalCare 直接权限发送、旧通知详情加载及日汇总投影比较；增加直接路由生理校准页保护。
  历史睡眠评分等额外字段不会导致相同活动/睡眠内容生成新版本；旧行原内容保留。
- 新定向边界测试首轮 11/11 通过。日汇总夹具首次使用不存在的 `copyWith(metric:)` 参数，导致两个文件加载失败；改用实际 JSON 解码构造原始夹具，随后两文件 29/29 通过。
- 新真机脚本不使用预览代替登录、不发送生理测量/AI请求。仅对允许指标做真实同步、ACK、带 metric 过滤的分页服务端回读、两次重试及旧行/旧待传指纹比较。
  全页脚本切换英文并在结束后恢复原语言；截图只输出 ignored 私有目录，不纳入 Git 或公开审核资料。
- 脚本新增过程中 analyzer 先发现 null-aware map entry，再发现 import alias 风格；分别修正，第三次零问题。
  此前 `r5` 双时区各 1025/1025 通过（UTC 58 秒 / Shanghai 66 秒）；增加直接校准页保护后最终 `r6` 双时区另跑，不把 r5 当最终代码。
- 完整发布 Python 25/25 通过（14.751 秒）；Swift Foundation 范围可执行测试通过。模拟发布日志不等于线上写入。
- 签名 Profile QA 构建成功（183.7 秒，约 63.5 MB）。复制到 `build/ios-wellness-1014/profile-qa/Runner.app`，严格签名校验、Bundle ID、1.0.1/1014 回读通过。
  此 QA 二进制编译早于最后的校准页防御性保护；不是最终 App Store IPA，也不用于宣称最终源码全部实测。
- 只在 iPhone 15 Pro Max 的国际 App 容器读取/复制现有加密健康数据库至私有 mktemp（权限 600），不导出密钥、登录 Token 或明文记录。
  `devicectl` 覆盖安装上述 Profile 成功；启动前再次复制，`cmp` 退出 0，当前加密库字节完全一致。未卸载、清库或改用其他手机。
- Say Ring 任务不断启动同一手机的测试及独立 checkout 的构建，因此本任务暂未启动 Profile 用例，不抢占其当前手机会话。
  不中断别的进程、不清共享缓存；本仓库 iOS Debug / Profile / Archive 串行，跨仓库外部构建并发事实保留。
- Android sideload Debug/QA Release/原生测试链已启动，只是跨端编译回归，不恢复 Android 真机测试或鸿蒙。Debug 正在解析 Gradle 依赖，尚无成功回执。
- 英文商店及审核草案已保存为 `IOS-STORE-COPY-1014.txt`、`IOS-REVIEW-NOTES-1014-DRAFT.txt`，未声称医学审批或准确性验证、未包含账号密码。
  初拟 `/global/legal/privacy` 与 `/global/legal/terms` 实测 404，已纠正；由真实 support/footer 查得 `/global/privacy-policy`，实测 200。
  support 实测 200；协议仍由 App 内正式 `global-appstore-2026-10-02` 文档访问。公网读取工具无法访问该站时，使用无凭据公开 HTTPS 检查；没有规避证书或认证。
- Production IPA 归档正在执行，待签名、权限、版本及 SHA-256 核查；旧正式审核未撤回、Apple 字段未修改、1014 未上传。

### 最终源码主机与正式候选包

- r6 全量 UTC 1026/1026（81 秒）、Shanghai 1026/1026（77 秒）。随后发现 EB1 自动心率/血氧配置命令 `0x16` / `0x2c` 仍需封住；Dart 与 Swift 同时补齐拒绝列表，并增加原生和 Dart 回归。
  首个 Production archive-r1 在此修正之前生成（190.5 秒，IPA 导出 8.2 秒）；已独立保留，不作为最终上传候选。
- r7 最终源码全量 UTC 1026/1026（54 秒）、Shanghai 1026/1026（79 秒）；analyzer 零问题（2.6 秒），Swift Foundation 可执行策略测试通过。
  日志 `/private/tmp/health-wellness-20261007-{utc,shanghai}-r7-final.log`；不是原生 SDK 全套 XCTest 或真实手表验收。
- 最终源码 Profile QA r2 成功（155.6 秒，63.4 MB），保留 `build/ios-wellness-1014/profile-qa-r2/Runner.app`。
  第二次覆盖安装前后私有加密库副本 `cmp` 退出 0；未卸载、清库或导出凭据。之后 `flutter drive --profile --keep-app-running --use-application-binary=...` 已连接实际 iPhone 的 VM Service。
- Production archive-r2：`SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功。
  Xcode 63.2 秒，归档 251.7 MB，App Store 导出 7.7 秒，IPA 37.4 MB；独立保留 `build/ios-wellness-1014/archive-r2/Runner.xcarchive`。
  正式 IPA `build/ios-wellness-1014/SAYDIAN-Health-1.0.1-1014.ipa`，SHA-256 `53e83157eaf8a28817e87afa4c109b2fea86c8daddfe1fc15d07d40a338b0cb1`。
  `codesign --verify --deep --strict` 成功；Bundle ID `cn.saydian.app.global`，团队 `W7SXQ4A226`，构建 1014，UIDeviceFamily 仅 1，`get-task-allow=false`。
- 从同一最终归档用既有 `ios/ExportOptions-AdHoc-iPhone15pm.plist` 导出：EXPORT SUCCEEDED，保存 `build/ios-wellness-1014/adhoc-r2`。
  未把 QA 二进制、旧归档或 Debug 包冒充 App Store 成品。正式候选尚未上传或安装验收。
- 官网实际页脚确认 `https://app.saydian.cn/global/terms` 返回 200；客服、隐私和协议三个实际公开地址均已核对，修正草案中的猜测 URL。
  Apple 仍显示旧 `1.0.0 (1012)` 等待审核，旧关键词含 heart rate、旧截图 `global-dashboard-appstore-v2.jpg`；尚未改变 Apple 字段或撤回提交。

### 真机脚本失败与修正（不是生产通过）

- r2 首个页面用例在首页 `pumpAndSettle` 超时（00:24），没有取得完整逐页通过证据。真实同步进度可持续动画，不能要求所有背景动画完全停止。
  将脚本等待改为 15 次 200 ms 的路由帧等待，仍检查框架异常、真实页面和独立同步断言；不取消同步/ACK/保留数据检查。
- 随后检查发现第二个同步用例传入 `allowAutomaticWearableRestore=false`，而控制器该配置同时禁止显式恢复方法；这是测试夹具错误，不是自动连接的生产缺陷。
  去掉该测试构造参数，加连接恢复 90 秒边界和不含账号/记录/健康值的阶段日志；将重新构建 Profile QA r3 并重跑。
  正式 archive-r2 的生产代码未因上述脚本修正改变；失败原始日志保留 `/private/tmp/health-wellness-1014-device-qa-r2.log`。
- Android 依赖解析期间检查到缓存文件继续下载，未清理共享 Gradle 缓存或更改证书/代理；此时仍无 Debug/Release/原生测试成功回执。

后续实机结果、最终 Debug/原生矩阵、截图更新、Apple 处理和提交状态须继续追加。没有通过证据的项目仍是待验。

### 实机 r3、隐私纠错与进一步回归

- Profile QA r3（仅测试脚本修正）成功，66.8 秒 / 63.4 MB；覆盖安装前后加密库字节一致。
  `--keep-app-running` 实机 VM 成功连接，取得首页、通知、关爱及 steps/distance/calories/sleep 详情访问日志；不是所有页面通过。
- r3 页面用例在 All health data 入口失败：tap 命中警告，预期离开主导航但仍在原页（01:16）。
  定位脚本在滚动后未等布局完成就点击；改 `Scrollable.ensureVisible(..., alignment:0.4)` 并 pump 一帧，保持导航成功断言不变。
- r3 同步用例实际连接恢复成功，但首次同步后 `CloudHealthSyncState.pending`，未达到 complete（01:35）。
  不把配对、设备读数或本机保存当服务端确认，不标记为通过。新增只打印 HTTP 状态/安全错误代码、批量提交/ACK/拒绝数量和允许队列数量的诊断；不输出 Token、记录 ID 或健康值。
  未查明原因前不改读数、伪造 ACK 或更改服务端协议；r4 新脚本将继续核查。
- r8 主机全量 UTC 1026/1026（104 秒）、Shanghai 1026/1026（114 秒）。随后新诊断代码的 `ApiException.code` 为 Object，analyzer 报一项类型错误；改字符串化后 r12 零问题（7.2 秒）。
- 最终源码 iOS Debug 编译成功（145.2 秒）；独立 `build-for-testing` 显示 TEST BUILD SUCCEEDED，RunnerTests 编译通过但本轮未在设备执行 XCTest。
  Foundation 策略可执行检查不是完整 SDK 原生测试替代。新建 derived 路径而非清理别的任务。
- Android sideload Debug 成功（1503.2 秒）；QA Release 成功（286.7 秒，68.3 MB），双 ARM 编译。不是正式 Android 上架包，也没有恢复安卓真机测试。
  原生 Gradle unit-test 链仍执行中；SDK XML/Kotlin 迁移及已弃用 API 警告保留，未通过改业务绕过。
- 新增与真实验收完全分离的无数据 UI 截图宿主：只渲染实际生产页面，不读取手机的安全库/健康库，不编造能力、连接或健康值。
  首轮 analyzer 发现 profile 属性名及 WearableEvent 导入错误；分别修正为实际 memberProfile / models 导入。
  首次手机截图用例失败（00:02）：缺 GlobalLocaleScope 导致空值异常；补内存语言 Scope，不改生产页面。未把失败截图当商店素材。
- Chrome 实时发现 Apple 原申报把健康、健身、头像、客服和标识符写成不关联账号；账号授权同步/头像上传/推送注册实际均与账号关联。
  依据源码和 Apple 官方 [App privacy details](https://developer.apple.com/app-store/app-privacy-details/) 的定义，已发布纠正：健康、健身、照片/视频、客服、其他用户内容、用户 ID、设备 ID 为关联身份且 App 功能用途；头像同时保留个性化，无广告追踪用途。
  新版隐私 URL 已保存为已验证的 `https://app.saydian.cn/global/privacy-policy`。Chrome 发布后回读确认，而非仅点击提交。
  证据 `/private/tmp/health-1014-apple-proof/privacy-corrected.png`；原其他数据类别仍保留，未宣称完成所有闭源 SDK 的数据流审计。
  页面编辑曾遇发表刷新未完成导致下一项未打开；重新读取状态后单项完成，不盲目重复发布。
- 当前旧正式 1012 审核仍未撤回，1014 未上传/未重新审核，外部试用仍是原 1013，不将隐私编辑算作新版本提交。

### 真机 r4–r6 与非生产诊断

- r4 Profile QA 构建 101.0 秒，页面用例通过（04:07），当前可访问页面完成截图与框架异常检查；不等于资料保存、账号删除、OTP、购买、设备设置及所有型号验收。
  私有目录 `page-screenshots-r4` 共 30 张 PNG，包含两个独立空状态截图；资料及真实健康截图没有公开、上传 Apple 或纳入 Git。
- r4 实际同步用例失败（04:26）：鉴权能力 HTTP 200、真实设备恢复成功、日汇总支持为 true，但三次批量各提交 3 / 接受 0 / 拒绝 3，允许队列仍为 3、状态 pending。
  不伪造 ACK、删除旧行、更改记录编号或将失败记作完成。服务端确认、再次同步去重和旧行指纹比较未走到验收断言。
- r4 独立公共空态用例通过（04:31），随后发现两张截图字节一致：测试宿主没有监听控制器页面切换。
  补 `AnimatedBuilder` 和 Watch AppBar 断言；原错误的 Watch 截图不能用作商店素材。
- Android 原生 Gradle 结果实际完成：五个 XML 中共 22 tests，0 failures/errors/skips；VeepooBatteryReadGate 7、WatchFaceProfile 5、WearableRecordTimezone 3、UrionGattDrain 6、PrivateStageLog 1。
  Android Debug/QA Release 与上述主机测试不是 Android 真机验收，也不是 Google Play 正式签名上传。
- 新增仅测试的 HTTP 回执诊断：保留原响应字节、只统计白名单拒绝代码和状态，不打印记录 ID、读数、服务端消息、账号或 Token。
  r14 analyzer 因构造器 super parameter 样式提示中止，Profile 未运行；修正后 analyzer 零问题（2.5 秒），Profile r5 34.6 秒成功。
- r5 覆盖安装前后加密库 `cmp` 为 0；真实同步用例在测试直接 HTTP 能力检查返回 401 处失败（00:02），没有取得拒绝代码。
  直接请求绕过了生产客户端的过期 Token 刷新。改为实际 `supportsDailySummaries` 调用，保持鉴权和能力要求，不放宽上传完成断言。
  r6 analyzer 零问题（2.8 秒），诊断 Profile 35.2 秒成功；安装前后库一致；生产客户端实际能力回执 HTTP 200 / dailySummaryVersions=true。
- r5 公共空态截图用例通过（00:07）；`01-activity-sleep-empty.png` 与 `02-connect-watch.png` 哈希不同，Watch 页面已人工查看。
  该宿主使用无凭据内存账号/空健康库及实际生产 UI，不连接设备、不读取真实账号，不是登录或硬件同步证据。

### 关爱标题 P2 与最后回归

- Bug：从首页进入 Family care，外层导航标题与页面内标题重复。预期只显示一次并保留返回和 Manage 入口；实际两个同名标题，P2。
  修改 GlobalCarePage / CarePage 增加显式 `showTitle`，iOS 首页及个人页的已带导航标题路由不再显示内层标题；独立页面及 Android 默认行为不变。
  不改关爱数据、账号隔离、授权或 API。修改前再次 fetch，HEAD 仍为 ca814865；完整 tracked patch 与五个原文件保留于私有 `health-care-title-prechange.u81hzF`。
- 新定向测试首轮 14 通过 / 1 失败：测试误写本地化按钮为 Manage care，实际资源是 Manage；按已存在资源修正断言，未改变生产文案或放松标题唯一性要求。
  最后全量双时区与构建需在此 UI 源码变更后重跑；旧 archive-r2 不能再作为最终候选。
- 诊断 r6 构建期间发生上述 UI 源码改动，因此 r6 只用于上传诊断，不声称关爱标题最终二进制已验。最终生产归档须重新生成。
- 本轮查询曾误用不存在的测试/脚本名称，且一次在服务端 cwd 查 App 文件；纠正实际路径后读取。服务端仅用 git show origin/main 只读检查最新校验和幂等逻辑，未修改或部署。

尚未上传 1014、未重新提交正式或 Beta 审核。已发布的 Apple 隐私纠错与新构建提交分别记录。

### 最新完整主机结果与真实拒绝原因

- 关爱标题修正后 r9：UTC 1027/1027（90 秒）、Asia/Shanghai 1027/1027（102 秒），全量通过；analyzer r16 零问题。
  `git diff --check` 通过。发布 Python 25/25 通过，其成功/失败发布文案仍为受控模拟，没有实际部署或提交商店。
- Android r9：sideload 双 ARM Debug 103.8 秒成功，QA Release 52.8 秒成功（68.3 MB）；Gradle 14 秒成功。
  `testSideloadDebugUnitTest` 本次 UP-TO-DATE，复用本轮已实际执行的 22/22 原生结果；原生源码未在关爱 UI 修正中改变，不声称重新执行了 22 项。
- r6 同步用例在真实设备恢复后的 ready 等待 120 秒失败（02:03），未达到可同步状态；公共空态用例通过（02:08）。
  不是服务器能力失败，也不能用旧 r4 的连接成功冒充本次连接通过。
- r7 诊断 Profile 41.2 秒成功、安装前后加密库一致；不依赖蓝牙先上传现有允许队列。
  实际 `/global/api/saydian-app/v2/health/records/batch` HTTP 201，拒绝代码明确为 `future_time: 3`，submitted=3 / accepted=0。
  服务端校验在测量时间超过服务器当前时间 10 分钟时拒绝；没有证据支持此前的 record_conflict 假设，未按猜测修改质量或编号。
  旧记录原时间和值保留待传，未回写时间、制造 ACK、放宽服务端校验或新增同值新 ID。
- 新增仅测试的汇总时间诊断：HTTP Date 对手机时钟偏移分钟、未来时间区间和日汇总数量；不输出任何具体记录日期、ID 或读数。
  接下来区分手机时钟、设备原始时间和转换错误；未查明之前不声称修复或已通过上传闭环。

### r8 / r10 根因确认、关联日期修正与源码冻结

- r8、r10 真实回执均 HTTP 201 / `future_time:3` / accepted=0；HTTP Date 对手机偏移为 0 分钟，3 条均在未来 24 小时内，均为非日汇总旧行。
  r10 再确认 `legacyNoonMarkers=3`：符合旧版 steps/distance/calories、无 aggregation、所在时区 12:00:00 标记。
  r10 蓝牙恢复后 120 秒仍未 ready，同步用例失败（02:05），独立公共空态截图用例通过（02:09）；不称整套通过。
- P1 根因：Veepoo 的日 Step/Dis/Cal 只有所属日期，旧客户端自行补今日中午作为测量时间，凌晨因此触发服务端未来时间拒绝。
  `AppDelegate.swift` 读取时只捕获一次真实 `Date()`，日汇总经 `WearablePayloadMapper.activityDailySummary` 标记所属 localDate。
  SDK 无具体睡眠时间时也用日归属/真实读取时刻，不再补中午；有 `SLEEP_TIME` 时保持真实 SDK 时间。原值、原库、原队列 ID/时间未改写或删除。
- 桥接当次按设备/指标/日期去重；持久化复用既有不可变日汇总版本机制，内容不变不产生新版本。
  新 Foundation 回归实编译并分别在 UTC / Asia/Shanghai 执行通过；RunnerTests 增加对应测试，完整 SDK XCTest 仍未执行。
- 展示按 SDK 所属日期排序、画图、显示日汇总，不把读取当天误作历史日，详情/趋势列表/关爱卡片不展示人工 00:00 时刻。
  iOS 对超过当前时间 10 分钟的允许记录仅隐藏显示，运输和原队列仍保留原始时间；没有伪造成功 ACK 或自动修复旧时间。
  Android 常规点记录显示与功能范围不变；跨端 canonical 日汇总日期展示也跟随真实归属日。
- r20 analyzer 发现健康卡片 nullable 引用两项错误；改成本地 record 变量供 Dart 提升，r21 零问题（1.9 秒）。
  日汇总/策略/排序/分析定向 26/26；r10 主机 UTC 1027/1027（70 秒）、Shanghai 1027/1027（84 秒）。
  后续日显示/未来显示策略回归增加后 r11 UTC 1030/1030（62 秒）、Shanghai 1030/1030（76 秒）。
- 末轮日汇总标题测试首次 31 通过 / 1 失败：趋势页默认展示今天，固定 September 30 的测试样本不在该期且列表未滚到记录。
  仅修正新测试为趋势当天归属日、详情固定历史日，并滚动检查日期字段；未改生产周期过滤或放宽断言。
  r2 定向 32/32 通过（1 秒），格式化 5 个文件仅关爱页有格式变化、随后新测试 1 文件格式变化；`git diff --check` 通过。

### 串行构建来源与未解决的服务端关联风险

- 曾主动停止自己的 Profile r9 以冻结关联日期修正；Flutter SIGINT 返回 0，旧 `&&` 链意外继续 archive-r4，与新链发生同仓库重叠。
  未停止其他任务或清理共享缓存，原日志 `health-wellness-1014-sync-profile-r9.log` / `health-wellness-1014-archive-interrupted-chain-r4.log` 保留。
  r9 Profile 不算成功，archive-r4 只保留为来源不清的历史检查点，不能上传。随后确认没有构建进程，再独占生成 production archive-r5。
  r5 因末轮日期字幕修正亦已独立存入 `archive-r5-before-date-captions`，不是最终上传包；最终须用显式 `lib/main.dart` 再独占生成 archive-r6。
- r11 Android Debug / QA Release 均成功，Release 66.5 秒 / 68.3 MB；原生测试仍缓存复用本轮已实际执行的 22/22。
  r11 iOS Debug 77.5 秒、QA Profile r10 57.3 秒 / 63.4 MB 均成功，签名核查通过；不把 QA 宿主当普通用户 App。
- 只读核对服务端 `origin/main 48d4932`：Care summary 当前从按 observedAt / ID 排序的 preview 取首条。
  历史日批量同一读取时间时，可能选到旧日而非最新所属日。这是源码关联风险，非本轮实际观察到的错值；App 日期修正不等于后台已修复。
  应由服务端任务验证/修复 latest-day 选择，保持 API、鉴权和数据隔离。服务端代码未修改、未部署。
- 调用任务列表拟查找既有联调任务超时，停止该只读调用；没有猜测任务身份或向其他任务发送消息。
  没有导出 Token、解密健康库、公开真实健康截图、变更手机号/邮箱或删除旧行。
- Apple 实时回读仍为正式 1.0.0 / 1012 等待审核；1014 未上传。已发布隐私关联纠正不代表完整闭源 SDK 数据审计完成。
  原购买历史、地址、精确位置声明尚需与最终 iOS 实际数据流复核；英文商店内容与审核说明仍为草案，不宣称设备测试通过。

### 最终冻结后的验证（执行中，完成后追加）

最后生产源码修正为三个日汇总日期字幕，之后不再更改生产源文件。
analyzer r22 零问题（3.6 秒）；Swift Foundation 原生策略/日期测试在双时区实际执行通过。
全量 Flutter 双时区 r12、发布 Python、Android Debug/QA Release/native、iOS Debug/Profile/native build-for-testing/archive-r6 已启动。
安装必须从同一最终生产归档导出 Ad Hoc，并在启动前比对手机加密库；尚未完成的项不算通过。

### 最终 r12 主机和跨端矩阵回执

- `flutter analyze --no-pub` 零问题（3.6 秒）；UTC / Asia/Shanghai `flutter test --no-pub --reporter expanded` 各 1033/1033（71 / 82 秒）。
  日志 `health-wellness-20261007-{utc,shanghai}-r12.log`；没有将主机合成数据或旧设备证据当新版硬件验收。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'` 25/25（10.037 秒），受控发布门禁模拟，不是实际发布到旧国内域名。
- Android `sideload` 双 ARM Debug 19.3 秒 / QA Release 57.8 秒（68.3 MB）成功；`./android/gradlew -p android testSideloadDebugUnitTest` 37 秒成功。
  unit-test task 为 UP-TO-DATE，本轮实际 22/22 原生结果缓存复用；未执行 Android 真机或 Google Play 正式签名上架。
- iOS Debug `lib/main.dart` 无签名构建 111.7 秒成功；Profile 真实 QA 目标 56.5 秒 / 63.4 MB 成功，独立保留 `profile-final-r12/Runner.app`。
  同仓库独占 `xcodebuild ... -derivedDataPath build/ios-wellness-1014/native-tests-derived CODE_SIGNING_ALLOWED=NO build-for-testing` 为 TEST BUILD SUCCEEDED。
  RunnerTests 新日汇总用例已编译，但没有在 iPhone 执行完整 XCTest；只有 Foundation 独立策略测试实际双时区执行。
- iPhone15pm / iPhone 15 Pro Max 实时为 connected；最终安装前只读拷贝加密库至私有 0700 目录，文件权限 0600、290816 bytes。
  未导出密钥、Token、解密库或原始健康字段；安装后须在启动前再次拷贝比较，仍待最终安装回执。

### 最终 production archive-r6、安装与停线交付

- 最后全量及三个日期字幕修正后，独占执行：
  `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --target=lib/main.dart --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`。
  正式归档 53.9 秒 / 251.7 MB、App Store IPA 导出 7.2 秒 / 37000770 bytes 成功；不是旧 IPA、QA 目标或来源不清的 archive-r4。
- 独立保存 `build/ios-wellness-1014/final-r6/Runner.xcarchive` 与 `SAYDIAN-Health-1.0.1-1014-AppStore.ipa`。
  App Store IPA SHA-256：`cea2043b277d1f775a74bd95952adb9eed262f0afb70a82ba2e5de88621ee5cd`。
  从同一归档执行 `xcodebuild -exportArchive -archivePath build/ios-wellness-1014/final-r6/Runner.xcarchive -exportOptionsPlist ios/ExportOptions-AdHoc-iPhone15pm.plist -exportPath build/ios-wellness-1014/final-r6/adhoc -allowProvisioningUpdates`，EXPORT SUCCEEDED。
  Ad Hoc IPA SHA-256：`3f9a0e99d40a6fd911b2b35ca0f32d9f1b6af7c838c27f50f72ec609051cd16b`。
- 两个实际导出 IPA 均在私有目录解包并 `codesign --verify --deep --strict` 成功。
  plist / entitlement 实际断言：Bundle `cn.saydian.app.global`、版本 1.0.1 / 1014、UIDeviceFamily=[1]、团队 W7SXQ4A226、get-task-allow=false、无 APNs/HealthKit entitlement。
  App Store profile 无设备列表/非企业分发；Ad Hoc profile 包含指定 iPhone 15 Pro Max。production App.framework 未含 QA 时间诊断或公共空态测试入口字符串。
- 02:18 用最终 Ad Hoc 的 `Payload/Runner.app` 覆盖安装指定手机，没有卸载或清库。
  安装前/后、首次正常启动前，只读拷贝同一加密库，`cmp` 退出 0；原始文件留在 0700 私有目录，库副本 0600，不纳入 Git/交付包。
  `devicectl ... process launch --terminate-existing cn.saydian.app.global` 成功，正常生产入口进程 PID 13418；实际手机应用列表为 1.0.1 / 1014，进程列表匹配新安装的同一容器可执行路径。
  这是覆盖安装、保留数据与独立启动证据，不是全页面可视检查、资料保存或真实手表同步通过；QA 空态宿主已被正常 App 替换。
  02:19:54 再次查询同一安装容器，仍为 PID 13418；没有再次启动 App，也未把进程存活等同页面/设备无问题。
- 送审停线：手表未 ready、3 条旧未来时间记录未 ACK；新 SDK 日汇总上传/回读/重复同步与后台关爱 latest-day 风险仍需实测/联调。
  新读取修复不回写旧时间，旧行保留。不要用旧 1013、Say Ring、无数据截图、主机测试、手机启动成功或 HTTP 201 当闭环证明。
  隐私余项/闭源 SDK、实际审核账号登录、最终新包连接视频和商店截图亦未完成验收；英文文案和审核说明仅交草案。
- Apple 新版 1014 未上传、未正式/外部重新送审；旧 1012 等待审核未撤回，1013 公开 TestFlight 保持原状态。
  签名包是 `BLOCKED / candidate`，待上述门禁关闭后再上传及替换审核构建。本轮不构建鸿蒙、不恢复 Android 真机测试、不替服务端部署。

### 07:28 用户确认已连接后的闭环复测

- 用户在正常 1014 App 确认已连接手表。开始时分支干净，fetch 后 HEAD / 远端仍为 `1eb8a1fa56e784652cc854257ceabfd548fe7f50`。
  实际手机应用列表仍为 cn.saydian.app.global / 1.0.1 / 1014，正常进程 PID 13418；安装成功或用户连接确认不直接算 ACK 通过。
- 本组仅修改 `integration_test/ios_wellness_sync_qa_test.dart` 的证据采集，正式 App 源码、r6 IPA、原记录和 API 不变。
  原测试在队列未清零时过早终止，无法收集独立回读；将完成门槛延后到两个实读、回读和保留数据断言之后，仍要求 complete、零待传和零拒绝才能整轮通过。
  新增同一已确认日汇总原 ID/值/时间的真实重传，要求 ACK 且回读 ID 集合不变；不改样本或新造 ID。
- 只读服务端已存在的 `health-record-scope.ts` 明确 API 折叠非 active 日汇总版本；原始点记录始终可见。
  因此回读要求所有已 ACK 的点记录及客户端 active 日汇总可见，不错误要求被有意折叠的旧版本出现在列表。所有批次 ACK 仍须为实际提交的 ID 子集。
  断言只输出布尔值/数量/状态；不在失败信息中输出记录 ID 集合、返回拒绝详情或健康值。连接超时追加安全状态计数。
- 初轮格式化一文件有变化；analyzer 零问题（3.2 秒），UTC / Shanghai 全量各 1033/1033（63 / 54 秒）。
  初轮 Profile 编译成功（112.6 秒 / 63.4 MB），但在加入 API 折叠契约和安全布尔断言前生成，仅保留为 profile-connected-r1，不安装为本轮最终诊断包。
  后续一文件格式化零变化，analyzer 零问题（2.7 秒）；最终诊断 Profile / 双时区完整测试仍在执行，结果继续追加。
- 服务器检索初次误用 src 根路径及猜测的 daily-summary.ts，不存在；改用实际 apps/api/src 和已显示 import 的 health-record-scope.ts，未修改服务端或猜测部署状态。
  签名包核查、手机查询和备份只读；未开启用户拒绝的 iPhone 镜像。
- 诊断前 SIGTERM 正常 App PID 13418，随后拷贝最新加密库至私有目录 `health-1014-connected-followup.mi1xtH`（0700），库副本 0600 / 311296 bytes。
  没有卸载、清库、导出密钥或凭据；安装后启动前必须再拷贝比较，结束必须恢复原 r6 正常 Ad Hoc 入口。

### 已连接复测最终结果

- 最终诊断 r2 analyzer 零问题（2.7 秒），UTC / Asia/Shanghai 全量各 1033/1033（51 / 57 秒）。
  Profile 67.4 秒 / 63.4 MB 成功，独立保留 profile-connected-r2，严格签名核查成功。
- 指定 iPhone 15 Pro Max 实际 drive 发现 VM 并执行用例；两次手表同步均返回 true，四项限定能力已 ready。
  两轮各回读 210 条服务器可见记录，客户端 active 日汇总及点记录可见、服务端 ID 唯一，旧生理历史及其待传指纹均保持一致。
  本轮没有新记录首次 ACK；不能把已有服务器记录回读称为新测量上传通过。
- 3 条旧人工中午时间标记仍被 HTTP 201 的业务结果以 future_time 拒绝，保持 pending。
  六次批次累计 18 个拒绝回执，是同 3 条重复重试，不是 18 条新记录；手机/服务端时差诊断为零分钟。
  已确认日汇总按原 ID/值/时间重传：提交 1、ACK 1、拒绝 0，服务端可见 ID 集合不变，真实重传去重通过。
- 整体闭环用例仍失败：两轮均 allowedPending=3、state=pending，没有放宽零待传门槛。
  公共生产空态 UI 独立用例通过；不代替真实登录/测量验收。
- 诊断安装前/后、正常 r6 Ad Hoc 恢复前/后均比较加密库，启动前 cmp 退出 0；311296 bytes、副本 0600、目录 0700。
  正常 App 已恢复并独立启动 PID 13801；实际包 cn.saydian.app.global / 1.0.1 / 1014。没有卸载、删除、改写旧记录或公开原始健康资料。
  r6 两个 IPA 校验值保持原值；1014 未上传、未重新送审。

### 首页提示与百科接续修改（2026-10-07）

- 用户反馈：首页健康预警/健康百科消失、顶部多出对用户无用的提示。
  P2 复现：固定 iOS 范围同时隐藏两个入口，首页插入 ios-wellness-scope 长说明。百科公共阅读被误当成生理数据操作一并封锁。
  预期：移除额外范围横幅，保留原有简短健康安全提示；恢复通用百科阅读，不恢复个人风险判断、测量、AI 或健康数据发送。
- 先核对分支/远端，fetch 无更新，基线 1eb8a1fa56e784652cc854257ceabfd548fe7f50。
  当前两个自有测试/记录修改完整备份至 /private/tmp/health-home-library-prechange.fbFwYE，原图/历史安装包/加密库不修改。
- 公开只读 GET 检查 /global/api/saydian-app/v2/content/categories 与 articles：中文有两篇睡眠原理及一篇心率原理科普。
  详情为通用教育，无个人数据或个体诊断接口；不把文章作为本产品准确性/监管证明。
  英文文章 total=0，英文分类实际仍中文名称；保留既有语言过滤与空态，不伪造英文内容或混入中文。
- 拟修改 dashboard_pages.dart、app_controller.dart、global_api_client.dart 及相应主机/真机空态测试，恢复现有公共阅读链路。
  健康预警按用户此前批准的活动/睡眠范围仍关闭；原始记录、SDK、阈值、API 契约和 Android 功能不变。
- 初次检索使用不存在的测试文件及 zsh 未匹配通配符，按 rg --files 找到 ios_wellness_policy_test.dart；无相关测试执行，不计失败回归。
  新 UI 的主机、跨端编译、新包安装验收随后追加；旧 r6 IPA 不代表此次 UI 修改。

### 首页/百科主机初轮

- dart format 首次 5 文件、1 变化；定向 3 文件 101 通过 / 2 失败。
  两个新用例的公共 GET、类别选择、详情阅读和安全文案断言已执行，但没有在用例内部 finally 清除 debugDefaultTargetPlatformOverride，框架收尾不变量失败。
  不改产品逻辑或放宽断言；修正夹具 finally，重新格式化 1 文件有变化。第一次补丁因格式化后缩进不匹配未应用，按实际文件重试。
- 定向第二轮 103/103 通过（4 秒）；新增 iOS / Android 公共阅读链路、UUID 类别/详情、不携带登录或健康数据、首页无范围横幅及保留安全提示断言。
  原有 iOS AI/生理 API 发送前拒绝用例继续通过，Android 健康预警入口仍可见。
- 实机公共空态驱动改为断言百科存在、范围横幅和健康预警不存在；追加实际英文/中文公共文章 GET 及 UI 阅读，不读取手机会话/健康库、不操作手表。
  格式化此驱动 1 文件有变化，analyzer 零问题（3.3 秒），git diff --check 通过。
  全量双时区、发布门禁、Android 工程回归已启动；本轮无 Android 真机测试或鸿蒙构建。

### 首页/百科全量与跨端回归

- UTC 全量 1035/1035（51 秒）、Asia/Shanghai 全量 1035/1035（60 秒）通过；负向夹具的预期异常不算产品异常。
  发布 Python 25/25（8.075 秒）通过，为本地受控模拟，不是实际发布或向国内地址发送请求。
- Android sideload 双 ARM Debug 67.7 秒、QA Release 41.5 秒 / 68.3 MB 成功。
  Gradle testSideloadDebugUnitTest 11 秒成功；本轮为缓存复用的原生门禁，不声称新原生用例执行或 Android 真机验收。
  插件 Built-in Kotlin、SDK XML/Gradle 弃用警告保留，未改依赖或降低发行门禁。
- Swift Foundation iOS 原生范围/日汇总策略在 UTC 和 Asia/Shanghai 实际执行通过；原生生产源码没有变化。
  iOS Debug 正在独占构建，后续 Profile 公共页面用例和正常新版 Ad Hoc 安装结果继续追加。
- 指定手机 available (paired)，当前仍是正常 r6 1.0.1 包。只读应用/容器清单存入私有 0700 目录 health-home-library-device.Piad8l。
  加密库目录清单只有该库，无同名 WAL/SHM；没有导出密钥或解密内容。
- iOS 普通入口 Debug 无签名构建成功（Xcode 26.4 秒），不安装或以脱离调试器的 Debug 判断冷启动。
  Android 原生 task 回读明确 UP-TO-DATE；初次查 XML 误用 android/app/build，按实际 build/app/test-results 重查，未运行不存在的测试。
  devicectl --filter 的 JSON 仍含其他 App，后续 jq 只按精确 cn.saydian.app.global 提取，不操作其他 App。
  实际已安装 1.0.1 / 1014、正常进程 PID 13801 与该包容器匹配；Profile 公共页面目标已启动串行构建。
- 再检索找到旧全页面实机驱动仍要求范围横幅；原文件先备份，再同步为无横幅、有百科/无健康预警并加入百科路由。
  此完整认证驱动本轮未执行，不能沿用上一版全页面结果；本轮执行公共页面独立驱动。格式化 1 文件零变化，最终 analyzer 结果另记。
- 最终 analyzer 零问题（2.8 秒）；公共页面 Profile 成功（56.5 秒 / 60.7 MB），独立保存 profile-home-library-r1，codesign --verify --deep --strict 通过。
  全量 Provisioning plist 含日期/二进制，直接转 JSON 被 plutil 拒绝；改为只提取团队与设备列表子键，不打印证书数据或导出私钥。
  原 r6 App Store / Ad Hoc 两个 IPA SHA-256 保持原值；独占执行显式 lib/main.dart 正常 Release archive-r7，不把测试宿主作为发布包。

### 新首页正常安装包 r7 与设备保护

- 显式 lib/main.dart production archive-r7 59.9 秒 / 251.7 MB、App Store 导出 7.4 秒成功。
  独立保存 final-home-library-r7，不覆盖 final-r6；同一归档 Ad Hoc 导出 EXPORT SUCCEEDED。
  App Store IPA 36994079 bytes，SHA-256 5046b440f756d8f2270e30798156533cded10d83f66bbafd2507e1ccc0ec2775。
  Ad Hoc SHA-256 02a4a981a6ce0a798a54b9d5a9701046376e8ec9e4973663d96fd1bea73e4b60。
- 两个实际 IPA 私有解包后严格签名核查通过，Bundle cn.saydian.app.global、1.0.1 / 1014、团队 W7SXQ4A226、仅 iPhone、get-task-allow=false。
  无 APNs/HealthKit entitlement；App Store profile 无设备列表，Ad Hoc 包含指定手机；生产 AOT 未含公共 QA/时间诊断标记。
- RunnerTests 使用既有隔离 DerivedData，build-for-testing 成功；本轮没有执行完整 XCTest，不把编译当执行。
  公共 Profile 的开发 profile 包含同一 15 Pro Max，get-task-allow=true；只作本轮测试，不作为生产上传包。
- 为避免 flutter drive 再次安装后直接启动、无法在最后一次安装与启动间比对，采用 devicectl 手动安装、加密库比较、手动启动后 --use-existing-app 接入。
  bundled iproxy 直接执行两次分别缺 libusbmuxd / glue dylib，按 Flutter 缓存源码设置三个现有库目录的 DYLD_LIBRARY_PATH 后 --help 成功；未安装替代工具或修改 SDK 原件。
  手动测试包安装前/后加密库 cmp 退出 0，311296 bytes、0600；没有卸载、清库或启用镜像。
- 首次裸 devicectl 启动 Profile 未发现 VM 服务，不算 UI 测试执行通过。
  按本机 Flutter getIOSLaunchArguments 的 Profile 参数重新启动同一已安装测试包；不重装、不关闭 VM 鉴权、不改应用源码或设备数据。
- 同一 Profile 裸启动即使带官方启动参数，仍无 VM；Bonjour flutter attach 仅等待，主动停止本任务自己的 attach。
  --use-existing-app 方案未跑用例，不计通过。锁状态查询 passcodeRequired=false / unlockedSinceBoot=true，不据此臆测物理当前画面。
  停止自己的测试 App、再比较加密库一致后，改用此前已工作的 Flutter 调试器启动路径，固定 --keep-app-running，禁止结束卸载。
  此路径含工具自动同包覆盖安装；会核对整个驱动前/后加密库，不宣称在自动安装与启动间插入了额外比较。
  结束仍须手动安装已核验 r7 正常 Ad Hoc，并在启动前比较数据库；未执行的 UI/保留数据项不算通过。

### 新首页/百科实机最终验证

- 通过 Flutter 调试器路径成功连接指定手机的实际 Profile VM；UI 驱动退出 0。
  实际执行生产首页/设备空态、英文线上公共百科空态、中文线上类别/列表/首篇详情三个 widget 用例，含框架收尾共 +4 / All tests passed（8 秒）。
  英/中 reading=passed，首页百科可见、范围长横幅/健康预警不可见；安全提示保留。严格按公开测试边界，不读取当前账号或设备健康值、不制造测量结果。
- 实际生产页面空态截图保留 public-home-library-r1，目视检查首页两列入口、最右消息铃铛、无新增长范围提示，原安全提醒位于页面底部，无溢出。
  它们是公开空态测试宿主，不是已登录用户的全 App/硬件审核截图。
- 停止本任务的测试进程后，整个驱动前/后加密库 cmp 退出 0，且与初始安装前副本相同。
  正常 r7 Ad Hoc 手动覆盖安装，启动前再比较库 cmp 退出 0；311296 bytes、副本 0600，所有库留在私有 0700 目录。
  没有卸载、清库、伪 ACK、重写记录、导出密钥/Token 或发布真实健康截图。
- r7 正常发布入口独立启动成功，PID 13874，实际包 cn.saydian.app.global / 1.0.1 / 1014。
  随后冷启动/进程存活检查继续追加；此安装不代表 TestFlight 新包、正式审核提交或全部手表闭环通过。
- 正常 r7 包实际应用列表为 1.0.1 / 1014，三次独立启动 PID 13874 / 13875 / 13880。
  首次后续进程查询仍存活，第二/第三次各等待 20 秒后查询同一安装容器匹配进程，均成功；最后保持正常 App 运行。
  不把进程存活等同真实账号全部页面、资料保存、删除账号、测量首 ACK 或后台同步通过。
- 新 UI 正常 App 与真实页面公共驱动的证据已分开；英文线上文章仍缺素材，不发布自编医疗内容或伪造翻译。
  07:28 实测仍是 3 条旧 future_time 待传，保留历史与不伪 ACK 的停线边界不变。本轮未复测新生成 SDK 样本首次上传，也未关闭服务端 latest-day 风险。
  1014/r7 未上传 Apple、未撤回旧审核或重新提交。原签名/地区/后台/Android 业务不改变，Android 真机与鸿蒙构建仍停止。
- 交付前 git diff --check 通过，fetch 无更新；差异检查没有新增真实凭据、原始健康字段/值或私人截图。
  代码与本记录一起提交当前国际分支；Git 提交及推送回执以最后实时核对为准，不把本地 commit 当远端成功。

## 08:45 后接续：英文公共内容及首 ACK 验收门槛

### 修改原因与现场

- 基线 `575eb81e1ba20f7f17c5468304bfe1d8b63255dd`，当前国际分支干净；remote / fetch / ff-only pull 确认无更新。
  源码完整 Git archive 保存在 `/private/tmp/health-1014-english-fresh-ack.gGmUv2/source-575eb81.tar`，目录 0700、归档 0600，87777280 bytes。
  本轮不改 `lib/`、原生产品行为、版本、API、签名、地区或旧健康库；原 r7 两份 IPA 哈希重新核对一致。
- P2：英文公共百科类别/列表 HTTP 200，文章 0 篇；客户端入口已恢复，但不能把空列表写成英文文章验收。
  新增 `HEALTH-LIBRARY-EN-20261007.json`，两篇原创一般睡眠教育，参考 NIH/NHLBI 及原始研究；不声称 SAYDIAN 医学准确性验证。
  原中文、法律资料及个人健康记录不纳入草稿，不伪造翻译或测量数据。
- P1 验收缺口：此前日汇总原 ID 重传 ACK 通过，但新 SDK 记录首次上传未证明。
  仅加强 `integration_test/ios_wellness_sync_qa_test.dart`：连接 ready 后保存本地/云端 ID 基线，留 60 秒真实走动窗口，再读取 SDK。
  新门槛要求当天真实步数增加、新 ID 原内容 ACK 后服务器回读一致且不再 pending；旧队列 complete/零拒绝原门槛不放宽。
- 服务器回读核对原 metric、values、unit、时间、来源设备/origin、daily aggregation。健康字段只在手机测试进程中比较，失败断言和日志仅输出布尔/聚合计数。
  不注入样本，不改时间、数值或原 ID，不把已上传记录当首次 ACK；超过基线读取上限直接停线。

### 服务端协同与公开回读

- 按用户既有授权向“导入-app服务端”任务发送 `/global` 联调要求；由服务端任务使用其既有正式内容流程发布。
  不直接操作对方工作树、凭据、国内或 SayRing；摘要排序修复只允许确证隔离的 global 派生查询。
- 08:53 匿名 HTTP 回读确认 en-only 新类别 `180a8248-5d99-46ea-8557-a76bf489f774` 和两篇 PUBLISHED 文章。
  `e9b1d15f-8dd0-4b80-b9e3-6eaad6831760` / `365ddfe0-569c-44b9-a3e9-3718354cbc73` 均为 product=saydian-global、locale=en。
  类别/列表/详情成功；用 jq 对两篇原稿逐段及全部参考 URL 做包含校验，均 true。此为公开 API 验收，不是 iPhone 阅读通过。
- 另发现旧 en 类别“帮助中心”显示中文（ID `37652ffa-31ab-42bd-b0fe-c92031f3b05b`），已委托服务端保留原元数据/审计后，仅修正该 en 显示名；结果待回读。
  服务端已用模拟场景复现 daily_summary 摘要误选旧日风险，36 项现有相关测试未覆盖此场景；只证明风险，不声称线上用户已经发生。
  旧 3 条 future_time 行保持原状态；不为通过门禁重写、删除、伪 ACK 或静默跳过。

### 本轮构建与主机验证

- 首轮文档路径检索使用根目录文件名返回不存在，按 `rg --files` 改为 docs 实际路径；thread limit=60 超出工具最大值，改为 50。失败未导致代码/外部数据改动。
- `dart format integration_test/ios_wellness_sync_qa_test.dart` 首次 1 文件变化，补充步数增加门槛后 0 变化；`git diff --check` 通过。
  `flutter analyze --no-pub` 两轮均零问题（3.1 / 3.4 秒）。JSON jq 格式及文章数量校验通过。
  后续 publication 状态校验首次因 jq 管道/and 优先级写法返回 false，加括号后为 true；JSON 原内容未因此改写。
- `TZ=UTC flutter test --no-pub --reporter expanded` 1035/1035，通过，108 秒；Asia/Shanghai 1035/1035，通过，70 秒。
  这些是完整主机测试，不覆盖真实 Bluetooth/SDK/API ACK；测试日志留私有目录。
- 发布工具 unittest 25/25，通过，25.566 秒；所有模拟发布/回滚/国内旧域名打印均为测试夹具，没有部署或改变公开清单。
  `swiftc ios/Runner/WearablePayloadMapper.swift test/native/ios_wellness_policy_main.swift` 编译通过，UTC / Asia/Shanghai Foundation 可执行测试均 passed；不是 XCTest 真机执行。
- 当前产品入口 iOS Debug 无签名构建 25.2 秒成功；诊断 Profile r3 119.7 秒成功，加入“当天步数增加”门槛后 r4 62.5 秒成功。
  两份诊断包分开保留，最终使用 `build/ios-wellness-1014/profile-fresh-ack-r4/Runner.app`；严格签名校验通过。
  实际 cn.saydian.app.global / 1.0.1 / 1014 / W7SXQ4A226 / UIDeviceFamily=[1]，get-task-allow=true，AOT 含本轮 QA 标记；不是 App Store 上传包。
- Android 只做编译回归：sideload 双 ARM Debug 9.4 秒、显式 SAIDIAN_ALLOW_QA_RELEASE=true Release 3.6 秒成功。
  JAVA_HOME=Temurin17 的 testSideloadDebugUnitTest 9 秒成功（300 tasks，295 up-to-date）；22 项 XML 为已有结果/缓存，不冒充本轮新执行 22 项。
  XML 路径初查 android/app/build 不存在，使用 rg 查到 build/app/test-results。Kotlin/SDK/模拟器 arm64 厂商警告保留，未改依赖或弱化门禁。

### 实机连接中断与停线

- 初次 live devicectl 显示指定 iPhone15 Pro Max available (paired)，包 1.0.1 / 1014，正常 r7 进程 PID 13880 与原安装容器准确匹配。
  随后尝试只终止该确认进程时返回 CoreDevice 4000 / RemotePairing 1001：建立隧道过程中连接中断。无法确认终止成功，不把它记为正常退出。
- 再次设备清单显示不可用；08:54 IOUSB 树无 iPhone，符合物理连接已断开。已请用户重新插拔并解锁，拒绝镜像的选择继续尊重。
  本轮尚未复制新手机库、覆盖安装诊断包或执行 Drive；没有卸载、改库、导出密钥/Token、使用旧截图或制造传感器/ACK 结果。
- 正常手机包尚未被本轮诊断包替换；新的 r4 首 ACK/步数增加及最新英文正文真机阅读均待 USB 恢复后执行。
  原 r7 App Store IPA 5046b440f756d8f2270e30798156533cded10d83f66bbafd2507e1ccc0ec2775；Ad Hoc IPA 02a4a981a6ce0a798a54b9d5a9701046376e8ec9e4973663d96fd1bea73e4b60，重新哈希一致。
- 本轮 Apple TestFlight 最后有效只读显示最新仍 1013 正在测试、1014 缺席；随后分发链接未正确导航，直接打开可见分发地址只显示壳页，未取得新的正式审核状态。
  返回原 TestFlight 地址；未修改 Apple 字段、上传新包、撤回旧审核或提交审核。历史正式 1012 等待审核不冒充本轮更新。
- 新 SDK 首 ACK、旧待传时间语义、安全范围内的摘要修复、全页真实账号验收与审核素材仍未闭环；1014/r7 保持 candidate，不能报告可上架/已送审。
  Android 真机与鸿蒙构建停止，待手机恢复后先对加密库做前后保护，再用 r4 Drive（keep-app-running）收证并恢复正常 r7。

### 协同结果及 Git 交付核对

- 两篇公共正文有国际 product 隔离；服务端任务确认中文/其他产品文章及协议均未改变，内容发布无需代码部署。
  分类本身是共用表、product 参数不隔离，因此原“帮助中心”未改名，不能声称类别层已完成产品隔离。
- 进一步查本客户端 `article_pages.dart`：`_matchesCurrentArticleLocale` 对英文过滤包含中文的类别名。
  所以上述 API 标签不一致不是英文界面实际显示混中文的证据，早先 P2 排查结论据此收窄；不改共享类别或产品源码。
  新 Health library 名称及两篇英文正文能通过现有语言过滤；真正 iPhone 页面验收仍待连接，不以源码检查替代。
- 服务端最终明确摘要排序尚未修复/部署：global 入口共用现有服务，跨产品修改不在本轮授权范围。
  保留此风险和旧 pending 三行，后续需隔离设计或用户明确扩大对应服务端修复范围；不通过放宽客户端门槛掩盖。
- 实施源码/草稿/日志已提交 `fccd286363b920407d2b45125d5fc8cda5fe23dc`，push 成功；`git ls-remote` 独立核对远端当前分支同 SHA，工作树干净。
  本节是随后取得的协同/推送回执记录，不修改生产行为；最后文档交付提交与远端核对另以实际回执为准。

## 11:13 重新连接后的真实手表验收

- 用户回复已重新连接。国际分支基线 `9426382ff039da5c630bf6b29dac900c81376480`，status 干净，remote / fetch / ff-only pull 无更新。
  没有其他 Flutter/Xcode 构建进程；本轮复用已签名 r4 诊断包，不重新构建、不改生产源码或平台范围。
- 开始时 Mac 仅 498 MiB 可用，随后外部状态恢复到 8.6 GiB；本任务未清缓存或删除文件，不能将空间增加算作本任务成果。
  r4 严格签名验证通过，实际 Bundle cn.saydian.app.global，AOT 包含 currentDayStepIncrease 验收标记。
- live devicectl 显示指定 iPhone15 Pro Max available (paired)，原正常包仍为 1.0.1 / 1014，原安装容器匹配，初次查询无该 App 运行进程。
  原加密库 311296 bytes，目录中只有主库、无 WAL/SHM/journal；只复制到私有 0700 目录 `/private/tmp/health-1014-reconnected-qa.RFn6Iq`，副本 0600。
- 手动覆盖安装 r4 诊断包成功，安装后启动前加密库 cmp 退出 0，完全保留。
  首次 chmod/cmp 在异步 copy 未完成时返回文件不存在；等待该复制命令成功完成后重新 chmod/cmp 成功，没有重新建库或删除手机文件。
- 运行 `flutter drive --profile --keep-app-running --no-pub --device-id 00008130-001C098C2290001C --use-application-binary=build/ios-wellness-1014/profile-fresh-ack-r4/Runner.app --driver=test_driver/ios_full_page_qa_test.dart --target=integration_test/ios_wellness_sync_qa_test.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`。
  截图及完整原始日志仅输出本轮私有目录；不卸载，不输出 VM URL、会话/Token 或健康原值，不上传私人截图。
- Flutter 提示当前走无线调试、安装启动 37.1 秒。IOUSB 两次查询无 iPhone；用户接续前只恢复了无线配对，已提示可接可传数据的 USB 线。
  无线后续实际成功连接 VMServiceFlutterDriver，自动覆盖安装后的 Bundle cn.saydian.app.global / 1.0.1 / 1014；匹配进程 PID 15299。
  controller 初始化、登录态能力 HTTP 200 / dailySummaryVersions=true、原队列检查及手表连接 ready 已到达，不把仅安装写成真机通过。
- 原三条旧记录仍 HTTP 201 / future_time 被拒绝；手机服务器时钟差 0 分钟，未来差值 under_1h，daily=0、legacyNoonMarkers=3。
  连接后的本批 6 条有 3 条实际 ACK / 3 条拒绝；发生在走动基线前，不当作本轮走动窗口的新记录验收。
  原拒绝行保持 pending，不改原时间、值、ID，不伪造 ACK；完整读回、指纹、重传去重及首 ACK 结果待驱动结束后追加。
- 已到达 fresh-activity-window-ready，提示用户此时佩戴手表走约 30–50 步，保持 App 前台、不手动点同步。
  本轮只允许真实设备活动/睡眠；窗口前后比较结果仍待验，不用旧时段或主机测试代替。

### r4 失败保留与契约修正

- r4 驱动最终退出 1：实际测试输出 +4 / -1，认证同步用例在首次读回比较失败；三个公共 UI/英中阅读用例及框架收尾通过。
  英文已发布列表及第一篇正文、中文列表/详情均真实执行到 reading=passed；不是模拟器或旧文章空态结果。
- 第一轮同步 SDK 返回成功，累计 7 个唯一 ID 实际 ACK；首批 3 个、窗口后新增 4 个。
  旧三行仍 pending，6 个批次累计 18 次拒绝都是同三行 future_time。设备/服务器时钟差仍 0 分钟。
  首次原内容回读断言失败后退出，第二轮同步、最终新步数增加、完整指纹和原记录 replay 未执行，不能认定整轮通过。
- P2 验收脚本错误：`_cloudIds` 要求 `source.deviceId`，但服务端既有 GET 契约有意不返回原设备 ID，只保存账号作用域哈希及可选绑定。
  只读检查服务端 48d4932 的 HealthService 返回及不可变重传判断；线上 `/global/health/ready` revision 与该源码 HEAD 完全一致。
  GET 同时用 JS/SQL Date（毫秒精度）返回观察时刻；原始 App 时间/值/ID 不改，不向 API 添加原设备标识以迁就测试。
- 仅修改 QA：按实际 iOS transport projection 比较，时刻用已有服务的毫秒精度，校验 metric/values/unit/aggregation 和全部既有源元字段。
  设备作用域身份通过同一原 ID/内容的真实 replay 和服务端 sourceDeviceKey 不可变冲突检查验收；有 fresh ACK 时优先重传该 fresh 日汇总。
  新增失败字段布尔诊断，不输出私人原值；完整零 pending / 零拒绝 / 新当天步数增加原门槛不放宽。其他字段仍待 r5 实机复核。
- 本轮修改前再次 status / fetch 确认远端基线仍 9426382，脏文件只有本任务日志；完整日志与 r4 QA 源文件已另存私有目录后修改。
  服务端路径首次误查根 src 不存在，rg 查到 apps/api/src/health/health.service.ts；只读，未修改对方工作树、部署或共享服务。
- 停止确认的诊断 PID 15299，复制当前加密库；恢复正常 r7 Ad Hoc，启动前与该副本 cmp 退出 0，副本 0600。
  正常 r7 独立启动 PID 15312；其后等待新 QA 构建，不把之前 test host 留在用户手机、不卸载或清库。
- `dart format` 本轮 QA 1 文件变化，`git diff --check` 通过；analyzer 零问题，3.1 秒。
  r5 诊断构建、双时区全量回归和后续真机结果在完成后追加；生产源码与原 r7 IPA 内容不变。

### r5 构建通过、无线 RPC 停线与恢复

- r5 Profile 编译成功，51.4 秒 / 63.4 MB；独立保留 build/ios-wellness-1014/profile-fresh-ack-r5/Runner.app，严格签名验证及新字段诊断 AOT 标记通过。
  实际 cn.saydian.app.global / 1.0.1 / 1014；本轮仅 QA 源码变化，不用诊断二进制上传 App Store，不重建或冒充新的正常 r7。
- 最终 QA 源码 UTC 全量 1035/1035（54 秒）、Asia/Shanghai 1035/1035（48 秒）通过；analyzer 零问题。
  本轮 Android 真机与鸿蒙不执行。正常生产目标的源码及 r7 构建矩阵与上一轮字节输入相同，沿用既有证据，不声称本轮重新构建所有正式包。
- 正常 r7 进程 PID 15312 经当前安装路径确认后停止，重新取得 stopped 状态的库副本作为 r5 安装基线，主库无 sidecar。
  手动覆盖安装 r5 成功；启动前 after-r5-install.db 与 before-r5-stopped.db cmp 退出 0。原版本/数据没有卸载或回退。
- r5 Drive 使用相同 keep-app-running / 预编译 binary 路径，连接 VMServiceFlutterDriver 后 request_data 长期不返回。
  日志没有 initialized 或任何 IOS_WELLNESS_QA_PHASE / 已执行用例结果；get_health 曾等待后连接，但不能据此认定真正初始化、手表连接、读回或 fresh ACK 已验收。
- 对既有本机 VM 服务做一次只读 HTTP、一次只读 WebSocket getVM/getStack 诊断，各 8 秒上限。
  HTTP 超时；WebSocket 升级成功但 RPC 未响应。仅解析函数名的诊断未得到调用栈，不打印 VM URL、变量、Token 或健康值，不修改程序内存。
- 设备管理仍显示原 iPhone 15 Pro Max，iOS 26.6、ddiServicesAvailable=true；lockState 的 passcodeRequired=false / unlockedSinceBoot=true 不等于当前屏幕已解锁或 App 前台。
  当前 r5 进程 PID 15327 与实际安装容器匹配；仅激活既有 App 返回同 PID，但日志仍不进展，不能确认根因是网络、挂起或初始化内部等待。
- 在已有安全诊断及激活无效后停止本任务 Drive（Ctrl-C，命令退出 0 是取消，不是测试通过），终止已核对的 PID 15327。
  本轮 stopped 加密库与安装前字节不同；可能已有初始化写入，但没有用例指纹证据，不能声称完整内容保留验收通过，更没有恢复旧库来伪造一致。
  所有副本仍 0700 私有目录 / 0600 文件，不解密或导出 Keychain 密钥。
- 恢复正常 r7 Ad Hoc，启动前与最新 after-r5-stopped.db cmp 退出 0；安装本身未改变停止时库内容。
  正常独立启动 PID 15361，后续 11:38 再次查询该安装路径仍为同进程（超过 20 秒），不是诊断包残留。
  没有重写/删除旧健康行、伪 ACK、卸载、OTA、改表盘、扩大共享服务范围或修改 Apple 送审字段。
- 本轮实际新增结论：iPhone 可无线配对、r4 真实 SDK 上传 7 个唯一 ID 获 ACK；公共首页/英中代表百科详情通过；QA 读回契约假设已修正并编译。
  完整内容指纹、新当天步数增加/首 ACK/第二次重复同步/优先新记录 replay 的最终 r5 现场验收仍未执行成功，旧三条时间语义及共享摘要排序仍是停线。
  最后 IOUSB 依然没有 iPhone；下一轮请用可传数据的 USB 线、解锁并保持 Health 前台，不启用镜像，再重跑 r5，不把无线卡住的结果当通过。

## 15:03 接续只读检查与正常版启动

- 用户要求继续；国际分支基线 c3207e9e66a8ce73daed6d86f096ff8e87bf0f1d，status 干净、remote 核对、fetch / ff-only pull 无更新。
  本轮不改生产或 QA 源码，不重建二进制、不覆盖安装、不恢复 Android 真机测试或鸿蒙；仅追加当前证据和交接记录。
- 指定 iPhone 15 Pro Max 当前 iOS 26.6，Developer Mode / DDI 可用，安装 cn.saydian.app.global / 1.0.1 / 1014。
  CoreDevice 明确 transportType=localNetwork / tunnelState=connected；两次 IOUSB 树仅控制器、没有 iPhone，不将配对可用冒充 USB。
  lockState 的两个布尔值仍不能证明当前解锁或 App 前台；已请用户用数据线连接、解锁并保持 Health 前台，不启用镜像。
- 当前安装地址仍为正常 r7 的 396A5F31-9428-4373-9CE1-6D58CCD820B7/Runner.app；初始进程列表没有匹配的 Health 进程。
  另一个 Runner PID 16483 属于不同安装容器，未终止或当作 Health。只启动本国际 Bundle，launch JSON info.outcome=success / PID 16503。
  后续两次独立进程查询仍匹配实际 Health 安装路径，持续超过 20 秒；只证明正常版进程存活，不证明当前画面、手表连接、VM Service 或热重载。
- 私有 0700 目录 /private/tmp/health-1014-resume-20261007.c3PArp 仅留设备管理证据，不复制健康库、解密数据或导出凭据。
  先前手动库保护步骤不冒充本轮执行；没有卸载或修改健康值/时间/ID。当前不重复已卡住的无线 r5 Drive，完整闭环仍待现场条件恢复。
- r5 诊断包与正常 r7 Ad Hoc 的严格签名验证通过；App Store / Ad Hoc IPA SHA-256 分别仍为 5046b440f756d8f2270e30798156533cded10d83f66bbafd2507e1ccc0ec2775 / 02a4a981a6ce0a798a54b9d5a9701046376e8ec9e4973663d96fd1bea73e4b60。
  可用空间从本轮 9.5 GiB 外部变化为约 11 GiB；本任务没有清理，不把空间增加算作成果。无本任务编译会话，不新跑旧输入的全量或跨端构建。
- 本轮 Apple 首次有效 TestFlight 页面显示最新仍为 1.0.1 (1013)，处理完成 / 正在测试，say / say public，邀请 3、安装 1；1014 未出现在列表。
  点击分发后正文仍为加载壳页，直接打开已知 inflight 地址也未取得状态；返回 TestFlight 导航超时、随后仅空页，不能把此前历史 1012 状态当本轮最新。
  未上传、撤回、改字段或送审；新 1014 未作为可试用版本发布。
- 匿名 /global/health/ready 实测 ready / revision=f58878a8a918f97d72cfa87b23928b4d109d519e，已不同于上午 48d4932。
  只读 fetch 服务端 origin/main、查看五个新提交；不 pull、改工作树或部署。HealthService 两版 blob 同为 087b54843a778c94e4e95f7a94c61f8c4cb509ad，health 目录无差异。
  新版改动涉及商城/库存/小程序认证，不据此声称最新日摘要风险已修复，亦不将源码比较当真实认证 API 回归。
- 沿用用户已授权的“导入-app服务端”协同，请其仅给出 /global 专用摘要选择隔离方案、最小文件和必要测试；明确不改源码/数据/共享类别、不部署、不扩大其他 App 行为。
  方案及实际验收尚未返回时不写通过。旧三行时间语义保持待核实，不通过改时间、清队列或伪 ACK 绕过门槛。
- 检索纠错保留：首个 IOUSB 文本过滤误匹配 IOKitDiagnostics，改为无属性树和精确属性过滤；服务端工作树不存在客户端交接路径，改按实际文件/提交只读查证。
  launch 结果首次误读根 outcome 产生 false，按 JSON keys 查到 info.outcome=success，再独立查进程；一个编排括号错误在执行任何工具前失败，修正后正常运行。
  这些是查询/编排错误，不据此归因为 App 崩溃、上传失败或已修复代码。
- 文档差异校验 git diff --check 通过；git diff 575eb81..HEAD -- lib ios android assets pubspec.yaml pubspec.lock 无差异，确认正常 r7 的产品输入未变。
  本轮不重复编译/全量测试，不将上午双时区各 1035 项当本轮新执行；没有新增页面、SDK、读回、去重或零待传通过结果。
  交付前再次 fetch，HEAD 与 origin 当前分支同为 c3207e9；只提交这三个文档变更，不纳入私有设备文件。服务端隔离方案仍在只读分析中。

## 15:57 USB 恢复后的实机闭环复测

- 用户回复 USB 已连接；修改前国际分支 699b0347430eec9b427cd92e6a4f543e3070bba7，干净 / fetch / ff-only pull 无更新。
  IOUSB 出现 iPhone，CoreDevice 实际 UDID 为指定 00008130-001C098C2290001C，transportType=wired，iOS 26.6 / DDI / Developer Mode 正常。
  无并发 Flutter/Xcode 构建；安卓真机及鸿蒙仍停止，不启用镜像。
- 初始 Health 安装为正常 r7 / 1.0.1 (1014)，没有匹配的 Health 运行进程；没有终止另一个 Bundle 的 Runner。
  主加密库 327680 bytes、无 WAL/SHM/journal，复制到私有 0700 目录 /private/tmp/health-1014-usb-qa-20261007.L0Oft1，库副本 0600。
  r5 严格签名与版本核对通过；手动覆盖安装成功，安装后启动前 cmp 退出 0。没有卸载、清库、读出密钥或改健康原值。
- r5 Drive 使用原 keep-app-running / 预编译 binary / production API 命令，真实 VMServiceFlutterDriver 连接后进入 initialized / connection-restored。
  自动安装后的实际 Health 容器 B2C3FB9F-4D36-4786-8039-F2EB249ECE42，PID 16874 匹配；不将仅 VM 已连接当初始化通过。
- 原队列检查后，连接恢复读入 3 条并实际 ACK 3、拒绝 0；在 fresh 窗口之前，不当作本轮走动首次 ACK。
  进入 60 秒 fresh 窗口时已提示佩戴走 30–50 步、App 前台且不点同步；尚未收到用户完成走动回复，不推断真实操作是否发生。
- 第一次真实同步：complete / allowedPending=0 / accepted=3 / rejected=0；第二次 accepted 累计 4，其余相同。
  两次完整指标过滤分页回读 serverAllowed=213，实际提交投影字段一致、没有重复 ID；旧非允许指标的内容及待传指纹均保持一致。
  仅覆盖脚本所明确比较的历史范围，不假称全部原始库内容指纹验收通过。
- 新 SDK 首 ACK/完整原内容回读已证明 1 条、freshPending=0；currentDayStepIncrease=false，未证明当天真实步数增长。
  同一原 ID/内容真实 replay 得到 ACK、无拒绝，重传前后服务器 ID 集合不变。正常补传和去重分项通过，但最终完成门槛仍失败。
  Drive 退出 1，+4 / -1；唯一最终错误为 New current-day activity increase not proven。公共用例/框架收尾通过，不写全 App 验收成功。
- 当前零允许指标 pending 不能证明上午旧三行的原时间语义正确，未通过修改/删除/伪 ACK 消除旧行。
  服务端只读隔离分析已返回：Health 和 Say Ring 均走 /global，不能仅凭前缀改变共用摘要排序并保证另一 App 不变。
  提议需显式 latest_day_v1 参数及模式确认标记，属于 API 扩展；本轮未实施、未部署，不擅自突破原 API 契约不变约束。
- 当前路径确认 PID 16874 后终止，复制最新停止库；恢复正常 r7 Ad Hoc，安装前后与该最新副本 cmp 退出 0。
  正常版启动 PID 16882 / 806288D9-278B-4994-A263-662F219CE404/Runner.app/Runner，待下一次 QA 构建，不留下测试 UI。
- 第二轮只修改 integration_test/ios_wellness_sync_qa_test.dart：采集窗口由 60 秒延至 120 秒，新增匿名 current-day baseline 布尔和 fresh 指标计数。
  原始值/时间/ID、全量 ACK、零拒绝、回读、重复同步、当天步数增长门槛全部不变；不以窗口变长当产品修复。
  生产输入和正常 r7 IPA 不变。下一包选择现有 ios_full_page_qa_test.dart，登录态逐页读取与同步组合执行；构建/回归结果完成后追加。

### r6 主机门禁、诊断包与再次断线

- dart format 本轮 QA 1 文件 / 0 改动，git diff --check 通过；analyzer 零问题，2.7 秒。
  `TZ=UTC flutter test --no-pub --reporter expanded` 1035/1035（54 秒）；Asia/Shanghai 同命令 1035/1035（59 秒）。
  `python3 -m unittest discover -s scripts/release -p 'test_*.py'` 25/25（16.031 秒），仅夹具，没有真实发布或回滚。
- `swiftc ios/Runner/WearablePayloadMapper.swift test/native/ios_wellness_policy_main.swift` 编译后，UTC / Asia/Shanghai 均执行 passed。
  这是 Foundation 可执行测试，不是 iOS SDK XCTest 真机执行；原生 XCTest 未新执行。
- `flutter build ios --profile --no-pub --target=integration_test/ios_full_page_qa_test.dart --build-name=1.0.1 --build-number=1014 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功，Xcode 34.7 秒 / 63.5 MB。
  独立保留 build/ios-wellness-1014/profile-full-page-fresh-r6/Runner.app，拒绝覆盖已有同名目录，严格 codesign 通过。
  实际 Bundle cn.saydian.app.global / 1.0.1 / 1014 / Team W7SXQ4A226 / UIDeviceFamily=[1] / get-task-allow=true，包含 REAL_DEVICE_PAGE 和新增基线标记。
  AOT App.framework/App SHA-256 为 3369d757bb0721cfd8d57bb39a0635f74ff4fbe3280d2afc41f21876b605e1f3；仅为诊断包，不得上传 Apple。
- 后续产品主入口 iOS Debug 无签名构建成功，Xcode 37.6 秒；不会覆盖上述独立 r6 或正常 r7 归档/IPA。
  git diff 575eb81 -- lib ios android assets pubspec.yaml pubspec.lock 无差异；r7 两个 IPA SHA-256 重新核对仍与前文一致。
- 16:14 覆盖安装前设备查询返回 CoreDevice 1011，apps/processes 结果不成功，依赖它的 jq 无法遍历 null；立即停止依赖动作。
  实时 IOUSB 无 iPhone、设备清单指定手机 unavailable，证明当前连线已断；不将此算成 App 崩溃或源码失败。
  r6 尚未安装、Drive 未运行、没有登录态逐页截图或新步数验收；最后成功安装的手机包为上文恢复的正常 r7，不是残留 QA。
  已请用户重新插稳并持续连接，采集时手机可留 Mac 旁、佩戴手表在附近原地踏步；不启用镜像。
- r5 本轮两张公共空态截图已逐张视觉检查：首页功能入口/右侧通知/底栏、Watch 连接空态可见，顶部范围横幅未恢复。
  英文、中文公共列表及第一篇正文 reading=passed。公共场景未读真实账号库/连接 SDK，与前面的真实同步独立记录；不冒充全页、登录写入或硬件演示视频验收。
- Android 仅尝试编译：`flutter build apk --debug --flavor sideload --no-pub --target-platform=android-arm,android-arm64 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 退出 1，16.7 秒。
  原因为 Gradle 9.1.0 官方分发下载 10000ms 超时，未到 App 编译。依赖缓存已不存在，Release 和原生 Gradle 测试未新运行，不沿用旧 XML 当本轮通过。
  查 JDK 初始系统/常见安装路径缺失；只读 flutter config 找到实际 Temurin17 目录，未改全局配置、JDK、Gradle 版本或仓库 checksum。
- 官方 curl 下载亦超时：首轮约 118 秒 / 66313207 of 134528013 bytes，自动重试重新开始后已取消；第二个有界下载在明确缺依赖缓存后取消。
  仅停止自己的两个下载进程（退出 130），当前生成的 31391744-byte 未完成 ZIP 保留私有目录，不校验通过、不安装/放入缓存或删除原始材料。
  停止该旁支恢复以保持 iOS 优先；Android 真机、鸿蒙、未知来源软件安装和任何发布均未执行。
- 服务端 CareService 48d4932 / f58878a 的 blob 同为 8795a910f3790bd3b3e1b33f1140446e0e0aacc2，关爱摘要风险确未在此范围更新。
  兼容参数/确认字段需要明确 API 扩展授权，已向用户提出仅新版 Health 启用的方案；尚未获得本次扩展回复，不发起实现/部署或改 Say Ring/国内默认行为。
- 交付前 fetch 确认 HEAD / origin 当前分支仍为 699b034；只有本任务 QA 与记录改动，不 pull 脏树。
  无残留 Flutter Drive / Xcode / Gradle wrapper 会话。空间约 6.8 GiB，无清理；私有 JSON、日志、库、截图与部分下载均 0600、目录 0700，不进 Git。
  新 SDK 首 ACK/回读/重传去重及零允许指标待传分项已证明；当天步数增长、旧行时间语义、登录态逐页及关爱摘要整改仍未闭环，1014 本轮未上传或送审。
- 交付时再次只读 Apple TestFlight 页面仅空壳，未取得新状态；不把 15:03 的有效 1013 列表当作此时新结果，不写提交/批准/新试用成功。
  下一轮预编译命令将 `--use-application-binary` 指向 profile-full-page-fresh-r6/Runner.app、`--target` 指向 integration_test/ios_full_page_qa_test.dart，保留既有 profile / keep-app-running / no-pub / 指定 UDID / production API / 私有输出参数。
  必须先重新核对实际手机路径和进程、保护最新加密主库及所有 sidecar，安装后启动前比较，再进入两分钟窗口；结束后恢复正常 r7 并核对最新停止库，不使用旧副本回滚健康数据。
