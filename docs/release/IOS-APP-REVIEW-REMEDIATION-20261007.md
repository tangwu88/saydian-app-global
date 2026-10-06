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
