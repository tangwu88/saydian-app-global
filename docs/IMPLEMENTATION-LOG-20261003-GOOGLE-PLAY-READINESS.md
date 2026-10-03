# 2026-10-03 SAYDIAN Health Google Play 准备与单位申请

## 目标与基线

- 用户要求按独立国际版应用向 Google Play 送审；仅选择已验证支持的地区，排除法国。要求先申请香港公司 D-U-N-S，完善 Android Play 分发包、素材和审核资料。
- 修改前分支 `codex/global-device-admin-20261001`，HEAD `66de1e90ab1656e44e3b4cd3f8452ae5ebdcd69a`。`git fetch --prune origin` 与 `git pull --ff-only` 已成功，工作树原本干净；原始公司证书、品牌图和旧安装包保持只读。
- 本轮不更改国际 `/global` 健康同步 API、数据算法或 iOS 分发逻辑。Android `sideload` 继续保留既有经校验的 APK 更新；`play` 渠道不提供自安装。

## 已实施

- 将 Android 划分为 `sideload` 与 `play` 构建渠道；Play 基础 Manifest 移除 APK 安装权限和 FileProvider，Play 专用 Manifest 显式拒绝继承 `REQUEST_INSTALL_PACKAGES`。原生更新桥在 Play 渠道拒绝 APK 安装/未知来源设置调用。
- Play 渠道的 Flutter 更新服务只生成绑定 `cn.saydian.app.global` 的 Google Play 产品页；拒绝此前持久化的侧载更新目的地。新增相应单元测试。
- 新建独立 Play 上传密钥与忽略规则，实际本机生成 PKCS12 与 properties，文件权限 0600，均不入 Git；缺少真实 JPush 生产配置时正式发行门禁仍拒绝打包。CI 改为分别构建侧载和 Play QA 渠道，并对两种 APK 分别执行 ABI/推送依赖门禁。
- Android 原生启动背景由纯白变为白底 SAYDIAN 英文原版字标；源素材未改。生成并目视核对 1024×500 Play 宣传图和 512×512 图标。后续发现 `AliAgent` SDK 合并了 `SCHEDULE_EXACT_ALARM`，Play 渠道已明确移除；侧载渠道保持原行为。
- 编写英文商店文案、审核说明、数据安全证据清单；清单不是已经提交的合规申报。

## 单位网站流程

- 根据用户提供的香港公司注册证书，以 `Hong Kong Saydian Technology Limited` 向 D&B 香港官网申请 D-U-N-S。用户明确同意网站要求的市场/产品营销联系；没有勾选另一项新闻订阅。官网显示 `success?formid=10039` 和“已收到消息、稍后联系”确认；这是申请回执，不是九位 D-U-N-S 核发。
- Google Play Console 网站已选“公司或企业”，开发者显示名称录入证书上的英文法定名称。注册目前停在“关联支付资料”；网站只有“创建新的支付资料”选项。没有创建支付资料、缴费、接受最终条款、创建 Play 应用或提交审核。
- D-U-N-S 编号、Google 单位账号身份/付款验证以及 Play 应用记录仍待完成；不能将当前网站草稿写成送审。

## 本轮验证

- `flutter analyze --no-pub`：通过，零问题。
- `TZ=UTC flutter test --no-pub --reporter compact`：953/953 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：953/953 通过。
- `TMPDIR=/private/tmp python3 -m unittest scripts.release.test_release_gate`：23/23 通过。
- `flutter test --no-pub --reporter compact test/global_update_test.dart test/app_update_gate_test.dart`：12/12 通过。
- `git diff --check`：通过；最终暂存差异仍需提交前再查。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --flavor play --target-platform=android-arm,android-arm64 --no-pub --dart-define=SAIDIAN_PLAY_STORE=true --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=QWEATHER_API_KEY=`：首次 Gradle 下载耗时 2319 秒后成功；移除精确闹钟权限后增量重建成功，最终 QA APK `build/app/outputs/flutter-apk/app-play-release.apk`，SHA-256 `7ee475a2a0f3354c1c1ee172a92374fca7fbbd6423a40a8975bc25e058030191`。`apksigner` 显示 Android Debug 签名，不能上传 Play。
- 同参数 `flutter build appbundle --release --flavor play`：成功生成 QA AAB `build/app/outputs/bundle/playRelease/app-play-release.aab`，SHA-256 `8c0ec1f3c3c64b5573e10a620165c0fa8ac678455106828b31146f5c5f38dfc7`。`jarsigner` 确认调试自签名，不能上传 Play。
- 实际 APK `aapt dump badging`：`cn.saydian.app.global` / `1.0.0 (1012)`、target API 36、`arm64-v8a` 与 `armeabi-v7a`，不含 `REQUEST_INSTALL_PACKAGES` 或 `SCHEDULE_EXACT_ALARM`。AAB 的 `bundletool dump manifest` 同样不含两项及更新用 FileProvider。
- APK `zipalign -c -P 16 -v 4` 通过；AAB `bundletool dump config` 返回 `PAGE_ALIGNMENT_16K`。所有 arm64 `.so` 的 ELF LOAD 对齐均不低于 16 KB；32 位第三方 `libEcgAnaly.so` 仍为 4 KB，对 Google 64 位要求不构成直接证明或豁免，需供应商更新和 16 KB 设备运行检查才能声称全架构完整兼容。
- 现有 ARM64 API 31 模拟器全新安装并启动 QA APK，进程存活，英语登录和注册页可见。原生截图保存在忽略目录 `build/android/play-review-screenshots/01-sign-in.png`、`02-register.png`，尺寸 1080×2280，未含账号或健康数据；只有认证页，暂不作为完整商店截图组。
- Android 原生测试第一次在线运行等待 Flutter Debug 引擎依赖，手动中止；离线重试在 13 秒内明确缺少 `arm64_v8a_debug` 缓存。恢复在线后，官方仓库 Debug JAR 下载完成，`./gradlew :app:compilePlayDebugKotlin --info --console=plain` 构建成功。随后 `./gradlew :app:testPlayDebugUnitTest :app:testSideloadDebugUnitTest --offline --console=plain` 通过；两个渠道各 22 个原生测试，XML 报告均零失败、零错误。
- `flutter build ios --debug --no-codesign --no-pub`：通过，生成 `build/ios/iphoneos/Runner.app`；`flutter build ios --profile --no-codesign --no-pub`：通过，生成 61.9 MB 的设备 Profile App。两者均未签名、安装或在 iPhone 上执行；插件提示部分 Swift Package Manager 支持不足及 WechatOpenSDK 模拟器 arm64 限制，未阻断设备构建。
- `flutter build apk --debug --flavor sideload --target-platform=android-arm,android-arm64 --no-pub`：通过，生成 `build/app/outputs/flutter-apk/app-sideload-debug.apk`；未安装到 Android 实机。
- 首次侧载 QA Release 构建失败于 `prePlayReleaseBuild` 的 Play Dart define 检查。`./gradlew :app:assembleSideloadRelease --dry-run --offline --console=plain` 证实 AGP 将两个渠道的 `pre*ReleaseBuild` 都放进侧载任务图，只有 `packageSideloadRelease` 是实际打包任务。已把 Play/侧载专属检查移至对应的 package/bundle 任务依赖；保留所有 Release 通用生产门禁。
- 修正后第一次侧载 Release 重建因磁盘耗尽在 `mergeSideloadReleaseNativeLibs` 失败；Flutter 自动重试又遇到同一 Gradle 进程遗留的执行历史锁。盘点后，仅删除本轮可重建的 `build/app/intermediates/merged_native_libs/{sideloadDebug,playRelease}`、`build/app/intermediates/{intermediary_bundle,module_bundle}/playRelease` 和 `build/ios/{Debug-iphoneos,Profile-iphoneos}`，释放约 3.9 GiB；正式输出目录中的 QA APK/AAB、既有 iOS archive/IPA、截图与源码均保留。`./gradlew --stop` 停止唯一残留守护进程，未删除 Gradle 依赖缓存。
- 再次运行 `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --flavor sideload --target-platform=android-arm,android-arm64 --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=QWEATHER_API_KEY=`：通过，侧载 QA APK `build/app/outputs/flutter-apk/app-sideload-release.apk` SHA-256 为 `92a22d88e6b1f8d3f397a6f2c777b94c1079fad92a9925ad60a69fc7f9ddebf6`。该包仍是调试签名，非正式侧载发行版。
- 修正门禁后重跑 Play QA AAB 与 APK：均通过，SHA-256 与上文一致。两渠道 Release 依赖报告分别来自 `playReleaseRuntimeClasspath` 和 `sideloadReleaseRuntimeClasspath`；`release_gate.py apk-abis` 对两种 APK 均通过，并核对 JPush 受控 arm64 独有库例外。两种 APK 的 `zipalign -c -P 16 -v 4` 均通过，Play AAB 仍为 `PAGE_ALIGNMENT_16K`；Play APK `apksigner` 确认是 Android Debug 证书，不能上传 Google Play。
- 提交前 `git fetch --prune origin` 成功，当时 HEAD 与远端当前分支均为 `66de1e90ab1656e44e3b4cd3f8452ae5ebdcd69a`；`git diff --check` 通过。
- 最终暂存后再跑 `flutter analyze --no-pub`：零问题；`TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：953/953 通过。完整测试首次在受限沙箱因 Flutter SDK 缓存不可写退出，随后在获准的宿主执行环境中成功；不把该权限错误算作测试失败。
- 当前 `adb devices -l` 仅显示 Android 模拟器，无 Android 真机。不能声称蓝牙手表连接、真实测量上传、补传去重或 Google Play 预发布报告通过。

## 待验收与停线条件

- 取得第三方 32 位 ECG 库的 16 KB 对齐版本或明确兼容性说明，并在 16 KB 设备上验证；现有 arm64 与包对齐检查不代表全功能验收。
- 正式 AAB 需真实 JPush/厂商通道配置、已安全备份的 Play 上传密钥及通过生产门禁，不能用占位值绕过。
- 需在真实 Android 设备上取得无隐私泄露的截图，并验证账号、资料、权限拒绝、蓝牙配对、测量上报、去重和删除；模拟器不代替手表。
- 服务端独立任务已完成英文隐私、客服和删除页源码并推送其分支，但线上仍返回 404；上线且公开回读正常前，Play 隐私/删除 URL 不可填写为已可用。
- Google 审核账号凭据尚未获单独授权向 Google 提供；不可自动沿用 Apple 审核授权。
- 只有 Play Console 显示“审核中”才算提交，商店可见才算上架；目前两者均未发生。
