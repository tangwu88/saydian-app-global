# 2026-10-01 国际 App 设备后台联调

## 基线与目标

- 从已推送的 iPhone 上架候选 `codex/global-appstore-20261001@2b7e0de` 建立独立分支 `codex/global-device-admin-20261001`；修改前工作树干净，已检查远端、执行 `git fetch --prune origin` 和 `git pull --ff-only`。此分支的源码**没有**包含在已上传的 iOS 1009 包中，不把源码变更误写成已装机或已提交审核。
- 服务端任务获用户要求在设备后台显示会员 ID、昵称、设备型号/BLE 名、真实 MAC 和连接历史。原 1009 客户端连接成功后未向国际 V2 设备端点上报，后台无法看到新连接。复用历史提交 `8b4f1c3` 的就绪/自动重连上报实现；其旧记录说明当时不发送 MAC，本轮新增可选真实硬件 MAC 契约。
- Cherry-pick 源码时 `docs/CHANGE-TEST-LOG.md` 出现一处内容冲突，保留当前较新的记录并同时补入历史记录与本轮索引；没有覆盖同事的日志。

## 实施与影响

- `lib/services/api_client.dart` 新增国际设备上报接口；`lib/services/global_api_client.dart` 用已登录状态向 `/global/api/saydian-app/v2/devices` POST 最小快照。`lib/services/app_controller.dart` 仅在连接 ready 或自动重连 ready 时非阻塞调用，登录代次/当前设备校验避免旧回调跨账号上报；请求失败不把成功的蓝牙连接改成失败。
- `lib/domain/models.dart` 增加 `verifiedHardwareMacAddress`：只接受 SDK `hardwareAddress` 中的六组十六进制字节或 12 位紧凑地址，再规范化为大写冒号格式。iOS CoreBluetooth UUID、展示用 native ID 或非标准杂字符都不会当成 MAC 传输。API 再次校验格式；缺地址时不发送 `macAddress` 字段。
- 涉及账号/设备标识与后台可见性，正式版隐私政策及 App Store 数据收集披露必须覆盖该用途；本轮不猜测或代填法律声明。连接历史从服务端部署并有新客户端上报后才会有真实数据，不伪造旧历史。

## 验证与待办

- `dart format lib/domain/models.dart lib/services/api_client.dart lib/services/app_controller.dart lib/services/global_api_client.dart test/app_controller_account_wearable_test.dart test/device_sdk_source_test.dart test/global_api_test.dart` 执行成功；`git diff --check` 通过。`flutter test --no-pub test/global_api_test.dart test/app_controller_account_wearable_test.dart test/device_sdk_source_test.dart --reporter compact` 45/45 通过，覆盖国际路由/鉴权、ready 上报、失败不阻塞、真实 MAC 与 iOS 标识不混淆。随后把硬件地址格式从宽松字符剔除收紧为完整匹配，`flutter test --no-pub test/device_sdk_source_test.dart --reporter compact` 13/13 再次通过。
- 严格地址校验后的 `TMPDIR=/private/tmp flutter test --no-pub --reporter compact` 934/934 通过，退出码 0；测试末尾预期的“已审查文档版本变更拒绝授权”分支输出 FormatException，但不属于失败。最终 `flutter analyze --no-pub` 零问题；`python3 scripts/release/test_release_gate.py` 23/23 通过，`git diff --check` 与 `git diff --cached --check` 均通过。共享 Mac 空间一度仅约 2.2 GiB，另一项目 Android 依赖仍在下载；为避免损坏签名归档或影响服务端部署，本分支暂不发起新的 iOS/Android 构建。此条不会被标记为真机验收或发行包。
- 尚未为该分支构建/安装新的 iOS 版本；已上传 1009 仍是未含设备上报的上架候选。Android、真机后台设备行及自动重连、服务器设备端点部署都需要独立验收。手表当前约 10% 电量，本轮不会为了后台记录强制断连或重配对。

## 12:02 空间恢复后的 iPhone 1010 联调

- 修改前再次检查分支/远端/工作树并执行 `git fetch --prune origin`、`git pull --ff-only`，保持 `codex/global-device-admin-20261001@4ce2521` 且工作树干净；原交接仓库不动。本轮仅做构建、安装和记录，不改变运行时代码。磁盘清理后从约 8.4 GiB 可用空间开始；构建结束后约 5.5 GiB。
- 首次执行 `SAIDIAN_PRODUCTION_RELEASE=true SAIDIAN_ALLOW_QA_RELEASE=false SAYDIAN_API_BASE_URL=https://app.saydian.cn flutter build ipa --release --no-pub --build-number=1010 --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 失败：清理后的 `.flutter-plugins-dependencies` 当时仅识别两个 iOS 插件，自动 `pod install` 因而删减 `ios/Podfile.lock`，Xcode 报 `Error (Xcode): error ?? Color(MaterialDynamicColors.error.getArgb(scheme)),`。未安装失败产物。执行 `flutter pub get` 从锁定的手表插件提交恢复依赖，再执行 `cd ios && pod install`，14 个插件链接和全部 24 个 Pod 恢复，`Podfile.lock` 回到无差异状态；没有升级依赖版本或提交构建生成物。
- 同一 `flutter build ipa` 命令重试成功：iPhone-only App Store 归档 `build/ios/archive/Runner.xcarchive` 约 259.6 MB，IPA `build/ios/ipa/SAYDIAN Health.ipa` 约 39.9 MB，SHA-256 `5534141f73c037f8341c325af8742ae98652f18044bf78428b62812f4b722cf0`。归档回读为 `cn.saydian.app.global`、`1.0.0 (1010)`、`UIDeviceFamily=[1]`，`codesign --verify --deep --strict` 通过；归档另用 `ditto` 保存在 `/Users/saydian/Library/Developer/Xcode/Archives/2026-10-01/SAYDIAN-Health-1.0.0-1010.xcarchive`，副本版本回读为 1010。默认启动图、第三方 Swift Package Manager/模拟器架构提示仍存在。`--build-number=1010` 是本轮构建覆盖值；源码 `pubspec.yaml` 仍为 `1.0.0+1009`，1010 **未上传 Apple**，不能误称商店候选已替换。
- `xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportPath build/ios/adhoc-iphone15pm-1010 -exportOptionsPlist ios/ExportOptions-AdHoc-iPhone15pm.plist` 成功。Ad Hoc IPA SHA-256 `d9fc8779e0a349f5ef5e125f6bc27b8b6f5bd810f1fef9d44e1c81c3a4b67e4f`；解包回读同一标识/1010/iPhone-only、预期 `SAYDIAN Health Global iPhone15pm Ad Hoc` 描述文件，应用签名通过。`devicectl device install app` 对连接的 iPhone 15 Pro Max 原位升级成功，设备安装清单显示 `1.0.0 (1010)`，`devicectl device process launch` 成功。
- WDA 只读确认新 App Watch 页为 `Connected`，未再次手动同步或断连低电量手表（约 10%）。生产 `/global/health/ready` 返回 `ready`、`database=ok`、revision `660cf1b70ad26eb1553751c0475084e12ae037cf`。服务端任务按脱敏状态确认 12:02:24 的认证 `POST /global/api/saydian-app/v2/devices` 成功创建；我在已登录后台独立刷新看到实机设备行、一条连接历史，以及可展开的原始上报数据，字段存在，未在记录中复制会员 ID、MAC、Token 或健康数据。先前后台只见合成设备是刷新时序/会员范围导致，无需重启 App；这证明本次连接上报，不代表多次自动重连、其他机型或全部健康同步已验收。
- 恢复依赖后定向 Flutter 测试 `TMPDIR=/private/tmp flutter test --no-pub test/global_api_test.dart test/app_controller_account_wearable_test.dart test/device_sdk_source_test.dart --reporter compact` 45/45，通过；`flutter analyze --no-pub` 零问题；`python3 scripts/release/test_release_gate.py` 23/23，通过。随后重跑 `TMPDIR=/private/tmp flutter test --no-pub --reporter compact`，934/934 通过、退出码 0；末尾法律文档版本变更拒绝分支的 FormatException 是预期测试输出。Android Debug/Release 和 iOS Debug/Profile 本轮未执行，不能把本次 Ad Hoc 安装等同附加式 Debug。App Store Connect 此时仍显示已上传的 1009 为“无构建版本”，Apple 处理/审核未确认。正式隐私政策和数据收集披露、截图、支持与审核资料仍是上架阻断项。
