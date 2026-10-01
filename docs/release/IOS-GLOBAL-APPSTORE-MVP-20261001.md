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
