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
