# 2026-10-02 Health 顶部个人资料同步

## 原因与范围

- Health 首页此前显示固定品牌图标及登录态 `session.displayName`，没有读取个人资料的 `nickname` 和 `head_portrait`。个人资料保存后控制器更新 `memberProfile`，页面顶部仍可能继续显示另一套身份信息。
- 仅调整国际版 Flutter Health 首页顶栏：左侧显示 Health，右侧资料区使用个人资料头像/昵称并保留消息入口；资料字段未加载或为空时回退到登录名称、体验访客名称或本地化默认名称，并使用头像占位图。无服务端、资料保存契约或健康数据逻辑改动。

## 修改前检查与保护

- 分支：`codex/global-device-admin-20261001`；修改前 HEAD 与 `origin/codex/global-device-admin-20261001` 均为 `304bab869abe65dacd5cc744fc0f51475f87b2c4`；`git fetch --prune` 成功。
- 工作树含此前其他未提交的国际化、自动重连、客服、资料等变动。全部保留；没有拉取、回退或清理。原有改动 checkpoint 在 `build/ios/real-device-qa-20261002/checkpoints/before-profile-fix.patch` 与 `before-profile-fix-untracked.tar.gz`；本轮另存修改前 `pages.dart` 为同目录下 `before-health-profile-header-20261002.dart.bak`。
- 检查 `ps -axo pid,command | rg '[f]lutter run|[x]codebuild'`：开始构建前没有同仓库 iOS 构建。

## TDD 与修改

- RED：新增 `Health header uses the current personal profile identity` 后运行 `TMPDIR=/private/tmp flutter test --no-pub test/ui_shell_test.dart --plain-name 'Health header uses the current personal profile identity' --reporter expanded`，按预期失败：未找到 `Profile Name`。
- GREEN：Health header 优先读取 `memberProfile.nickname/head_portrait`，昵称回退到登录态和体验/默认文案；头像复用 `_MemberAvatar` 安全图片与占位样式。增加资料对象变更并通知后的头像 URL/昵称更新断言，以及空字段回退用例。
- 新标题与底部导航有同名 `Health`，原导航 QA 测试的文字 Finder 因找到两个“健康”而失败。按根因将 `test/qa_user_flows_test.dart` 的定位限定到底部 `NavigationBar` 内；其定向用例随后通过。

## 验证

- `dart format lib/ui/pages.dart test/ui_shell_test.dart test/qa_user_flows_test.dart`：通过，无格式变更。
- `TMPDIR=/private/tmp flutter test --no-pub test/ui_shell_test.dart --reporter compact`：通过，58 项。
- `TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub --reporter json`：首次失败 1 项，`notifications, care, sport and preference pages stay navigable`，原因是重复的“健康”文字使旧 Finder 不唯一；修改导航限定后重跑：1,026 项通过。日志 `build/ios/real-device-qa-20261002/profile-health-header-shanghai-final.jsonl`。
- `TMPDIR=/private/tmp TZ=UTC flutter test --no-pub --reporter json`：1,026 项通过。日志 `build/ios/real-device-qa-20261002/profile-health-header-utc.jsonl`。
- 第一次 `TMPDIR=/private/tmp flutter analyze --no-pub` 把本轮 `.dart` 格式备份当作源码扫描，产生缺失相对导入错误；将备份改名为 `.dart.bak` 后重跑：`TMPDIR=/private/tmp flutter analyze --no-pub` 零问题。
- `git diff --check`：通过。
- `TMPDIR=/private/tmp flutter build ios --profile --no-codesign --no-pub`：通过，生成 61.8 MB `build/ios/iphoneos/Runner.app`。
- `TMPDIR=/private/tmp flutter build ios --debug --no-codesign --no-pub`：通过，iOS Debug 设备构建完成。
- iPhone 15 Pro Max/iOS 26.6，UDID `00008130-001C098C2290001C`：`TMPDIR=/private/tmp flutter run --debug --no-pub --device-connection attached --device-id 00008130-001C098C2290001C` 成功签名、安装、启动并连接 Dart VM Service `http://127.0.0.1:58497/duMgKoSOMEc=/`。资料头像 API 返回 200，头像图片 GET 返回 200。Flutter Debug 会话保持附加。启动期间应用自行进行一笔后台 POST（201，requestId `cf70527f-1d52-48bc-9f71-cbacdd6c2907`）；没有手动触发健康同步。更新清单 GET 404 是已有后台配置问题，不影响本次顶栏显示。
- Android Debug 曾运行 `TMPDIR=/private/tmp flutter build apk --debug --target-platform=android-arm,android-arm64 --no-pub`；首次依赖解析期间 Gradle 多个 HTTPS socket 长时间等待读取、无 APK 产物。依据用户此前“Android 版本放后面”的范围和该网络阻塞中止；Android Debug/Release 本轮未验收。

## 提交边界

- 本次源改动：`lib/ui/pages.dart`、`test/ui_shell_test.dart`、`test/qa_user_flows_test.dart` 和本记录。工作树其他既有修改不应混入本次提交。
- App Store Connect 状态未改变。Physical Debug 不等于 App Store 归档或审核提交。
