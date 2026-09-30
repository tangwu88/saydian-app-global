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

## 21:22 本地网络授权后 Flutter 热重载复验

- 用户在 iPhone 允许本地网络访问后，Xcode 控制台不再出现 `FlutterDartVMServicePublisher` 权限拒绝，并确认 `0.1.23 (1007)` 的 Dart VM Service 已监听。
- 首次切换到 `flutter run` 时，生成态 `.flutter-plugins-dependencies` 只列出部分插件，`pod install` 因此临时缩减 `Podfile.lock`，Xcode 构建失败。执行 `flutter pub get` 和 `cd ios && pod install` 后恢复完整的 15 个 iOS 插件，`Podfile.lock` 回到已提交状态；未手工改依赖或业务源码。
- 第二次 `flutter run` 的 Xcode 构建成功，耗时 `99.7s`；安装与启动后，Flutter 超过 60 秒才发现服务，最终完成文件同步并建立 VM Service 与 DevTools 的本机 USB 隧道。
- 执行热重载成功：`Reloaded 0 libraries in 285ms`。随后调试通道短暂丢失，但设备仍连接，App 进程未退出。
- 使用 `flutter attach -d <connected-iphone-udid>` 重新连接成功，文件同步耗时 `8.2s`，VM Service/DevTools 隧道重新建立；持续观察 15 秒未再断开，当前调试会话保持运行。
- 设备再次回读为 `cn.saydian.app.global`、`0.1.23 (1007)`；安装容器 `F465D2B0-231C-4161-897B-7743EA5292A1` 与运行进程 PID `21958` 路径一致，主机存在对应 `flutter attach` 与 `iproxy` 进程。
- 结论：**本地网络授权生效，Dart VM Service、DevTools 和热重载均已真机通过。** 首次热重载后的单次 USB 调试通道丢失已如实保留，不扩大为长期稳定性通过。

## 22:24 新真机调试会话

- 上一轮 Flutter 会话已断开，但 iPhone 15 Pro Max 仍有线连接，设备上保留 `cn.saydian.app.global` 的 `0.1.23 (1007)`。
- 以相同国际生产域名参数执行 `flutter run -d <connected-iphone-udid> --debug --no-build --no-pub`；Xcode 增量构建成功，耗时 `17.0s`。
- 安装和启动阶段耗时 `103.6s`，其中 Dart VM Service 发现超过 60 秒；最终设备文件同步耗时 `127ms`，VM Service 与 DevTools 的本机 USB 隧道均建立成功。
- 设备回读安装容器为 `C42033DF-1238-42F3-B0ED-A4A32505CFF3`，运行进程 PID `22282` 与该容器路径一致；`debugserver`、`flutter run` 和两个 `iproxy` 端口转发进程同时存在。
- 启动日志中业务 API 返回 `200/201`；国际更新清单仍返回已知 `404`，不影响调试连接，但不记作更新能力通过。
- 连续观察 10 秒未断开。本轮按用户要求保持 Flutter 真机调试会话运行，未重复触发已在上一轮通过的热重载。

## 23:00 重新开启 iPhone 真机调试

- 开始时 `feature/u19-eb1@2c625e7` 与远端一致，工作树干净；iPhone 15 Pro Max 有线连接，设备上的 `cn.saydian.app.global` 为 `0.1.23 (1007)`，先前的 Flutter 调试会话已结束。
- 以相同国际生产域名参数执行 `flutter run -d <connected-iphone-udid> --debug --no-build --no-pub`；Xcode 构建成功，耗时 `13.6s`。
- 安装与启动阶段耗时 `124.0s`，VM Service 发现超过 60 秒，最终文件同步耗时 `114ms`，Dart VM Service 与 DevTools USB 隧道建立成功。
- 设备安装容器为 `C00B0671-48FB-4B34-9261-070194D6E313`，运行进程 PID `22568` 与该容器路径一致；同时核对到 `debugserver`、`flutter run` 和两个 `iproxy` 进程。
- 启动后的国际业务 API 有 `200/201` 响应；更新清单仍返回已知 `404`。本轮只验证调试启动与连接，未重复执行热重载或完整业务流程。
- 调试会话保持运行，手机连接和解锁状态由现场继续维持。
- 后续现场手表操作的日志先显示 `[U19Capability] BP history structure verified`，接着两次出现 `[U19Sync] daily: index=0 dayOffset=0` 与 `[U19Sync] StateError`；同一进程仍在运行。源码 `app_controller.dart` 的捕获分支会将这类错误显示为数据读取失败，本轮尚未取得堆栈或确认实际页面提示，不能计为每日数据同步通过。

## 23:12 再次开启 iPhone 真机调试

- 开始时上次 Flutter 会话已报告 `Lost connection to device`，设备上 `0.1.23 (1007)` 保留但对应进程未运行；iPhone 15 Pro Max 仍有线连接，分支基线 `b1b79b6`，工作树干净。
- 以相同国际生产域名参数执行 `flutter run -d <connected-iphone-udid> --debug --no-build --no-pub`。Xcode 构建成功，耗时 `12.9s`；安装与启动耗时 `113.0s`，VM Service 发现超过 60 秒，最终文件同步耗时 `121ms`。
- Dart VM Service 与 DevTools USB 隧道建立；设备回读安装容器 `F8256591-9B05-457F-BAD6-A6BD262B7361`，运行进程 PID `22584` 与该容器路径一致，同时存在 `debugserver`、`flutter run` 和两个 `iproxy` 进程。
- 国际业务 API 在启动时返回 `200/201`，更新清单仍为 `404`；日志再次出现 `[U19Sync] daily: index=0 dayOffset=0` 后的 `[U19Sync] StateError`。本轮未取得堆栈、页面提示或完整同步结果，继续列为待定位。
- 调试会话保持运行；本轮未改业务源码或重复执行热重载。
