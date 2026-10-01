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
