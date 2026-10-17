# SayDian 当前交接说明

## 2026-10-18 QRing 同步接续及资质材料

本机源码仍 1018，手机实际 NSBundle 为 `cn.saydian.app.global / 1.0.1 (1019)`；保留现装，不降级或注入旧 kernel。原生 LLDB / VM main / 美国 `.com` 实例核对通过，未执行 Flutter 热重载。
已修复真实 iOS 同步 QA 写死旧 `.cn` 回读的问题；3 项新增测试、analyzer、双时区各 1108、发布工具 25 项通过，产品源码/API 未改。
用户选择先测 QRing，但扫描暂无设备，真实设备 ACK/服务器回读/去重尚未完成；已请先断开其他配套 App 后返回国际版搜索。LuckRing 仍待。
提供的三份 PDF 属于 U19S 气囊血压手表，不能当作两戒指资质；FDA K254048 官方已查，包装/授权编码不一致和欧洲材料缺页待补，不改变 iOS 功能或现有审核。
精确现场、失败、清理边界见 [本轮同步记录](QA-20261018-IOS-RING-CLOUD.md)，材料核对见 [U19S 资质记录](release/DEVICE-QUALIFICATIONS-20261018.md)。私有健康库、会话和原件不进 Git。

## 2026-10-17 国际版苹果真机 Debug 重新开启

此前Flutter会话已停止，本轮在指定iPhone 15 Pro Max重新启动正常入口1.0.1(1018) Debug；USB wired/iOS26.6/开发者模式正常，另一台已连接XR未操作。运行源码未变，复用签名及SHA验证通过的10-16调试包；手动安装后启动前3个数据库共5,431,296bytes逐字节一致。

当前国际版PID40310与安装URL匹配，VM main isolate/HTTP200、热重载521ms通过，Flutter会话保持附加；DevTools HTTP200，右侧面板打开请求为queued。不是两戒指或新美国同步验收。完整命令、数据保护和边界见 [10-17真机调试记录](QA-20261017-IOS-DEBUG-START.md)。

## 2026-10-16 国际版真机 Debug 已启动

“继续”接续：调试进程与VM仍正常，官方inspector确认当前在GlobalAuthPage。真机实际第一方请求均.com，10次200，早期能力接口两次500、更新检查一次404；无连接戒指或上传记录。Mac补充正常域名/美国直连HTTP均超时，系统DNS返回198.18.0.77，未擅改网络/服务器。已请用户先在手机登录美国账号，再逐个连接LuckRing/QRing同步；尚未验收，不用商店审核账号存用户戒指数据。详见同一真机记录的接续段。

指定iPhone15pm已实时确认为USB wired / iOS26.6 / Developer Mode开启；正常 `lib/main.dart` Debug 1.0.1(1018)已覆盖安装并附加，PID35545与实际安装路径匹配。美国.com接口、英文默认、设备通用和iOS活动/睡眠范围沿用现有代码。Xcode27首次因旧Pods最低版本设置失败，使用本次私有Debug配置15.0后编译/签名成功，没有修改跟踪的产品配置或商店包。

手动安装后启动前两个原数据库共5,361,664bytes逐字节一致；Flutter内部二次安装/运行的内容不冒称同一次比对。VM getVM与DevTools HTTP200，热重载262ms通过，Flutter会话保持附加，不启用镜像。手机需保持USB与调试进程连接。具体命令、失败、私有证据和验收边界见 [本轮真机Debug记录](QA-20261016-IOS-DEBUG-START.md)；两戒指活动/睡眠及美国同步未在本轮验收，下面商店状态为各自标注日期快照。

## 2026-10-15 00:50 两端已送审

用户最新明确要求“提交送审”，取代此前只完成上传和准备的暂缓安排。Apple 官方审核详情已确认 `1.0.1 (1018)`，提交时间 2026-10-15 00:47（Asia/Shanghai），提交 ID `c60f87b6-25aa-4e5a-97be-ff687be9ff30`，状态“等待审核”；该提交已存在，本轮未重复提交或取消。Google 本轮实际完成最终送审确认，发布概览显示“正在审核中的更改”，正式版 `1.0.1 (1018)` 正在接受审核。两端尚未证明审核通过或正式上架。

本轮仅核对商店和更新交接记录，不修改程序、重建、安装或部署。此前完整 push CI `38596665683` 已全部成功；1018 两戒指实机活动/睡眠及美国同步仍未测试，此事实不因用户授权送审而改变。最新证据见 [实际送审回执](IMPLEMENTATION-20261015-STORE-UPLOAD.md)。下面的暂缓、草稿和未提交说明保留为历史快照，已被本节更新。

## 2026-10-14 美国系统与 1018 构建

2026-10-15 最新：Google 1018 正式 AAB 已实际上传并保存，自动预检查完成，发布概览显示“您的更改现在可以送审”。Apple 1018 已替换为 Dashboard / Device / Data privacy 三张 1179×2556 英文截图，旧 AI/预警/Watch 截图引用已移除；Apple 当前为“可供审核”的草稿，最终提交按钮可用但未点击。此前外部 10-14 18:36 的旧截图审核已为此次替换退回。用户随后明确回答“仍未测试，先完成上传和提审准备”；因此两端最终送审必须等 1018 两戒指活动/睡眠和美国同步真实验收，不能自动提交。

QRing 厂商 consumer rules 的两条 `-printmapping map.txt` 是 immutable cache 反复损坏的原因，已在生成 AAR 时移除，仅修改输出位置行为，SDK 类/JNI/DEX/Flutter payload 不变。正式 AAB 新 SHA256 为 `d097ac2ae4a2041991293b30d2d357d3fdb485bba459d441113e12dd05c00e78`，产物 `build/store-us-1018/qring-cache-fix/app-play-release.aab`；旧包保留。源码远端 `codex/saydian-us-api-20261014` 为 `69e1ecfe0845aab8e2ebfeedd2db1b9003b5c49e`，本地源码相同树、clean。两渠道各 38 原生测试、完整双时区各 1105、发行25、native/auth90通过/1跳过；CI 38596674403 的质量/鸿蒙已通过，Android/iOS 最终结论须另核对。

美国公开 r3 隐私/协议英文实读、支持/注销 HTTPS 和审核专用账号登录/回读/登出通过。额外发现公开注销页 CSS 把已 hidden 的未启用 SMS form 显示为 grid；服务器独立候选已在真实本地浏览器修正，尚未发布。当前仓库中美自动部署开关均 true，不能为了这个候选盲推 main 或改动国内发布范围。最新记录见 [本轮上传与门禁](IMPLEMENTATION-20261015-STORE-UPLOAD.md)；以下 10-14 快照的“尚未上传”等状态仅供历史追溯。

国际版第一方服务已切换为 `https://app.saydian.com/global`，API 为 `/global/api/saydian-app/v2`。美国使用独立新库、文件及密钥；北京数据属于国内测试，保留并独立管理，不执行历史迁移，也不自动导入手机旧域名缓存或复用旧会话。美国服务实际验收、60 次持续同步、99 表备份恢复及证书续期演练通过；独立 CI 自动部署已启用并完成同版本部署演练。以下旧日期的 `.cn`、旧名称及 1014 状态均为历史记录。

App 源码分支 `codex/saydian-us-api-20261014` 已同步 `1500f8d8025a9bb1079de104eb5e8bec8dd40c3b`，当前正式版本 `1.0.1 (1018)`；保持英文默认、设备通用提示、LuckRing/QRing、iOS 活动/睡眠范围和安卓远程推送关闭。Apple 实际报告的定位警告通过 SDK 官方前台定位编译设置修正；未新增始终定位或后台定位权限。

1018 已实际上传 Apple、处理完成、完成标准加密及法国不分发声明，关联到 1.0.1 正式草稿并持久保存。既有内部 TestFlight 组 `say` 自动获得此构建，状态正在测试；未新增测试员或发布外部测试。iPhone 当前仍不可用，尚未覆盖安装或完成两戒指的新美国同步验收，不能沿用 1016 的连接反馈当作本次通过。Google 1018 AAB 已构建和验证，商店英文及隐私资料已保存，AAB 尚未上传。Apple 截图和 Google AAB 的本机文件选择仍需支持的上传工具或用户操作；两端均未提交审核。

完整命令、失败保留、重试、产物 SHA、CI 和最新待验收项见 [美国部署与接口记录](IMPLEMENTATION-20261014-US-API.md)。已有正式产物位于忽略目录 `build/store-us-1018/accepted-live-builds/`；仅 Dashboard、Device、Data privacy 三张英文截图已通过本轮视觉检查，未采用错误态 Profile 或旧版本 About 图。

10-15 最终补记：完整源码 push CI `38596665683` 全部 success，质量、两时区鸿蒙、Android、iOS均通过，之前的QRing缓存错误已在云端Release后原生测试实际排除。并行PR CI的iOS被取消，不能将该run说成全部通过；使用完整push证据。注销页CSS独立候选为[服务器PR31](https://github.com/tangwu88/saydianserver/pull/31)，已同步、附任务且本地完整验证；未合main、未部署，生产样式问题仍保留。两端按用户最新选择继续等待1018两戒指实机反馈，最终审核未提交。

## 2026-10-11 正常产品入口真机 Debug

指定 iPhone 15 Pro Max 已实时确认为 USB wired / iOS 26.6 / Developer Mode enabled，正常 `lib/main.dart` Debug 构建并覆盖安装 1.0.1 (1014)。
手动安装前后停止状态加密库逐字节一致；Dart VM getVM / main isolate 与 DevTools HTTP 200，313 ms 热重载通过，保持 Flutter 附加，不启用镜像。
本轮仅启动调试，不修改产品代码/API，不执行新全页/手表业务验收，不上传 Apple；10-07 停线项保留。精确记录见 [真机 Debug 启动](QA-20261011-IOS-DEBUG-START.md)。

## 2026-10-07 苹果整改接续

本分支正在制作 `1.0.1 (1014)` 活动与睡眠限定版，以下 2026-10-05 快照不代表新源码或新包验收。
新范围固定适用于全部 iOS 账号和构建；原始健康记录保留，Android 业务范围不变，鸿蒙不构建。
完整变更、失败、签名包及停线项见 [苹果整改记录](release/IOS-APP-REVIEW-REMEDIATION-20261007.md)。

1014 未上传、未送审：07:28 接续实测手表已 ready，两次同步读取及服务器回读通过，同 ID 日汇总真实重传 ACK 与去重通过。
三条旧人工中午时间标记仍以 `future_time` 被拒绝、保持 pending；尚未证明新生成 SDK 样本首次 ACK，整轮闭环门槛仍失败。
随后按用户反馈恢复公共健康百科阅读、去掉首页额外范围横幅，健康预警/AI/生理数据边界不恢复。
新版 r7 已通过首页/英文百科空态/中文百科阅读真机用例，正常 Ad Hoc 已装入指定手机，安装前后加密库完全一致。
08:53 已通过服务端任务发布两篇 en-only 公共科普，并独立核对类别、列表及完整正文/参考 URL；本轮最新英文文章真机阅读尚未执行。
保留的 r6 IPA 对应 1eb8a1f 生产源码，不包含随后首页改动，不作为最新 UI 包上传。
当前带首页修正的归档为 build/ios-wellness-1014/final-home-library-r7；IPA 校验值和精确验收边界见同一整改记录。仍是待闭环的 candidate，未上传 Apple。
Apple 已发布隐私关联身份纠错；旧正式 `1.0.0 (1012)` 仍等待审核，未撤回，1013 TestFlight 状态与 1014 分开记录。
08:45 后接续没有产品源码变化；只强化首 ACK/当天步数增加/原内容回读的真机脚本并补英文公共内容，原 r7 IPA 校验值不变。
诊断 Profile 最新为 build/ios-wellness-1014/profile-fresh-ack-r4/Runner.app，编译/签名通过，不能当正式上传包。
指定手机随后 USB 断开：CoreDevice 隧道中断、设备不可用且 IOUSB 无 iPhone；尚未安装本轮诊断包，需重新连接后执行，不启用镜像。
本轮主机双时区各 1035 项、analyzer、发布工具 25 项、Foundation 执行及 Android Debug/QA Release/iOS Debug/Profile 编译通过；不代替首 ACK/实机。
国际摘要 latest-day 风险由服务端任务核对隔离方案；旧三行仍 pending，不伪 ACK/改时间/清库，1014 未上传/送审。
接续代码和内容记录已提交推送 fccd286；两个正文 product 隔离已回读，分类表本身仍共用，不能把分类当产品隔离已通过。
共用“帮助中心”类别未改名，Health 的现有英文过滤会排除中文类别名；摘要共享服务未修复/部署，不擅自改变其他 App。

11:13 用户接续连接后实机为无线配对，iOS 26.6 / DDI 可用。r4 真实同步 7 个唯一 ID 获服务器 ACK，旧三条仍 future_time；公共首页/英中代表详情阅读通过。
r4 在读回时因测试误要求服务端返回原设备 ID 而中止；现已按既有隐私契约和毫秒日期精度修正 QA，不改生产行为、原值或 API。
最新诊断包为 build/ios-wellness-1014/profile-fresh-ack-r5/Runner.app，签名/编译、analyzer、双时区各 1035 项通过；无线 RPC 无响应，未完成真正新步数/读回/重复同步验收。
11:35 已停止卡住的 r5 并恢复正常 r7，安装前后与最新停止时库一致；PID 15361 独立运行并持续存活。运行前后库有变化，没有最终内容指纹，不假称全部旧记录保留验收。
IOUSB 仍未识别 iPhone；下一轮需可传数据 USB 线、解锁及 App 前台，不启用镜像。1014 未上传/送审，旧记录时间语义与共享摘要修复仍待处理。

15:03 接续再次明确 CoreDevice 为 localNetwork、IOUSB 无 iPhone；未安装/运行 r5。正常 r7 重新启动为 PID 16503，实际安装路径匹配并持续存活，不是附加调试验收。
Apple 首次有效 TestFlight 仍显示 1013 正在测试、1014 缺席；正式分发壳页/返回导航超时，未取得新的正式状态或写入字段。
线上服务已更新为 f58878a，但 HealthService 与 48d4932 字节一致，摘要风险未因此解决。已请服务端任务仅分析 /global 隔离方案，不改共享行为或部署。
本轮仅记录现场检查，生产/QA 源码及 r7 IPA 未变；待用户 USB 数据线、解锁及 App 前台后继续真实新样本/回读/去重复测。

15:57 用户 USB 恢复后已确认 wired。r5 真机两次同步、完整原内容回读、旧非允许指标指纹及同 ID replay 去重通过；新 SDK 首 ACK 1 条、允许指标 pending=0，但当天步数增加未证明，整轮仍退出 1。
正常 r7 已恢复，安装前后与最新停止库一致，独立启动 PID 16882。最新 r6 为 build/ios-wellness-1014/profile-full-page-fresh-r6/Runner.app，只有 QA 窗口/匿名诊断变化，不用于上传。
r6 analyzer、双时区各 1035 项、发布工具 25 项、Foundation 双时区执行、签名 Profile 及产品 Debug 编译通过；Android 编译被缺失 Gradle/依赖缓存及官方工具下载超时阻断，未计通过。
16:14 手机再次不可用、IOUSB 无 iPhone，r6 尚未安装或运行；请持续插稳 USB 后直接用预编译 r6 + keep-app-running 执行登录态逐页/两分钟真实采集，再恢复正常 r7，不重试 r5 短窗口。
关爱摘要共享入口不能仅按 /global 隔离；服务端提议的新版 Health 专用兼容参数需要 API 扩展授权，已询问但未实施。旧三行时间语义仍待核实，零 pending 不等于原时间正确；1014 本轮未上传/送审。

## 以下为保留的 2026-10-05 工具交接快照

更新日期：2026-10-05。此说明覆盖当前工作；旧记录仅作历史证据。
新版交接包独立生成，旧 ZIP、素材、签名与安装包不覆盖。

## 内容与版本

- App：`tangwu88/saydian-app-global`，分支 `codex/global-device-admin-20261001`。
- 服务端：`tangwu88/saydianserver` 当前已提交主线，只读携带；不替同事修改或部署。
- `manifest.json` 固定两份离线 Git Bundle 的分支、完整提交号和逐文件 SHA-256；另附 `SHA256SUMS.txt`。
- `README.md`、`IMPORT.py`、当前测试/代码导航；可选携带已上传的 1013 App Store IPA。

本轮只优化维护工具。`lib/`、Android/iOS 原生行为、API、算法和版本不变。
App 名称 `SAYDIAN Health`，包名 `cn.saydian.app.global`，iOS 团队 `W7SXQ4A226`。
第一方请求须保留 `https://app.saydian.cn/global` 隔离；不要合入国内仓库。

## 苹果、安卓与服务端状态

2026-10-05 实时核对：Apple 已接收 `1.0.1 (1013)`，上传状态“完成”，TestFlight“正在测试”。
外部 `say public` 组已出现该版安装记录；公开邀请为 https://testflight.apple.com/join/Tp2ThpNm 。
正式分发页面读取超时，不能宣称已正式上架；不撤回旧审核，也不重复上传 1013。

原 IPA 为 2026-10-04 的已有正式签名产物，37,092,454 bytes。
SHA-256：`14363daa2d17155ba08ba4437b6f624dfa482d4b8aba0575d3243a3c0b094d45`。
它不是本轮工具整理重新构建的包；只能经 TestFlight/App Store 安装，不能当 Ad Hoc 侧载。

下载页入口：https://app.saydian.cn/global/down ，兼容入口 `/down`。
原赛电 `/down/legacy`、Say Ring `/down2` 独立；四个 Health 协议/客服/注销入口保留。
下载页此前的“等待审核”是历史配置，后续可按真实审核结果独立更新；不要擅自混入其他产品。

安卓真机测试已按用户要求停止，本轮仅做工程编译回归，不安装、测试或分发新 APK/AAB；鸿蒙不构建。
公开 Android 1012 是内部 QA 包，不是 Google Play 正式版；不能覆盖旧 Windows 签名 3012。
禁止卸载旧版、清空数据、换签名强装；不要把手机容器复制进普通交接包。

## 在新电脑上导入

需要 Git 与 Python 3.10+；先通过可信渠道取得 ZIP 和独立 `.sha256`。
在 ZIP 所在目录执行 `shasum -a 256 -c <ZIP名称>.sha256`，成功后解压。
进入解压目录，先 `python3 IMPORT.py verify .`，再导入不存在的新目录：

```sh
python3 IMPORT.py import /绝对路径/SAYDIAN-Health-workspace
```

脚本逐项验证、离线克隆、核对 HEAD、Git fsck，并设置原远端；不会网络拉取或覆盖现有目录。
两份仓库当前提交在包内 `manifest.json`，以脚本输出为准。
若发生错误，保留部分导入目录供检查，不向该目录重试或删除已有项目。

接手时先 `git status --short --branch`、`git fetch --prune origin`，干净且可快进再 `git pull --ff-only`。
不要直接 checkout main 代替当前任务分支，也不要覆盖未推送修改。
源历史含国内导入历史和受许可证约束的厂商 SDK，应受控传输，不上传公共附件。

## 工具链与代码导航

原机参考：Flutter 3.44.9 / Dart 3.12.2，Xcode 26.6，CocoaPods 1.16.2。
Android 参考：JDK 17、SDK 36、NDK 28.2；新电脑独立恢复，不复制整机缓存。
页面模块见 `docs/CLIENT-CODE-MAP.md`；每轮先读 `AGENTS.md` 和 `docs/CHANGE-TEST-LOG.md`。

以后重新打包时先提交已验证的源码，再运行仓库中的工具；输出 ZIP 必须是新文件名：

```sh
python3 tool/handoff/portable_handoff.py build --app-repo /App仓库 --server-repo /服务端仓库 --output /新文件.zip
```

默认不包含二进制；`--ipa` 只接受上述校验值的已有 1013 IPA，不能以任意历史包冒充新版。

```sh
flutter pub get
flutter gen-l10n
flutter analyze --no-pub
TZ=UTC flutter test --no-pub
TZ=Asia/Shanghai flutter test --no-pub
python3 -m unittest discover -s scripts/release -p 'test_*.py'
python3 -m unittest discover -s tool/handoff -p 'test_*.py'
```

## 必须独立安全转移的材料

不复制未提交配置、Keychain、签名私钥、证书、Provisioning Profiles、Play 上传密钥或生产推送配置。
不包含密码、验证码、会话、真实健康库、原始健康日志、公司证件或带个人信息的截图。
由账号持有人通过独立加密渠道恢复需要的材料；原上传密钥不能随意重新生成。

Git Bundle 仅从明确的已提交分支构建；它保留已有历史，不表示旧历史已完成全面秘密扫描。
本仓库当前可见性为 Public；本轮不变更可见性、不发布普通交接包到 GitHub Release。
生产签名和推送门禁不弱化，不以占位值绕过。

## 验收边界和继续工作

最新实机记录见 `docs/IMPLEMENTATION-LOG-20261004-IOS-TESTFLIGHT.md`：已验证新手表历史通知自动上传和服务端 ACK/回读及稳定 ID 重试。
用户物理操作/手表表盘时间确认、全部指标/型号、超距自动重连、30 分钟经过和后台运行仍非全面验收。
旧 drive 默认清理曾卸载测试 App；后续必须 `--keep-app-running`，不能声称所有未确认本地记录均保留。

本轮主机测试、脚本夹具和 ZIP 干净导入各自单独记载；它们不代替新设备验收。
继续时优先核对正式商店状态、下载页真实试用入口，再按用户授权补剩余真机矩阵。
天气暂缓、法国不发布；Google Play 的 D-U-N-S、单位验证和正式 AAB 状态须重新核实。
