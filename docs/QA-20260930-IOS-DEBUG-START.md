# 2026-09-30 iOS 真机 Debug 启动记录

## 目标与边界

- 目标：把国际版客户端安装到 iPhone，并保持 Flutter Debug、Dart VM Service 和热重载连接。
- 本轮不修改业务逻辑，不登录账号，不连接手表，不执行支付、健康写入、OTA 或推送验收。
- 开始时间：2026-09-30 14:18 CST。基线 `e7bda6e6fc45f889d89c3bd1f0da6fa7e35bf5b5`，`main` 与 `origin/main` 一致且工作树干净。

## 环境与设备

- Flutter `3.44.9`、Dart `3.12.2`、Xcode `26.6 (17F113)`、CocoaPods `1.16.2`。
- iPhone 15 Pro Max，iOS `26.6 (23G71)`；`devicectl` 与 `flutter devices` 均识别为已连接。
- 国际版 Bundle ID 保持 `cn.saydian.app.global`。本机忽略文件 `ios/Flutter/Local.xcconfig` 只设置开发团队 `W7SXQ4A226`，未进入 Git。

## 空间与依赖准备

- 初始系统可用空间约 `788 MiB`，不足以执行首次 iOS 全量构建。
- 确认无 `flutter run/build` 或 `xcodebuild` 后，删除约 `2.1 GiB` 可重建 Xcode DerivedData。
- 另删除旧国内客户端中被 Git 忽略的 `app/intermediates`、`ios-profile-usb` 和 `ios-native-tests` 缓存；保留 APK、IPA、XCArchive、测试记录、源码、签名材料和手机数据。最终可用空间约 `10 GiB`。

执行并通过：

```bash
flutter pub get
flutter gen-l10n
cd ios && pod install
```

- `pod install` 补齐当前 `pubspec.lock` 已使用但 `ios/Podfile.lock` 缺失的 `share_plus 0.0.1` 条目。
- 仅锁文件发生 6 行新增；无 Pod 版本漂移，无业务源码改动。

## 构建、安装与调试

使用已连接 iPhone 的设备标识执行：

```bash
flutter run -d <connected-iphone-udid> --debug --no-pub \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update \
  --dart-define=QWEATHER_API_KEY=
```

实际结果：

- Xcode Debug 构建成功，耗时 `135.2s`；自动选择开发团队 `W7SXQ4A226` 完成设备签名。
- 安装与启动完成，总安装/启动阶段 `135.8s`。设备应用列表实核 `Saydian` / `cn.saydian.app.global` / `0.1.21 (1004)`。
- 设备进程列表存在本次 `Runner.app/Runner`；Dart VM Service 与 Flutter DevTools 均连接成功。
- 执行一次 `r` 热重载：`Reloaded 8 of 2206 libraries in 760ms`，交互式真机调试通道通过。
- 启动日志中的结构化第一方请求 host 为 `app.saydian.cn`，涉及 update manifest 与 API。
- 国际更新清单请求实际返回 HTTP `404`；这是功能不可用记录，不计为更新接口通过，也不阻断本轮 Debug 启动。

## 失败、警告与处理

- 首次 LLDB 提示无法读取设备磁盘 shared cache，可能降低调试性能；不影响本轮安装、VM Service 连接和热重载。
- Dart VM Service 发现超过 60 秒，继续等待后正常连接；没有通过重装、改 Bundle ID 或移除隔离配置绕过。
- `sqflite_sqlcipher` 与 `yc_product_plugin` 尚不支持 Swift Package Manager；当前 CocoaPods 构建通过。
- `WechatOpenSDK-XCFramework` 缺 Apple Silicon 模拟器 arm64，本轮使用物理 iPhone，不计为模拟器通过。
- 运行中出现一次 `TUIKeyboardContentView` / `TUIKeyplane` 系统键盘约束冲突，UIKit 自动打破 `TUIKeyplane.height` 约束后恢复；未观察到进程退出，本轮未执行视觉复现或源码归因。

## 验收结论与未验证项

- 已通过：国际版 Debug 编译、开发签名、真机安装、启动、进程存活、Dart VM Service、DevTools 和热重载。
- 未执行：Profile 独立冷启动、三次桌面启动、APNs、真实登录、手表连接/同步、健康数据、支付、完整自动测试与发布构建矩阵。
- 当前 `flutter run` 必须保持运行才能继续 Debug；退出该进程后 Debug App 不作为独立桌面启动验收。

## 20:19–20:38 同机恢复记录

- 用户确认继续使用 iPhone 15 Pro Max。先执行 `fetch --prune` 与 `pull --ff-only origin main`；本地和远端均为 `72a31f1`，没有新提交，也没有生成空提交。
- 第一次恢复时 Debug 编译成功，但 Xcode 自动化返回 `Failed to find project Runner: 不能获取对象`。检查发现 Xcode 活动窗口停在 Archives，而不是 `Runner.xcworkspace`。
- 打开正确工作区后，Scheme 为 `Runner`、目标为 `iPhone15pm`。Xcode 直接 Run 可完成安装并显示 `Running Runner on iPhone15pm`，证明项目、签名、设备和原生调试器可用。
- Xcode 控制台确认 Dart JIT VM 在设备端监听，但 iOS 拒绝 `FlutterDartVMServicePublisher` 的本地网络服务发布；外部 `flutter attach` 因此无法自动发现。本轮没有擅自修改手机隐私权限。
- 停止该临时会话后，仅删除本轮可重建的 Runner DerivedData、ModuleCache 和一个旧 Runner DerivedData；源码、Pods、`build/ios`、签名及手机数据均保留。
- 保持 Runner 工作区为活动窗口后重跑原 `flutter run`：Xcode 构建 `69.5s`，安装/启动 `95.1s`，Dart VM Service 与 DevTools 连接成功。
- 最终热重载：`Reloaded 0 libraries in 267ms`。国际更新清单仍返回 HTTP `404`，与首次记录一致；Debug 会话保持运行。
