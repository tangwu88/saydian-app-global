# 2026-10-16 国际版 iPhone 真机调试

## 范围与基线

用户要求开启真机调试，按当前国际版 iPhone 执行。正常入口 `lib/main.dart`，版本 `1.0.1 (1018)`，第一方美国接口 `https://app.saydian.com/global/api/saydian-app/v2`；不改算法、权限、iOS 活动/睡眠范围、商店审核或部署，不启用手机镜像。

起始 HEAD `af2d424a47875abdd2c0abd4898e5cf23cbc8e48`，工作树干净；`git fetch --prune origin`、`git pull --ff-only` 成功。创建 `codex/ios-device-debug-20261016` 记录分支，不切换或合并 main，不改同事代码。已阅读 AGENTS、当前交接、最新上传记录、历史 Debug、复盘和回归清单。

## 设备与安装前保护

- `xcrun devicectl list devices`、`device info details`、`flutter devices` 实时确认指定 iPhone 15 Pro Max / iPhone15pm / iOS 26.6，通过 USB wired、paired、booted、Developer Mode Enabled。UDID `00008130-001C098C2290001C`。
- 当前安装 `cn.saydian.app.global / 1.0.1 (1016)`。已安装 URL 与现有另一个 Runner PID 35474 的 URL 不同；未终止其他 App。没有另一个 Flutter run 或 xcodebuild 编译本仓库。
- 覆盖安装前，将本 App Documents、Library/Application Support、Library/Preferences 复制到 `/private/tmp/saydian-ios-debug-20261016/` 私有目录，0700/0600 范围权限，不进 Git、不导出 Keychain、不解密健康库。两个数据库文件共 5,361,664 bytes，摘要仅私有保存；未见该健康库 WAL/SHM。
- `flutter --no-version-check analyze --no-pub` 无问题，2.4 秒。设备信息和日志仅留私有目录，不上传健康数据。

## 构建尝试与修正

- 本机 Flutter 3.44.9 / Dart 3.12.2 / Xcode 27.0 (27A266a)，与历史 Xcode 26.6 不同。
- 首次 `SAIDIAN_DISABLE_REMOTE_PUSH=true SAYDIAN_API_BASE_URL=https://app.saydian.com flutter --no-version-check build ios --debug --no-pub --target=lib/main.dart --build-name=1.0.1 --build-number=1018 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=` 失败，Xcode 5 秒。报告 Pods 的 IPHONEOS_DEPLOYMENT_TARGET=13.0，当前工具支持范围 15.0–27.0；原始 `build.log` 保留，未安装、未清理缓存。
- 第二次仅使用私有 `debug-xcode27.xcconfig`，内容 `IPHONEOS_DEPLOYMENT_TARGET = 15.0`，以 `XCODE_XCCONFIG_FILE` 作用于本次 Debug 构建；相同命令加 `-v` 保存完整诊断。不修改跟踪的 Podfile、项目、正式包或设备最低支持承诺。结果随后追加。

- 第二次成功：Xcode 23.3 秒、Flutter 总计28.8秒。产物复制到 `build/ios-debug-20261016-us/Runner.app`；`codesign --verify --deep --strict` 通过，team W7SXQ4A226、get-task-allow=true、Profile包含指定UDID、版本1.0.1(1018)、本次调试MinimumOS=15.0。Runner SHA256 `f3951d0890bcd3389fe0b6ef71f6c5924636a4a39509932d5ae974e3e233be65`。仅保留工具/厂商兼容警告，未改源码或正式签名包。
- `xcrun devicectl device install app --device 00008130-001C098C2290001C build/ios-debug-20261016-us/Runner.app` 实际成功，覆盖安装后未启动时，再复制Documents和Application Support；两个原数据库全部逐字节一致，共5,361,664 bytes。此证明仅针对本次手动安装，不冒充后续正常运行、内部二次安装或业务内容验收。
- 使用 `flutter --no-version-check run --debug --no-pub -d 00008130-001C098C2290001C --device-connection=attached --target=lib/main.dart --use-application-binary=build/ios-debug-20261016-us/Runner.app --no-uninstall-first`，同时传入前述.com API/更新地址和空JPUSH_APP_KEY、私有VM URI/PID文件。运行日志只写私有目录，控制台过滤调试令牌/业务记录。附加结果随后追加。

## 实际附加结果

- Flutter 内部再次覆盖安装并启动，19.6秒；同步文件139ms。官方设备列表确认已安装1.0.1(1018)，安装URL与本次运行PID35545逐项匹配，未影响另一App的PID35474。
- 私有VM URI执行HTTP `getVM` 返回200，`result.type=VM`且包含main isolate。Flutter PID存活，发送SIGUSR1后真实回执 `Reloaded 0 libraries in 262ms (compile:15ms, reload:0ms, reassemble:53ms)`；没有源码变化，0 libraries符合预期。
- 当前启动日志没有Lost connection、Application finished、Unhandled Exception、EXCEPTION CAUGHT BY或RenderFlex overflow。没有可供重新验收登录/同步的第一方请求日志；.com来源已由编译参数和现有GlobalEnvironment校验，不冒称新业务HTTP回读通过。
- DevTools本地HTTP返回200、1706bytes，已请求在Codex右侧打开；工具返回queued，不假称已目视检查面板。VM令牌、DevTools会话地址和PID控制文件仅留私有目录，不进Git。
- 保持Flutter Debug会话附加。没有修改产品代码、版本、正式包或商店提交。`git diff --check`通过；本轮仅记录并启动调试，不重复全量测试/发行构建，不把这次热重载当作LuckRing/QRing业务或美国数据同步验收。

## 验收边界

本轮目标是 Debug 安装和附加、VM service / 热重载。完整双时区测试、Android、Profile/Release、XCTest、两戒指活动/睡眠和美国同步不在本次重新验收范围；不得把工具连接当作这些流程通过。Debug 必须保持 Mac 调试进程与 USB 连接，不能当作脱离调试器的独立启动稳定性证明。

## 用户“继续”后的真机观察

- 接续基线 `a57365e8b0bc0c818f471d1cce4a2afb97119cd3`，工作树干净；`git fetch --prune origin`、`git pull --ff-only` 成功。独立记录分支 `codex/ios-debug-observations-20261016`；不修改运行时代码或重建。
- 实时设备仍connected，Flutter进程存活；VM getVM/getIsolate成功，main pauseEvent=Resume。通过官方Flutter inspector只读取当前widget类名，包含 `GlobalAuthPage`，仍停留在登录/注册页；不输出文本框值、密码、成员数据或健康值。临时inspector object group读取后dispose，不改变产品状态。
- 实际网络审计共有13个响应：200共10次、500两次、404一次；所有请求均GET、host均 `app.saydian.com`。`e189a4489bdb` 对应 `/global/api/saydian-app/v2/auth/capabilities`，最初两次500，之后7次200；不把后续成功当作500根因已修复。
- 更新检查 `/global/api/saydian-app/v2/support/app-update` 曾返回404。只读服务端实现显示，独立产品更新配置未公开时故意返回NotFound，App已有英文不可用提示并保持隔离；未发布未经核对的清单、安装包或商店状态，不回退国内。当前没有实际服务端响应正文，因此“配置未发布”仍是与代码一致的解释，不声称已核对数据库配置。
- 从Mac补充HTTP验证未成功：Python urllib公开能力GET读取超时；curl正常域名能力/更新请求各12秒超时、HTTP000；使用 `--resolve app.saydian.com:443:47.85.43.52` 保留证书校验的美国直连复测也各12秒超时。系统DNS当前返回 `198.18.0.77`，不是部署配置的47.85.43.52；不擅自改Mac代理/DNS、服务器或TLS。不能用这次桌面网络失败断言美国服务已宕机，真机此前多次200也不能证明当前所有接口正常。
- 启动日志仍无异常、断连或Application finished；无LuckRing/QRing连接、POST登录或健康上传证据。未启动测量、伪造ACK、自动换账号或使用商店审核账号承接用户戒指数据。已请用户在手机登录美国账号，再逐个连接两戒指、同步活动/睡眠；密码只在手机输入。待用户操作后再验收真实连接、服务器确认和历史显示。
