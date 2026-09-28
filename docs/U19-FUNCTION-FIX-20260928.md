# U19 功能修复与回归（2026-09-28）

## 范围与保护

- 基线 `41fe3e5677c69821c9a544a9437bdb6ab67317e2`，工作区 `F:/xcodeplace/saydian-app-u19`，分支 `feature/u19-eb1`，origin 为 `tangwu88/saydian-app-global`。开始时干净，fetch 后本分支与远端一致。不合并国内分支、不清除手机数据。
- 依据前轮 [功能审计](U19-FUNCTION-AUDIT-20260928.md)，处理测量会话不结束、断线残留、同步通知遗漏、旧连接未关闭就重连、测量与查找入口缺失、读取成功误报云端成功。核心生命周期为 P1，提示为 P2。
- 预期：真实结果完成会话，不支持 App 停止时不发停止命令；断线/换号拒绝旧会话；只读核验后展示能力，启动应答/旧历史不算测量成功；不能确认的数据不上传。健康算法与已有真实记录不改。
- 手表时间由用户调整为当前时间。仍需用新测量回包核验时间戳语义，不硬减 8 小时。用户先前授权一次佩戴后的测量，不自动循环启动。
- 原始日志、截图、设备标识、联系方式、健康原始值及构建产物只存忽略的 `build/`，不进入 Git。本轮暂不发布服务端。

## 实施

1. `app_controller.dart`：真实新结果完成会话并取消定时器，无停止能力不发送 stop；断线/设备信息确认失联/换表/换号清理状态；重复历史 ID 不能完成新测量；同步中通知合并为有界一次补读并绑定账号和设备代次。
2. 新结果提供稳定的开始时间、会话 ID、结果给页面。粗粒度采样槽只有桥接提供当前测量的开始/变化/结束证据，才可结束会话，不改采样时间。
3. Android/iOS 原生连接排空见 [专项记录](U19-NATIVE-DRAIN-20260928.md)。旧连接真正关闭/取消后才能开启下一次；iOS 超时不冒充排空成功。
4. 测量弹窗改用控制器会话结果，关闭再打开不会丢失等待，秒精度结果不再受弹窗打开毫秒影响。无停止能力保留“请在手表上结束测量”，断线关闭不发停止命令；大字体内容可滚动。新增提示覆盖英文、简/繁中文、德/法/西/日/韩。
5. 设备读取成功提示明确只代表读取手表，云端状态单独确认。线上日汇总能力 404 不绕过。
6. [BP/查找桥接专项](U19-BP-FIND-BRIDGE-20260928.md)：只读血压历史核验、快照与完成通知后的新结果回读、按新结果证实时钟编码；旧历史时间不猜测。查找等待手表应答，拒绝时收回能力；U19 页面不提供虚假的停止查找按钮。心率/血氧独立测量未开放。
7. 二审补充：旧设备详情请求的空结果、成功和异常，以及旧账号保存错误，均不得污染新连接/账号。明确来自手表的健康变化在第二轮补读中到达仍合并补读；一般 SDK 回调维持有界一次，避免自触发循环。
8. 新增 `CloudHealthSyncState` 与 `SyncOutcome.hasPending`，设备页实际展示本机保存/待上传/云端确认，待上传可重试；新增提示八语覆盖。Debug/QA Release 版本递增为 `0.1.21+1005`，不变更应用包名及生产发布配置。

## 已执行验证（持续追加，不覆盖失败）

- 控制器第一轮定向：105 通过。第二轮：111 通过、1 失败，原因是新 Widget 超时测试遗漏 connectivity 平台夹具；补夹具，不改产品逻辑。第三轮：112 全通过，含新增 15 项默认回归、原诊断 5 项、账号及既有页面/流程测试。
  命令：`flutter test --no-pub test/app_controller_measurement_lifecycle_test.dart test/app_controller_account_wearable_test.dart test/qa_user_flows_test.dart test/ui_shell_test.dart tool/diagnostics/u19_measurement_lifecycle_test.dart --reporter compact`。
  输出：`build/u19-function-audit/measurement-fix-focused-round{1,2,3}.txt`。前轮 1 通过/4 失败原始证据继续保留。
- 原生 Kotlin/JUnit 6/6、跨端接线门禁 3/3、Android 传输独立编译通过；不等于 APK/真机通过。命令与限制见原生专项记录。
- `flutter gen-l10n` 通过；`dart format lib/ui/pages.dart` 通过，恢复了范围外一处仅格式变化，未改其他页面业务。
- 测量弹窗新增 6 项：首轮 4 通过/2 失败为测试夹具残留等待计时器、视口未产生滚动距离；明确清理与缩小测试视口后 6 全通过。覆盖关闭重开、秒精度/粗槽结果、断线、无停止、大字体滚动，不使用真实健康数据。
- 二审控制器先红 21 通过/8 失败，修复后连同账号/UI/流程共 127 通过；新回归覆盖同 ID 重连、换号详情空/异常、迟到保存错误、云端状态及真实推送补读。日志 `controller-stale-callback-red.txt` / `controller-stale-callback-green-round1.txt` 保留。
- 桥接/协议定向 18/18、相关静态分析通过；最后追加路由前缀测试由全量覆盖。
- 完整 `flutter analyze --no-pub` 首轮有 2 条格式建议（Debug if 括号、测试可空集合元素），已最小修正；复跑 `full-fix-analyze-round2.txt` 为 No issues found。
- 完整 `flutter test --no-pub --reporter compact` 首轮 898 通过/1 失败：旧页面测试仍要求误导性的 `Data synced`；改成确切的设备读取提示并断言旧提示不再出现。第二轮 **899/899 通过**，日志 `full-fix-tests.txt` / `full-fix-tests-round2.txt` 均保留。没有删测试或放宽健康校验。
- 格式化仅涉及本轮文件；查找单次触发测试复用原玉成用例，新增 U19，同时维持 Veepoo 开始/停止回归。

## 服务端联动与边界

- 独立服务端工作区 `F:/xcodeplace/saydian-server-u19`、分支 `codex/u19-daily-summary`，保留原未提交日汇总改动。公网国际服务 revision `a134be05e02fb7c48063345a4d87ef06362caa81` 的能力接口仍 404。
- 本地补能力路由鉴权/显式日汇总契约及接口文档；修复无效新日汇总遮蔽旧有效证据：复用既有有效性规则、先验证再选每日有效版本，不改健康算法/原始数据。
- 服务端先复现 8 项失败，修复后 47 项定向通过；API 全量 824 通过、4 项数据库测试跳过；类型检查、构建、359 接口目录、184 部署结构检查通过。没有执行真实数据库迁移、推送或线上发布。详细记录在服务端 `docs/implementation-log/2026-09-28-u19-capability-route-audit.md`。
- 云端同步、数据库迁移/并发/回滚、其他型号、iOS 构建/真机、HarmonyOS 仍不能据此标记完成。
- 服务端随后补充两项 P1：旧关爱路径缺省排除日汇总，V2 显式选择；报告/关爱按会员已保存时区和汇总所属日，在分页前筛选。先复现 7 失败，修复后相关 116 通过，最终 API **831 通过、4 数据库测试跳过**。类型/构建/359 路由检查通过。历史会员的默认时区仍需现场确认。
- 已把完整服务端本地工作保存为独立源码 checkpoint `de12cda`（`codex/u19-daily-summary`），没有合并 main、执行迁移或部署；这是未发布源码，不代表线上 404 修复完成。

## 最终验收

- Android Debug：`flutter build apk --debug --target-platform=android-arm64 --no-pub` 通过（73.2 秒）。
- Android 内部 QA Release：显式设置 `SAIDIAN_ALLOW_QA_RELEASE=true` 后执行 `flutter build apk --release --target-platform=android-arm64 --no-pub` 通过（134.7 秒）。仍是 Android Debug 证书签名，不是商店发布包；原 camera/jpush 插件未来 Kotlin 兼容警告保留，未为了本任务改无关依赖。
- 两包核验均为 `cn.saydian.app.global`、`0.1.21+1005`；`apksigner verify --print-certs` 通过，证书 SHA-256 为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`。
- Debug SHA-256：`1e8dc064dbe719289e1e773e79b9a73304e88bb80601bd428c9d61bd5dab58ad`。
- QA Release SHA-256：`58e7bfafcac3ee877f0c210bd7a86ae94d9d7959a72da6992728323da9e3cf0d`。
- 可交接包位于忽略的 `build/qa-u19-fix-20260928/`，分别为 `Saydian-U19-1005-debug.apk` 与 `Saydian-U19-1005-internal-qa.apk`。不提交 APK 到 Git。
- 安装执行 `adb install -r`，手机停在“风险提示／继续安装”确认页，已请求用户在手机确认，未代替确认或绕过。最后读取包管理器仍为 `versionCode=1004`，所以 **1005 尚未取得安装成功及真机复验证据**。未清除数据、未卸载、未发送测量/查找/设置指令。
- 距离先前佩戴确认已过一段时间，已再次询问是否仍佩戴、允许一次测量；本轮未收到确认前不触发充气。
- 再次执行 `node --test tool/test_urion_native_lifecycle.mjs`：3/3 通过。Windows 未执行 iOS Debug/Profile/Release 或 HarmonyOS 构建；不能用跨端源码测试代替。
- 操作纠错：最初按 ADB 的 D 盘 SDK 路径找 aapt/apksigner 未找到；按本工程 local.properties 使用 F 盘 SDK 后验包成功。一次从服务端工作目录读取 App 构建日志失败，随后回到 App 工作区读取；未影响源码或构建。
- Git 发布前核验账号和 App origin 均为 `tangwu88`，fetch 后 App 上游无新增提交。服务端独立 feature checkpoint 不合并 main；两仓源码分支不执行生产部署。

下一位同事先更新对应分支并阅读本记录；待安装确认后核对 versionCode=1005，冷启动并完成 U19 三轮连接/同步/重连及一次用户确认的测量。必须核对真实新结果时间、实体振动、本机保存/去重和服务器回读。心率/血氧格式、日汇总服务端迁移/时区及线上发布仍未验收，不得标记全量完成。

## 追加：用户确认继续安装后的真机复核

- 用户明确要求“继续安装”。先前悬挂安装已返回 `INSTALL_FAILED_ABORTED: User rejected permissions`；保留该失败，不将其解释为安装成功。重新检查 1005 的两份 Debug 包 SHA-256 一致、签名有效、包名和版本正确。
- 开始时 App 分支 `feature/u19-eb1` 为 `f234467349c0f39d3b52ffd93103c03b846b95e2`，工作区干净，fetch 后与远端 0/0。此次只安装、真机检查和记录，不改产品代码或重建 APK。
- 安装前在旧版设备页正常断开当前 U19，确保旧连接释放；然后重新 `adb install -r build/qa-u19-fix-20260928/Saydian-U19-1005-debug.apk`。依据用户此次明确继续安装的指示，在两级系统安装确认页使用正常“继续安装”，返回 **Success**，未修改系统安全设置、未卸载或清除数据。
- 包管理器实际显示 `versionCode=1005`、`versionName=0.1.21`，安装时间为手机 `America/New_York` 当地 `2026-09-28 06:21:26`。冷启动仍保留已登录会话和已有记录。
- 冷启动复扫确认 U19 厂商广播后连接同一手表：`06:23:48.852` 完成服务发现、通知订阅和设备信息读取并 ready；`06:23:50.157` 血压历史结构只读核验成功，`06:23:51.325` 自动读取当天日汇总 `index=0 dayOffset=0`。本轮首次连接通过，但前提是安装前已主动关闭旧连接；不能扩展为此前安装首次连接缺陷在所有路径均已解决。
- `06:24:53.866` 手动同步再次读取当天汇总；页面显示“已读取手表数据，云端上传结果请查看同步状态”，随后明确“部分记录暂未上传，已保存在本机”。能力接口仍在新域名返回 404，未冒报云端已保存。
- 查找入口真实出现；仅点击一次“开始查找”，`06:25:37.155` 收到 `[U19Find] acknowledged`，页面显示指令已发送，不再出现虚假的停止按钮。此为指令及 UI 应答证据，手表实体振动尚无人为反馈，不能代称已观察到振动。
- 当前进程可用日志没有 `FATAL EXCEPTION`、`ANR in` 或 `RenderFlex overflow`。原始日志、UI XML 均在忽略的 `build/u19-function-audit/1005-*`。未执行新的充气测量、未修改时间/语言/目标等设置、未触发服务端部署；最终保持 U19 已连接的设备页。
- 本轮未重复三轮重连，也未验证测量结果时间、历史保存去重、服务端回读或 iOS/HarmonyOS。其余原待验收项继续保留。
- 安装包应用标签经核验仍为 `Saydian`，本次功能修复包尚未包含此前 `SAYDIAN Health` 改名要求；已作为独立遗留事项提醒，未临时混入安装任务重建。
