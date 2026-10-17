# 2026-10-17 国际版苹果真机调试重新开启

用户要求开启苹果真机调试，沿用本任务的国际版及此前指定iPhone 15 Pro Max，正常 `lib/main.dart` / `cn.saydian.app.global` / `1.0.1 (1018)`，美国第一方接口。另一个已连接iPhone XR不操作，不因浏览器显示其他App页面切换产品。

## 基线与数据保护

- 起始HEAD `869465004a8e74e7fe3084fa79e5dddeee970896`，工作树干净；`git fetch --prune origin`、`git pull --ff-only`成功，Already up to date。运行输入相对已完整验证的 `69e1ecfe0845aab8e2ebfeedd2db1b9003b5c49e` 无差异（lib、ios、android、pubspec.yaml）；没有其他Flutter/Xcode构建进程。独立记录分支 `codex/ios-debug-restart-20261017`。
- 指定iPhone15pm / iPhone 15 Pro Max / UDID `00008130-001C098C2290001C` 实时connected、USB wired、paired、booted、iOS26.6、Developer Mode Enabled。手机已有国际版1.0.1(1018)，该安装路径没有运行进程。前轮Flutter PID文件已不存在，因此不假称旧会话仍附加。
- 复用10-16已验证Debug二进制 `build/ios-debug-20261016-us/Runner.app`，本轮 `codesign --verify --deep --strict`再次成功，包名/版本实际读取一致，Runner SHA256仍为 `f3951d0890bcd3389fe0b6ef71f6c5924636a4a39509932d5ae974e3e233be65`。本轮未重新构建或改变Xcode/Pod设置。
- 在私有 `/private/tmp/saydian-ios-debug-20261017/` 下备份本App Documents、Library/Application Support、Library/Preferences，0700/0600权限，不导出Keychain或解密健康库、不进Git。手动devicectl覆盖安装后、启动前再复制核对，3个数据库文件共5,431,296bytes逐字节一致，不卸载、不清库。后续Flutter内部二次安装和正常运行不冒称这次同一比对。

## 调试启动

`flutter --no-version-check run --debug --no-pub -d 00008130-001C098C2290001C --device-connection=attached --target=lib/main.dart --use-application-binary=build/ios-debug-20261016-us/Runner.app --no-uninstall-first`，传入 `SAYDIAN_API_BASE_URL=https://app.saydian.com`、`.com/global/api/saydian-app/v2/support/app-update`、空JPUSH_APP_KEY及私有VM/PID输出文件。正常产品入口，日志只私有保存，控制台过滤会话URL和业务记录。附加、热重载及最终结果随后追加。

本轮只开启调试，不运行QA入口、不启用镜像、不替换用户账号、不修改商店审核或服务器、不宣称两戒指业务验收通过。运行输入未变，本轮不重复全量Flutter/Android/Profile/Release测试或构建；10-16已记录的500及更新404不能据本次启动自动视为修复。

## 实际结果

- Flutter内部再次覆盖安装并启动21.3秒，同步文件77ms；设备官方安装列表与进程URL逐项匹配，本国际版PID40310。另一台XR未操作。
- Dart VM getVM HTTP200、type=VM、main isolate存在；Flutter PID实际存活，通过SIGUSR1执行热重载成功：`Reloaded 0 libraries in 521ms (compile:15ms, reload:0ms, reassemble:237ms)`。无源码变化，0 libraries符合预期。
- 启动日志未见Lost connection、Application finished、Unhandled Exception、EXCEPTION CAUGHT BY或RenderFlex overflow。不是新的登录、戒指活动/睡眠或美国同步验收。
- DevTools本地HTTP200，已请求在Codex右侧打开，工具返回queued；不冒称已目视检查面板。访问令牌/VM URI/PID/设备数据库与完整日志仅本机私有保存，不提交Git。
- 保持Flutter Debug附加，手机需保持USB与Mac调试进程连接。`git diff --check`通过，代码/正式包/服务器/商店提交均未修改。本轮只补交接记录，不重跑未变化产品的全量测试或发行构建。
