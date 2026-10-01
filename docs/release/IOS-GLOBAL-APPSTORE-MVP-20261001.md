# 2026-10-01 国际版 SAYDIAN Health 首版 App Store 准备

## 范围和基线

- 用户要求将**全新国际版 App** 尽量推进上线，优先保证基础功能可用；不是国内 SayRing 或原赛电 App 的更新。
- 原仓库 `/Users/mycodex/电商/saydian-app-global` 在 `feature/u19-eb1@4736fcbe29030b9d004b67b6ccc0fd622def87f7` 上干净。先执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin`、`git pull --ff-only`，结果已是最新。修改只在独立 worktree `/Users/mycodex/电商/saydian-app-global-appstore-20261001`、分支 `codex/global-appstore-20261001` 内完成；未改原 checkout 或国内仓库。
- 修改前阅读 `AGENTS.md`、`docs/INTERNATIONAL-HANDOFF.md`、`docs/CHANGE-TEST-LOG.md`、`docs/BUG-RETROSPECTIVE-20260829.md`、`docs/REGRESSION-CHECKLIST.md` 及最近 iOS/U19 交接记录。独立 worktree 后再次 `git fetch --prune origin`；因工作树已含本轮修改，不执行 `git pull` 或覆盖。

## 实施和影响

- Apple Developer 新建 `SAYDIAN Health Global` App ID，Bundle ID `cn.saydian.app.global`，团队 `W7SXQ4A226`；新建 App Store 分发描述文件 `SAYDIAN Health Global App Store Distribution`，UUID `7ee485ea-f57e-4db2-beff-1374c632adad`，有效至 2027-09-24。原国内 App ID、App Store Connect 记录不改。
- App Store Connect 新 App：Apple ID `6817980969`，名称 `SAYDIAN Health`，英语（美国），团队完全访问，主类别 Health & Fitness；iOS 版本 `1.0.0`，手动批准后发布。已保存英文副标题、谨慎的 wellness 描述和关键词。尚未提交审核。
- `pubspec.yaml` 调至 `1.0.0+1008`；`ios/Runner.xcodeproj/project.pbxproj` 将 Release 限为 iPhone 家族 `1`，采用专用 `Info-AppStore.plist` 和无额外 Push/Associated Domains 的 `RunnerAppStore.entitlements`。`ios/Runner/Info.plist` 删除 iPad 横竖屏声明。新 Release plist 不包含未配置的微信/支付宝 URL scheme；Debug/Profile 仍沿用原有配置。原生 SDK 仍在二进制中，不能据此声称第三方数据收集为零。
- `lib/ui/feature_visibility.dart`、`lib/ui/pages.dart` 在国际首版隐藏付费健康分析入口，保留基本健康读数/设备功能；商城入口原本已隐藏。`scripts/release/validate_xcode_release.sh` 与测试改为验证国际正式包名、iPhone-only、专用权限/Info、真实签名、国际 API origin，继续拒绝 QA/Production 模式混用、国内 origin 与未配置 JPush。新增 `ios/ExportOptions-AppStore.plist` 明确手动分发描述文件映射。测试同步更新。
- 核查曾误将旧 `LoginPage` 微信按钮视作国际版入口问题；追踪 `lib/app.dart` 后确认国际版实际使用 `GlobalAuthPage`，未按该误判修改代码。该检查纠正保留在记录中。

## 实际验证

- `flutter pub get`、`cd ios && pod install` 成功；`plutil -lint` 对 Info、entitlements、pbxproj 与导出配置通过；`sh -n scripts/release/validate_xcode_release.sh`、`dart format`、`git diff --check` 通过。
- `python3 -m unittest scripts.release.test_release_gate.XcodeReleaseBuildGateTest -v` 首轮 1/7 失败，因新增测试用例根路径写成 `HERE.parent`；改为 `HERE.parent.parent` 后 7/7 通过。`python3 scripts/release/test_release_gate.py` 22/22 通过。失败已记录，不当作产品构建失败。
- `flutter analyze --no-pub` 通过。`TZ=Asia/Shanghai flutter test --no-pub --reporter compact` 与 `TZ=UTC flutter test --no-pub --reporter compact` 各 929/929 通过。自动化不代替真机手表/服务端验收。
- 首次 `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 在核查登录入口时主动中断，退出 130；未产生成品。第二次同命令成功生成 `build/ios/archive/Runner.xcarchive`（260.1 MB），但 IPA 自动导出失败：`exportArchive "Runner.app" requires a provisioning profile`。新增显式 ExportOptions 后运行 `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/ipa -exportOptionsPlist ios/ExportOptions-AppStore.plist`，显示 `** EXPORT SUCCEEDED **`。
- 真正的 IPA 为 `build/ios/ipa/SAYDIAN Health.ipa`，约 38 MB，SHA-256 `a1af2a9c41ef841c3289153b961f5c810c8e32f90fdf7420436bb6c91baf7291`。解包 Info.plist 回读 `cn.saydian.app.global`、`1.0.0 (1008)`、`UIDeviceFamily=[1]`、arm64；归档 `codesign --verify --deep --strict` 通过，嵌入分发描述文件名称正确，App 权限 `get-task-allow=false` 且无 Push/Associated Domains。构建有 Flutter 默认启动图警告，待收口视觉资源。

## 线上与未验收边界

- 2026-10-01 回读 `/global/api/saydian-app/v2/auth/capabilities` HTTP 200：`registration.email=true`、`registration.sms=true`、`verificationRequired=false`，`login.email=false`、`login.sms=true`、`smsCountries=[CN]`。曾误以为 `login.email=false` 代表邮箱**密码**登录关闭；回读服务端 `GlobalAuthService.login()` 后确认密码登录仍走 `AuthService.login()`，该能力字段实际随验证码投递可用性计算，不能仅据此推断密码登录失败。注册-退出-再登录仍需实机与现网账号验证。未提交真实 OTP/支付。
- 英文隐私接口返回的标题仍为 `Saydian Global Pre-release Privacy Notice`，版本 `global-qa-2026-09-10`，且内容声明这是 test service；不是正式公开隐私网页。国际版公开隐私政策 URL、准确数据收集清单、可用客服网页/邮箱和 Apple 审核账号尚未提供，不能编造或沿用国内资料。
- 健康与健美类别在美国/欧盟/英国的受监管医疗设备状态、年龄评级、加密出口、数字服务法等声明需真实产品/法务依据。App Store Connect 尚无截图、审查账号、联系信息或已处理的构建，因此尚未“提交审核”，更不是审核通过或上线。
- iPhone 15 Pro Max `A3DC94EA-18E8-52EB-B953-60133E11D071` 已有线连接。Mac 的 iPhone 镜像重试仍报无法连接。`flutter run --profile` 已尝试，原生编译通过，但由于 Xcode 未配置团队签名账号、备用 wildcard profile 缺少 Push/Associated Domains 权限，签名安装失败；不能标为 Profile 启动通过。Android Debug/Release、iOS Debug 本轮未执行。
- Xcode Organizer 已识别新国际 App 归档，并在 10:03 返回 `Upload completed with warnings`，状态回读 `Uploaded with warnings`，构建号 1008。警告包括 iOS 13 最低部署版本将在 2027 年 4 月后不再符合上传要求，以及 13 份第三方手表框架缺 dSYM；均未阻止这次上传。App Store Connect 构建处理结果仍待单独回读，不把上传成功等同处理成功。

## 10:10—10:20 真机与服务端联调追加

- 为不依赖 Xcode 开发账号的实机安装，Apple Developer 新建仅含这台 iPhone 15 Pro Max 的 Ad Hoc 描述文件 `SAYDIAN Health Global iPhone15pm Ad Hoc`（UUID `c874b72f-abf3-4278-9a03-59726518c4b8`，有效至 2027-09-24）；新增 `ios/ExportOptions-AdHoc-iPhone15pm.plist`，`plutil -lint` 通过。运行 `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/adhoc-iphone15pm -exportOptionsPlist ios/ExportOptions-AdHoc-iPhone15pm.plist`，返回 `** EXPORT SUCCEEDED **`。Ad Hoc IPA 为 `build/ios/adhoc-iphone15pm/SAYDIAN Health.ipa`，SHA-256 `edf5ec05d0cf20589521f6c023165523f5e1f5dc5c9a71c0ad3c474abbe86567`；解包回读 `cn.saydian.app.global`、`1.0.0 (1008)`、`UIDeviceFamily=[1]`、正确的 Ad Hoc profile，`codesign --verify --deep --strict` 通过。
- 安装前 `devicectl device info apps` 显示同 Bundle ID 旧版 `0.1.23 (1007)`；用 `devicectl device install app` 覆盖安装 Ad Hoc App，未卸载旧包。安装后清单变为 `1.0.0 (1008)`，`devicectl device process launch` 成功。实机截图和 WDA 辅助功能树确认首页已启动、原登录会话和既有读数仍在；未读取或记录账户令牌/原始健康包。旧语言设置为简体中文；在 Profile → Language 切换 English 后，Profile、Watch、Health 首页均显示英文，因此中文不是缺少英文适配。
- WDA 实机只读点击已验证 Health → All data → Heart rate analysis，日期切换、历史读数、空状态和健康免责声明均可显示；Profile → Help and feedback、Account settings 亦可打开，未发送反馈、退出账号或删除数据。Watch 页显示已连接手表及电量约 10%，但提示部分记录未上传；点一次 Try again 后提示仍在。客户端 `HealthSyncService` 代码表明该提示可能来自服务器拒绝、未确认记录、暂不支持的日汇总或波形等，**仅凭 UI 不能判定服务端故障或数据丢失**；本地队列保留。未在低电量手表上执行测量、断开/重新配对或完整 BLE 验收。
- 问题记录（待定位，暂按 P1 云端同步风险）：复现为已登录且手表连接时进入 Watch、看到未上传提示、点击 Try again；预期记录经正式支持的接口获得确认或显示具体可处理原因，实际提示持续但根因未知。App 的 Account settings → Privacy policy 实机打开的是 `Saydian Global Pre-release Privacy Notice` / `global-qa-2026-09-10`，不能作为正式上架隐私政策。以上现象已交由现有“导入-app服务端”任务对照线上 `/global` 路由与日志；该任务报告生产全局分支已到 `fabf58c` 且数据库就绪，最终端到端结论仍待它的复核结果。
- 10:19 刷新 App Store Connect TestFlight 页面仍显示“提交构建版本以开始测试”，暂未看到已处理构建。不能从 Organizer 的上传回执推断 Apple 已完成处理或可提交审核。

## 10:40 本地化图标名称修正与新候选包

- 真机 `devicectl` 安装清单和 WDA App label 仍为 `Saydian`，与新 App 名称 `SAYDIAN Health` 不一致。回读已安装的 1008 Ad Hoc 包：`Info.plist` 的 `CFBundleDisplayName` 正确，但八个 `*.lproj/InfoPlist.strings` 都将其覆盖为 `Saydian`。问题等级 P1，已先报告复现、预期/实际，再改动。
- 修改八个国际版 `ios/Runner/*.lproj/InfoPlist.strings` 的图标名称为 `SAYDIAN Health`，不改各语言权限说明；`pubspec.yaml` 增至 `1.0.0+1009`，避免与 Apple 已接收的 1008 混淆。`scripts/release/test_release_gate.py` 新增八语名称一致性测试。修改前工作树干净，`git fetch --prune origin`、`git pull --ff-only` 后基线 `c5ca9e1`；原始 checkout 未改。
- 新增定向测试 `python3 -m unittest scripts.release.test_release_gate.XcodeReleaseBuildGateTest -v` 8/8 通过；八个 `InfoPlist.strings` 的 `plutil -lint` 全部通过，`git diff --check` 通过。1008 上传包不是最终送审候选；1009 的归档、签名、实机覆盖、Apple 上传与处理状态须分别重新验证。
- 此前 `flutter build ios --debug --no-codesign --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 在 393.5 秒后成功；Profile 同命令配置 `--profile` 在 669.0 秒后成功，产物约 69.7 MB。两者只证明无签名编译，不是安装或 Flutter VM 真机调试。Android Debug/Release 因同时进行的独立服务端全量测试和另一项目 Gradle 构建造成显著高负载，本阶段暂缓，未记为通过。
- 客户端与“导入-app服务端”任务联调已证明实机 `GET /global/api/saydian-app/v2/health/capabilities` 返回 404，随后无健康批量 POST。客户端遇该错误会将 `dailySummaryVersions` 视为 false，故 U19 日汇总继续留在本机并显示待上传；服务端侧正在移植已有日汇总版本能力并跑部署门禁，未部署前不能写成同步修复完成。
- 使用 `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功生成 1009 App Store 归档与 IPA。`build/ios/ipa/SAYDIAN Health.ipa` SHA-256 为 `5c83c8289e3cf7212033c4ef1a081c3330f06c012a1548a4d12aaedb81a82394`；解包确认 `cn.saydian.app.global`、`1.0.0 (1009)`、`UIDeviceFamily=[1]`、八种语言的桌面名称均为 `SAYDIAN Health`，归档和 App 签名均通过 `codesign --verify --deep --strict`，App Store profile 和 `get-task-allow=false` 正确。构建仍有默认启动图、SPM 将来兼容与第三方手表框架模拟器架构提示，不能将其描述成全无警告。
- 对同一 1009 归档执行 `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/adhoc-iphone15pm-1009 -exportOptionsPlist ios/ExportOptions-AdHoc-iPhone15pm.plist` 成功。Ad Hoc IPA SHA-256 为 `9854267ad6d478515c0f64f5854e8e92a55354b57304d2ea4da58255a3088f5f`；实机通过 `devicectl device install app` 原位升级，`devicectl device process launch` 成功。安装清单显示 `SAYDIAN Health 1.0.0 (1009)`，数据容器 ID 与 1008 一致；WDA 确认英文健康首页与登录会话、既有读数仍可用。这是已安装并启动的真机证据，不代表 BLE 低电量手表全流程已验收。
- 10:59 Xcode Organizer 对 1009 返回 `Upload completed with warnings`，随后归档状态为 `Uploaded with warnings`、Build Number 为 `1009`。警告：iOS 13 最低版本自 2027-04 起不再满足新上传要求，及若干第三方手表 framework 缺 dSYM；当前没有上传失败提示。App Store Connect 的处理、TestFlight 可选构建及审核提交需要分别回读，不把此回执写成上架成功。
- 同一轮修改后 `python3 scripts/release/test_release_gate.py` 23/23 通过、`git diff --check` 通过、`flutter analyze --no-pub` 无问题，`TMPDIR=/private/tmp flutter test --no-pub --reporter compact` 929/929 通过。测试期间故意触发了被审查文档变更的拒绝分支，日志中有预期的 FormatException；最终测试进程退出 0。Android 构建另记实际结果，不提前判为通过。
- 11:00 刷新新 App 的 TestFlight 页，构建版本侧栏仍显示“无构建版本”，不能从 Xcode 回执推断 Apple 已处理完成；1008 和 1009 均尚未在该页可选。
- 11:02 联调读回 `https://app.saydian.cn/global/health/ready` 的 revision 为 `a1c1d3b90bf726a7d270b6e1fdc3a4c0bf018810`，未登录访问 `/global/api/saydian-app/v2/health/capabilities` 从原来的 404 变为 401。服务端任务确认能力修复已部署，正在使用合成账号验证上传和回读；401 只证明匿名访问被拒和路由存在，不是已登录真机同步成功。避免在无明确授权时主动重试上传真实会员健康记录。
- 11:04 用户明确允许将该 iPhone 当前账号的待传健康记录发往 `https://app.saydian.cn/global` 作端到端复测。通过 `devicectl` 启动已装 1009，WDA 打开 Watch 页；页面先短暂显示 `Waiting for confirmation`，随后稳定为 `Connected`，原 `Some records have not been uploaded` 和 `Try again` 提示不再出现。未触发低电量手表的手动 `Sync watch`；无原始健康数值进入日志。已请服务端任务仅按脱敏路由/状态/计数核对是否有 batch POST 和确认，因此目前只证明实机 UI 待传提示消失，尚不能证明服务端最终入库。
- 运行 `TMPDIR=/private/tmp flutter build apk --debug --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 尝试 Android 回归。Gradle `assembleDebug` 约 7 分钟无最终结果；同时另一项目 Android 构建和服务端 Argon2 全量测试占用 CPU，磁盘仅余约 5.5 GiB。为避免影响共享机器和服务端验证，主动中断；未生成本轮 `app-debug.apk`，**Android Debug 未通过/未完成**，Release 未执行。此修正只涉及 iOS 本地化字符串和构建号；已完成 iOS 归档、真机、全量 Flutter 测试，但不能把 Android 标为验证通过。

## 12:20 新候选 1010 上传回读

- 含国际设备后台真实连接上报的 1010 已在 iPhone 15 Pro Max 原位安装、启动，并有服务端和后台设备行回读；详细构建、测试、归档哈希及隐私边界见 [设备后台联调记录](../IMPLEMENTATION-LOG-20261001-DEVICE-ADMIN-INTEGRATION.md)。Xcode Organizer 12:20 对 1010 返回 `Upload completed with warnings`，归档状态 `Uploaded with warnings`；Apple 端 TestFlight/版本页仍显示无构建，尚未证实处理成功。
- 新国际 App 的品牌支持网址已保存；价格设为免费，并关闭未实测的 Mac 与 Vision Pro 分发。Apple“添加以供审核”校验仍明确拒绝：无可选构建、审核联系人、年龄分级、内容版权、App 隐私及正式隐私政策 URL。未提交审核，未上线；不得把 Xcode 上传回执视为 App Store 审核通过。

## 13:15 App Store 截图与构建状态

- 12:53 对已签名的 1.0.0 (1010) 归档再次使用 Xcode Organizer 上传，返回 `Upload completed with warnings`。13:05 刷新新 App 的 TestFlight 和版本页，均仍无可选构建；本轮没有再重编或重复上传相同包。签名导出团队 `W7SXQ4A226` 与新 App ID 团队一致。Apple 端处理结果仍未证实。
- 在独立工作树扩展现有离线 Flutter 页面截图工具，以英语（美国）、1284 × 2778 像素渲染未改动的国际版 Health 首页；使用合成 `SAYDIAN User` 与无手表/无健康读数状态，不访问生产账号或接口。先发现图片异步加载导致品牌图标空白，增加预缓存后目标测试通过并重新渲染。最终无 alpha 的 JPEG 为 [ios-global-health-home-en-65.jpg](assets/ios-global-health-home-en-65.jpg)，SHA-256 `9dbcf13dbe3e5fc67f19f47e0d67c9643fea59279c5f25c2cb2b137e214deddd`。首次空白图标版已从 App Store Connect 移除；刷新后确认只有修正版，6.5 英寸 iPhone 截图为 1/10。未上传实机个人健康数据。
- Apple“添加以供审核”最新校验不再报告缺截图，只列三项：必须选择构建、具有“管理”职能的用户填写 App 隐私信息、填写正式隐私政策 URL。现网 `/global/api/saydian-app/v2/auth/capabilities?locale=en` 仍返回 `consentVersion=global-qa-2026-09-10`；对应英文政策标题仍为 `Saydian Global Pre-release Privacy Notice` 且正文称 test service，不可冒充正式上架政策。客户端不填写或发布未经核实的法律与隐私声明。
- 已把现网能力和政策版本回读交给现有“导入-app服务端”任务复核；其中 `login.email=false` 不能单独推断邮箱密码登录失败，须按前述服务端实现与端到端复测判断。App Store 审核账号当前字段未被本轮验证为可登录账号。

## 18:50 二次送审候选准备

- 原因：1010 在 Xcode Organizer 显示已上传但超过六小时仍未进入 TestFlight，无法被 App Store 版本选择；Apple 状态日志唯一上传警告为 iOS 13 最低版本将在 2027 年 4 月后不再符合要求。为避免将未来兼容警告带入新的候选构建，准备独立的 1011。
- 修改：`pubspec.yaml` 从 `1.0.0+1009` 调整为 `1.0.0+1011`；`ios/Runner.xcodeproj/project.pbxproj` 的 Debug、Profile、Release 最低 iOS 版本统一由 13.0 提升至 15.0。该修改不改变业务、API、健康算法、权限声明、设备协议或数据模型。
- 构建环境：共享磁盘曾仅余约 1.5 GiB；已确认没有运行中的 Flutter、Dart 或 Xcode 构建进程后执行 `flutter clean`，只删除该 worktree 可重建的 `build/`、`.dart_tool/` 和 Flutter 生成配置。Xcode 已签名归档和 IPA 均保留。首次 `flutter pub get` 无网络套接字且持续无输出，已对两个精确 PID 正常终止；未修改依赖锁或源文件，后续将以离线依赖恢复和真实构建结果续记。
- 待验证：恢复依赖后执行静态检查、iOS 发行归档、签名/设备族/版本回读及 iPhone 原位安装。1011 只有在 Apple TestFlight 出现后才可选作送审构建；正式英文条款、隐私政策、准确 App Privacy 问卷和可登录审核账号仍是独立提交门槛，不能由本构建替代。

## 20:24—20:39 1011 构建、复测与设备启动

- 依赖恢复：`flutter clean` 后首次在线 `flutter pub get` 在 Gitee `yc_product_plugin` 镜像阶段无进展；精确锁定提交 `5ca3050d7170509d386f548fcae7d5f8b457febf` 已完整下载至 Pub 临时镜像，复用该镜像恢复同一提交的本机缓存。离线解析先报缺 `sqflite_common_ffi`，仅补回锁定的 `2.4.2+1` 后再次离线解析报缺 `flutter_lints`；最终正常 `flutter pub get` 恢复既有锁定依赖，未升级依赖。`cd ios && pod install` 成功恢复 24 个 Pod，`Podfile.lock` 无 Git 改动。
- 静态与回归：`flutter analyze --no-pub` 通过；`python3 scripts/release/test_release_gate.py` 23/23 通过，`git diff --check` 通过；`TMPDIR=/private/tmp flutter test --no-pub --reporter compact` 在 1 分 59 秒后 934/934 通过。测试末尾有关已审健康分析文档版本变更的 `FormatException` 是覆盖拒绝路径的预期输出，最终退出码为 0。
- 发行归档：执行 `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功。App Store IPA 为 `build/ios/ipa/SAYDIAN Health.ipa`，SHA-256 `311015c76a8303f4fd8596ba3957a8e1430b899196ed6c45cde662b160bfb6bf`。归档和 IPA 回读为 `cn.saydian.app.global`、`1.0.0 (1011)`、`UIDeviceFamily=[1]`、`arm64`、`MinimumOSVersion=15.0`，以 `Apple Distribution: Xuewu Tang (W7SXQ4A226)` 签名，`codesign --verify --deep --strict` 通过。没有出现原先 Apple 上传状态日志中的 iOS 13 最低版本警告；SPM 兼容与 WeChat SDK 模拟器 arm64 提示仍为上游依赖的未来兼容提示。
- 真机：同一归档导出 `build/ios/adhoc-iphone15pm-1011/SAYDIAN Health.ipa` 成功，SHA-256 `9eb00127c8b51cc6702944b4020586f43d09371bd4fe672f9d43de8e0434be50`。连接的 iPhone 15 Pro Max（`A3DC94EA-18E8-52EB-B953-60133E11D071`）原位安装后列出 `SAYDIAN Health 1.0.0 (1011)`；`devicectl device process launch` 成功，运行进程存在。此为安装和启动验证，不等同完整 BLE、推送、服务端或 Apple 审核验收。
- 审核资料草案：新增 `GLOBAL-TERMS-20261001.md` 与 `GLOBAL-PRIVACY-NOTICE-20261001.md`。内容按实际实现限定在账号、穿戴设备与健康同步、可选定位天气、明确选择的头像/反馈上传、可选推送与本地蓝牙/相机/照片/联系人功能；不作医疗诊断、零数据收集、零第三方或无条件数据删除承诺。草案尚未标为服务端已审或已发布，也没有改动线上 `global-qa-2026-09-10` 文档。

## 21:05 1011 上传与 Apple 处理状态

- 修改前工作树干净，`git status --short --branch`、`git remote -v`、`git rev-parse HEAD` 回读 `1bb475e9f0c1e68f3fede886adab31afde6c9a04`；`git fetch --prune origin`、`git pull --ff-only` 完成，提示 `Already up to date.`。本轮只追加上传事实记录，不修改源码、配置、构建或原始素材。
- 用户确认上传后，Xcode Organizer 选择 `Runner (cn.saydian.app.global)` 的 `1.0.0 (1011)` 归档，以 App Store Connect 分发。21:05 Xcode 显示 `Upload completed with warnings`，随后状态日志为 `Uploaded to Apple`、构建号 `1011`、提交状态 `Uploaded`。仅见 14 个第三方穿戴框架缺 dSYM 的 `Upload Symbols Failed` 警告，未见 iOS 最低版本警告或上传失败。
- 21:05 后刷新该新 App（Apple ID `6817980969`）的 TestFlight，仍显示“无构建版本”。`App 信息`回读其 Bundle ID 为 `cn.saydian.app.global`，与上传包一致。按 Xcode 本轮 `ContentDelivery.log` 中的精确 `buildUploads` ID，只读回查 Apple 状态：**FAILED**。错误代码 `90683` 两项：`Runner.app` 缺 `NSSpeechRecognitionUsageDescription` 和 `NSAppleMusicUsageDescription`；同代码警告一项：缺 `NSLocationAlwaysAndWhenInUseUsageDescription`。这解释了 Xcode 显示上传成功但 TestFlight 无构建的差异，不能将 Xcode 传输回执视为 Apple 构建处理通过。版本页仍无可选构建，App 隐私页面仍无政策网址和数据问卷；现网 `auth/capabilities?locale=en` 仍返回预发布 `global-qa-2026-09-10`。未提交审核，未上架。

## 21:12—21:20 1012 定向修复与构建

- 修改前在 `e77a7bc` 的干净工作树执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin` 和 `git pull --ff-only`，确认 `Already up to date.`。对照锁定的玉成穿戴插件源码：iOS 包含语音识别入口和 `SFSpeechRecognizer` 引用，内置 `DFUnits` 的音乐控制类引用 `MPMediaItem`；因此 Apple 的两项缺失用途说明有二进制来源，并非主 App UI 当前宣称的常规健康读数功能。客户端自身仅请求 `locationWhenInUse`，不把 Apple 的“始终定位”警告冒充真实后台定位能力。
- 影响范围：`pubspec.yaml` 构建号从 1011 升到 1012；`ios/Runner/Info-AppStore.plist` 和 `ios/Runner/Info.plist` 新增语音识别及音乐资料库的条件性用途说明；发布门禁测试要求这两项非空且明确不将未使用的始终定位授权写入 App Store plist。未改网络目标、权限调用、健康算法、设备协议或服务端。其他语言目前回退到英文用途说明，没有伪造本地化能力。
- 验证：`plutil -lint` 对两个 plist 通过，`git diff --check` 通过；`python3 scripts/release/test_release_gate.py` 23/23 通过；`flutter analyze --no-pub` 无问题；`TMPDIR=/private/tmp flutter test --no-pub --reporter compact` 934/934 通过（2 分 57 秒）。末尾 `FormatException: Reviewed analysis document changed` 为拒绝路径的预期测试输出，最终退出码为 0。Android 按用户要求后置，未作为本次 iOS 包通过项。
- `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 成功；签名归档 `build/ios/archive/Runner.xcarchive` 及 IPA `build/ios/ipa/SAYDIAN Health.ipa`。IPA SHA-256 `3d943a9912fffddb748a541dec80bf1539d79dbc27246e357ce3846ac68d491f`；最终包内回读 `cn.saydian.app.global`、`1.0.0 (1012)`、`UIDeviceFamily=[1]`、iOS 15.0、两项新增用途说明；归档 `codesign --verify --deep --strict` 通过。Xcode 提示仍有 Flutter 默认启动图和部分依赖的未来兼容警告，不标成零警告。独立复制归档到 `/Users/saydian/Library/Developer/Xcode/Archives/2026-10-01/SAYDIAN-Health-1.0.0-1012.xcarchive`，Organizer 确认 1012 可选。
- 21:25 使用 Xcode Organizer 将 1012 上传 App Store Connect。Xcode 显示 `Upload completed with warnings`、归档 `Uploaded to Apple`；14 项警告均为第三方穿戴框架缺少 dSYM。按本轮 `ContentDelivery.log` 精确构建上传 ID `b23d8d19-205b-4981-9adc-5fa2ef14bebd` 回读 Apple 状态，21:26 为 `PROCESSING`、错误/警告数组为空；此时不能标为处理完成或已提交审核。

## 21:26 审核演示账号初验

- 用户提供国际版 App Store 审核演示账号；未把密码写入代码、测试、提交、文档或对外回复。按客户端实际路径，对生产 `POST https://app.saydian.cn/global/api/saydian-app/v2/auth/login` 进行一次密码登录初验，响应业务 `code=401`、`message=Please sign in again.`，没有会话。此结果不能证明账号是否存在或密码是否正确，但意味着当前不能把它作为已验证可登录的审核账号。已请原“导入-app服务端”任务只读核对线上路由/账号状态；未创建或重置账号，也未向该任务传递密码。
- 服务端任务随后按线上 revision `6ea9dd9` 的源码和公开 `/global/health/ready` 只读核对：请求确实进入国际版登录控制器，不是路由鉴权或过期 token；同一 401 被有意用于账户不存在、未设密码、非 ACTIVE、密码不符，以及可能的邮箱未验证等条件，防止账户枚举。公开响应无法安全区分，当前没有经核实可直接提供 Apple 的演示会话；需要经授权的私有后台只读状态核查或由账号持有人在 App 中实际登录。此结论不把 401 擅自归因于某一个条件。
- 1012 真机复核：同一归档以 `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/adhoc-iphone15pm-1012 -exportOptionsPlist ios/ExportOptions-AdHoc-iPhone15pm.plist` 导出成功。Ad Hoc IPA SHA-256 `4352f2dd6999cd11c0d9a86edce96e8a89bce51d3ae33e608405ce4404b70347`；解包回读 Bundle ID 和构建号，`devicectl device install app` 对连接的 iPhone 15 Pro Max 原位覆盖成功，安装清单显示 `SAYDIAN Health 1.0.0 (1012)`，`devicectl device process launch` 成功。仅证明 1012 在目标设备安装与启动，不代表账号登录、手表 BLE 或 Apple 审核通过。
- 21:27 Apple `buildUploads` 状态仍为 `PROCESSING`，已出现 `90683` 缺 `NSLocationAlwaysAndWhenInUseUsageDescription` 的**警告**，无错误。客户端自身仅请求使用期间定位，暂未为消除警告伪称后台定位；待最终处理结果判断是否阻断。

## 2026-10-02 审核账号与提交门槛复核

- Apple 已将 `1.0.0 (1012)` 构建上传状态处理为 `COMPLETE`，仅保留 `NSLocationAlwaysAndWhenInUseUsageDescription` 的 90683 警告；TestFlight 已列出 1012，但标记“缺少出口合规证明”。静态依赖回读显示本包包含 SQLCipher 以及穿戴 SDK 的 AES 接口，因此出口合规应如实选为“标准加密算法”，不能报为不使用加密或仅使用 Apple 系统加密。是否需附加文稿仍取决于 Apple 后续问题与实际分发地区，不能伪造声明。
- 用户再次提供审核演示账号后，对生产登录接口进行一次无令牌密码登录复测仍为 401。随后经用户已打开的生产服务器终端进行只读数据库查询：该邮箱在国际版 `saydian_global` 的 `User` 表中不存在。此项只输出布尔结果；不记录邮箱、密码、令牌或健康数据。因此问题已收敛为“账号尚未创建”，不是路由、登录守卫或已存在账号的密码校验失败。
- App Store 版本页当前仍缺：可选审核构建（1012 先要完成出口合规）、准确 App Privacy 问卷及正式 App 专用隐私政策 URL、有效审核登录账号、版权字段。公开的商城隐私政策只覆盖订单/物流/支付等电商数据，不覆盖本 App 的账户、穿戴设备和健康同步，不能挪作审核隐私政策。未经授权未创建演示账号、未修改后台账号状态、未把无效凭据填写给 Apple、未提交审核。

### 2026-10-02 审核账号交叉复核

- 用户说明所给账号可在实际 App 登录。为排除字段名差异，按国际版生产源码的准确请求形态（邮箱置于 `username`、`POST /global/api/saydian-app/v2/auth/login`）再次只读认证探测；结果仍为业务 `401`。响应内容、账号、密码、令牌均未落盘或输出。
- 同一台 iPhone 15 Pro Max 当前列出三个独立包：`SAYDIAN Health` (`cn.saydian.app.global`, `1.0.0 (1012)`)、`Say Ring` (`cn.saydian.ring`, `1.0 (1016)`) 与 `Saydian赛电`（国内包）。国际版 `AppController.production` 明确创建 `GlobalSaydianApiClient`，且网络边界禁止任何国内 `/api/v1` 回退。因此，所述“实际 App”若为后两者，不可将其账号直接作为国际版的 Apple 审核凭据；在确认具体 App 前不新建或改写生产账号。
