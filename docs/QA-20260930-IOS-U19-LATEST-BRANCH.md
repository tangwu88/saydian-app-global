# 2026-09-30 iOS U19 最新分支更新与真机安装

## 目标与基线

- 用户要求更新到线上最新提交分支，并继续使用 iPhone 15 Pro Max 真机调试。
- `git fetch --prune --tags origin` 后，`origin/main` 的最新两笔仅为本机已推送的 iOS 调试记录；最新提交的功能分支为 `origin/feature/u19-eb1`。
- 该分支相对 `main` 独有 23 笔 U19/EB1 功能、修复与 QA 提交。工作树干净后切换为本地跟踪分支 `feature/u19-eb1`。
- 更新基线：`00e899fa381ff92c622714212a5c67ebb6d1d6a1`，切换后与 `origin/feature/u19-eb1` 差异 `0/0`。

## 依赖与构建准备

- 分支版本为 `0.1.23+1007`，Bundle ID 为 `cn.saydian.app.global`，显示名为 `SAYDIAN Health`。
- 保留本机忽略配置 `ios/Flutter/Local.xcconfig`，只提供现有开发团队 `W7SXQ4A226`；未复制国内凭据或改变国际 Bundle ID。
- 确认没有进行中的 Flutter/Xcode 构建后，只删除旧分支 `build/ios`、旧 dill 和可重建 Xcode DerivedData/ModuleCache；保留源码、Pods、签名和手机数据。

以下命令通过：

```bash
flutter pub get
flutter gen-l10n
cd ios && pod install
flutter analyze --no-pub
git diff --check
```

- `pod install` 补齐 `pubspec.lock` 已使用但该功能分支 `ios/Podfile.lock` 漏记的 `share_plus 0.0.1`；仅增加 6 行，无 Pod 版本漂移。
- 静态分析为 `No issues found`，本轮没有业务源码修改。

## iPhone 15 Pro Max 结果

执行：

```bash
flutter run -d <connected-iphone-udid> --debug --no-pub \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update \
  --dart-define=QWEATHER_API_KEY=
```

- Xcode Debug 构建成功，耗时 `43.4s`；自动使用开发团队 `W7SXQ4A226` 签名。
- 设备应用列表实核 `cn.saydian.app.global` 已更新为 `0.1.23 (1007)`，设备进程列表存在新 `Runner.app/Runner` 和 `debugserver`。
- LLDB 仍提示设备 shared cache 不在磁盘，可能降低调试性能；不等于编译或签名失败。

## 当前阻断与边界

- 安装和启动已完成，但 Dart VM Service 超过数分钟仍未被 Flutter 发现，主机侧没有建立 `iproxy` 端口转发。
- 同一 Bundle ID 的 Xcode 控制台已明确记录 `FlutterDartVMServicePublisher` 因 iOS 本地网络权限被拒绝而无法发布服务；该系统权限状态在覆盖安装后保留。
- 已停止无结果的等待，没有卸载 App、清除数据、改变 Bundle ID 或绕过手机隐私设置。
- 结论：**最新线上功能分支已更新并安装成功；真机 Flutter Debug/热重载尚未通过。**
- 下一步需要在 iPhone 打开“设置 → 隐私与安全性 → 本地网络 → SAYDIAN Health”，再重新执行 `flutter run` 并验证 VM Service 与热重载。

## 21:13 覆盖重装与 Xcode 有线调试复验

- 复验前 `feature/u19-eb1` 与 `origin/feature/u19-eb1` 一致，基线为 `c4bbb58faccc73b301cfbcfd6728c90109144641`；没有修改业务源码。
- 使用相同生产国际域名参数执行 `flutter build ios --debug --no-pub`，Xcode 构建成功，耗时 `42.8s`。
- `codesign --verify --deep --strict` 通过；产物标识为 `cn.saydian.app.global`、版本 `0.1.23 (1007)`、团队 `W7SXQ4A226`，并带 `get-task-allow=true`。
- `devicectl device install app` 对 iPhone 15 Pro Max 执行覆盖安装成功；未卸载 App、未清除手机数据、未改变 Bundle ID。
- 直接从 `devicectl` 独立启动 Debug 包时，应用按 Flutter 限制明确终止并提示必须由 Flutter 工具或 Xcode 启动；该结果不能记作桌面独立启动通过。
- 为检查独立启动路径，尝试 Profile 构建；Xcode 因未登录开发者账号，且现有通配 Provisioning Profile 不包含 Push Notifications 与 Associated Domains 能力而拒绝签名。没有删除 entitlement 或降级能力绕过门禁。
- 随后在 Xcode 打开 `ios/Runner.xcworkspace`，Run 目标为 `Runner / iPhone15pm`。Xcode 状态实核为 `Running Runner on iPhone15pm`，设备同时存在 `debugserver`。
- 设备应用列表实核安装版本仍为 `0.1.23 (1007)`，安装容器为 `8DDB4F56-078C-48E5-81EB-62057E4437EC`；运行进程 PID `21891` 的路径与该容器完全一致。
- 结论：**覆盖重装、签名、版本回读、Xcode/LLDB 有线真机调试均通过，调试会话保持运行。** Flutter VM Service/热重载仍受此前手机“本地网络”权限状态影响，本轮不把 Xcode 调试通过扩大为热重载通过。
