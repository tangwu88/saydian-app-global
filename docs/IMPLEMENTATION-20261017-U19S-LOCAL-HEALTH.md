# 2026-10-17 U19S 本机健康模块

## 用户范围与原因

用户先反馈设备已连接，随后明确要求连接U19S手表时显示血压等相关模块。实际旧1018日志先尝试Yucheng后选择Urion，EB1每日读取开始；美国注册201、绑定201、健康批量上传201可见。仅网络状态不证明每条记录ACK或两戒指验收。未输出账号、设备ID或健康值。

P1原因：原iOS活动/睡眠策略同时在首页候选指标、控制器、路由、Urion能力探测/数据过滤及Swift帧写入禁用了生理模块，仅改页面不能恢复真实可用入口。前轮只读VM尝试evaluate失败于 `No compilation service available`（预编译App无表达式编译服务），不据此推断设备或数据为空。

基线 `7aa515c4f5fc76bd89a70f1e212a3eabae0dfd2a`，初始clean，已fetch/ff-only pull最新，阅读AGENTS/交接/复盘/回归/10-07范围记录；创建 `codex/u19s-local-health-ios-20261017`，不改他人分支、国内库或服务器。用户新要求扩展此前iOS本机范围；实现不依赖账号、审核身份、远程开关或Debug/Release模式。

## 实施边界

- 新代码1.0.1(1019)：已验证Urion/EB1通道可按实际返回能力呈现血压、心率、血氧，未知/不支持布局不露出，手动测量仍要求桥接确认支持；不以名称直接宣称传感器可用。
- 新增设备本机策略，与默认云端/分享策略分离；本机记录必须有Urion来源且不是关爱他人记录。血压保留systolic/diastolic，其他记录仍按已知值投影，原始缓存不重写/删除，不伪造时间/值/ACK或医学准确性。
- Urion只允许对应历史读取及用户发起测量帧14/15/2d/32/38/39，仍串行、绑定会话、校验回包。动态血压设置、校准、脉搏评估、AI、医疗预警、血糖/ECG等不扩展。
- 数据仅本机加密存储；默认云同步和关爱分享保持活动/睡眠。首页、所有健康数据、详情及趋势明确英文/中文本机说明。其他设备的iOS范围、Android功能及数据算法不变。
- Apple现有1018审核不撤回、不替换，不上传1019。后续上架1019须按实际功能更新描述/截图/政策，核对硬件准确性及适用监管资料；本次SDK/同步测试不是医学验证。Apple 1.4.1官方说明已核对，不能以免责声明代替支持材料。

## 检查与失败保留

- 首次analyzer：Dashboard动态候选列表误保留const，Urion日志分支缺括号；已修正。
- 新测试初稿遗漏BatchUploadResult.nextCursor、误用不支持的HealthRecord.copyWith(deviceId)；修正为完整fixture后analyzer零问题。
- 定向r1：72通过/1编译失败；r2：75通过/1widget收尾失败，原因平台debug覆盖未在widget回调结束前恢复。增加finally，未弱化产品断言。r3：39项全部通过（iOS默认范围、新Urion本机范围、路由、EB1会话）。Swift原生策略运行通过。
- 当前Flutter完整UTC/Shanghai回归及Debug构建正在执行；真实安装和能力展示结果随后追加。完整日志与数据库备份仅 `/private/tmp/saydian-u19s-local-health-20261017/` 私有保存。


## 1019 初次验收与崩溃追查（12:10 后）

- 功能改动静态分析零问题，完整 Flutter UTC/Asia-Shanghai 各1110通过；最终9语言文案生成后再次各1110通过。Swift原生策略通过，发布工具25通过；Node首次因PATH无node失败，改用内置运行时后90通过、1跳过、0失败。
- iOS Debug 15.2s、Profile 68.8s构建及签名检查通过；Android play Debug 23.1s、显式QA Release 82.1s通过。QA不是正式商店签名。iOS首次覆盖安装前后3个数据库共5,513,216bytes逐字节一致；Flutter内部二次安装另计。设备VM读取确认已登录、Urion U19_V3.0及steps/sleep/bloodPressure/heartRate/bloodOxygen能力，用户随后回答“已有”，确认入口显示；不代表手动测量准确性或新生理记录云上传（本来禁用）。
- 最终文案热重载报告34库/1315ms，但完整日志同时出现app.dart:530 ListenableBuilder构造NoSuchMethodError。此前只按重载完成判断成功不充分，已纠正。预编译Debug附加没有表达式编译服务，VM invoke额外探测也被Invalid params拒绝，未声称驱动UI成功。
- 用户报告“app崩溃了”；取得对应1019的12:10:43原生ips，EXC_BAD_ACCESS/SIGSEGV，主线程Flutter VSyncClient初始化、FlutterViewController viewDidLoad，尚未进入Urion业务栈。无当日Jetsam记录。该报告与热重载Dart异常分开记录，不强推单一根因或改动设备算法。
- 准备以完整源码正常flutter run重新构建与附加，避免复用预编译二进制后继续增量编译。12:10后当前Documents/Application Support另行只读备份，均仅私有/tmp保存；不卸载、清库或改商店审核。重新启动/稳定性结果随后追加。


## 崩溃恢复实际结果

- Git先保存完整1019实现checkpoint 91898d1；fetch成功，CLI push因无HTTPS本机凭据失败（terminal prompts disabled），未索取密码或改用国内远端。
- 正常完整源码 `flutter --no-version-check run --debug --no-pub --track-widget-creation -d <指定iPhone> --device-connection=attached --target=lib/main.dart --no-uninstall-first`，显式.com API/update及空JPush；沿用私有Xcode27最低15.0兼容配置，不改产品配置。不再提供--use-application-binary。私有启动器与日志为start-debug-full-source.py、flutter-run-full-source.log。
- Xcode28.2s构建成功，安装启动23.1s、文件同步104ms；首次VM探测仍指向旧已关闭端口而ConnectionRefused（安装尚未结束），等待工具明确广告新VM后成功。实际main isolate runnable/Resume，AppController仍已登录、暂无设备连接；inspector首页树包含SaydianApp/DashboardPage，不含ErrorWidget/登录页。DevTools HTTP200，面板打开queued，不据此声称用户已看面板。
- 在本次完整源码会话再次SIGUSR1热重载8/2222库840ms，通过；重新读取完整日志确认无EXCEPTION CAUGHT、NoSuchMethodError或Lost connection。设备崩溃目录仅旧12:10:44报告，无新增；未验证脱离Flutter后的Debug独立冷启动，不把此当Release稳定性或生理测量准确性结论。
- 本轮恢复未新增产品逻辑，未重复整个已通过的构建矩阵；保留先前1110双时区及原生/构建结果，以上真实源码重建和设备页面/热重载是恢复专项验收。U19S重连后连续采集的长期稳定性仍需实际使用观察，不沿用恢复前“已有”证明恢复后连接。


### 12:14:56 最终实机回读

- 恢复会话已重新连接实际Urion U19_V3.0，设备能力steps/sleep/bloodPressure/heartRate/bloodOxygen；设备同步空闲、无设备同步错误，活动/睡眠云同步状态complete。该状态不代表生理指标上传。
- 重新读取inspector：首页/SaydianApp存在，无ErrorWidget；本次完整日志Flutter异常0、断连0、热重载成功1次。系统崩溃目录仍仅12:10:44旧报告，无新增。Flutter会话保持附加；属于短时恢复验收，不宣称长期无崩溃或Debug独立启动通过。
- GitHub连接器两次create_blob均在HTTP传输层失败（chatgpt backend MCP），没有取得SHA或创建远端分支/PR；不把本地提交写成远端同步完成。CLI push仍缺本机凭据，源码和完整追查记录已本地提交保存。本次未改商店、服务端或用户数据库。


## 12:16 后：首页提示移至远程关爱底部

用户截图明确要求将本机健康存储/云同步范围提示从首页移到远程关爱底部。本轮只调整dashboard_pages.dart与global_care_page.dart的提示位置，保留设备条件、提示正文、其他详情页说明、数据和能力策略。同步修正既有首页测试预期，不新增低影响布局专用测试。

修改前工作树clean、HEAD31cc997；fetch成功，ff-only pull因本地新功能分支尚无远端tracking而拒绝，未覆盖或合并其他分支。阅读最新交接/变更/复盘/回归记录。预期首页紧接功能入口，已登录远程关爱列表最后呈现同一提示。验证结果随后追加。


### 提示迁移验证轮次

- `dart format`三文件、仅global_care_page.dart需要格式调整；`flutter analyze --no-pub`零问题。`TZ=UTC flutter test --no-pub` 1110通过/17s，`TZ=Asia/Shanghai flutter test --no-pub`1110通过/20s。
- 旧源码会话收到SIGUSR1和stdin r均未完成重载；VM getVM超时，CoreDevice仍连接、Runner进程存在，不能声称布局已更新或以此推断又崩溃。提示用户保持解锁/前台，同时在私有位置备份最新Documents，停止本轮旧Flutter会话（SIGINT后exit0，Lost connection为主动停止）。没有清库或卸载。
- Android play Debug构建11.1s通过；首次QA Release因遗漏 `--dart-define=SAIDIAN_PLAY_STORE=true` 被verifyPlayReleaseChannel拒绝（26.4s），补正确渠道参数而不改门禁后23.7s成功，70.7MB，仅QA签名不是上传证据。
- iOS Profile47.5s构建通过，strict/deep代码签名验证成功，保存build/ios-ui-notice-move-1019/Profile-Runner.app；随后正常完整源码Debug重新构建/附加，保持1019/.com/空JPush和原有私有Xcode兼容设置。未并行运行iOS构建。

- 最终Debug完整源码构建18.1s、安装启动25.2s、文件同步82ms，strict/deep签名检查通过。VM仍已登录，暂未连接设备；实际inspector首页存在、UrionLocalHealthNotice不存在、无ErrorWidget。新完整日志异常0、断连0，DevTools HTTP200，面板打开queued。新Flutter会话保持附加。
- 远程关爱提示位于列表最后，在设备本机范围条件下显示；正文和其他详情页说明不变。远程关爱新底部未在重新连接U19S后另行截图验收，不冒称该页面已完成真机可见性确认；源码位置与既有全面回归通过。用户无需再次确认已有授权的页面修改。


## 用户后续确认已解锁/前台后的调试恢复

- 后续回读时旧VM端口已关闭，旧Flutter会话exit0且Lost connection，App本身进程仍在，无新增ips；不把旧快照当当前附加正常。USB wired、开发者模式enabled。
- 优先尝试仅attach保留进程：首次CLI64因attach不支持--vmservice-out-file，移除此run专用参数后仍等待发现旧服务；停止等待后改用正常源码run，未改产品代码。一次停止筛选误匹配调用shell使该shell退出1，随后限定dartvm可执行进程及精确attach参数，未以宽泛名称终止其他App或系统进程。
- 原有1019源码完整run重新构建8.4s、覆盖安装启动23.7s、同步98ms，沿用既有.com和空JPush，无卸载/清库。新的VM回读已登录、实际Urion U19_V3.0连接、五项能力、无设备同步错误，活动/睡眠云状态complete；首页树存在且没有本机提示/错误组件。新日志页面异常0、断连0，设备ips仍只有12:10旧报告；DevTools HTTP200，面板打开queued。
- 新调试会话保持附加，仅当前短时实读，不承诺未来不会USB断连；本轮无产品源码变化，不重复既有通过的全量矩阵。源码与文案提示位置保持0ac385b，未触碰商店或远端服务。
