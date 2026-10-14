# 2026-10-13 SayDian 国际版戒指、名称与隐私

## 基线与范围

- 用户要求对照国内版接入并显示 LuckRing/QRing，应用名改为 SayDian，采用既有 Apple 审核经验，加入美国服务器数据隐私声明。
- 导入 main 为 ada5df2787745b82bf869cb136a91a2108e3e2b7。fetch --prune origin 后发现较新的国际审核分支；从 origin/codex/global-device-admin-20261001 / 1704b99 建立 codex/saydian-rings-review-privacy，保留现有国际审核、活动睡眠和数据隔离实现。main 未覆盖。
- 国内版参考为同级 saydian-app-cn：导入快照 80fccf6 加本机 2026-10-13 戒指名称/1022 审核整改。该目录没有独立 Git 历史，不能称为刚同步的远端版本。参考只读。
- P1 缺口：国际版生产启动和 Android/iOS 中没有 CoolWear/LUCKRING、QRing 通道，因此不会显示相应真实扫描/连接状态。复制原有供应商 SDK 与自有适配，保留准确标识、能力握手及数据来源。
- 修改涉及 Dart 路由、设备模型/界面、Android SDK 隔离和注册、iOS SDK 链接和活动睡眠边界、显示名称、多语言隐私入口与说明。保持国际包名与 /global 环境；不复制账号、签名或国内版单语言设置。
- 美国云端存储位置来自用户本轮提供的部署事实，未独立审计数据库、对象存储、备份和第三方供应商地域。声明区分第一方云端存储、手机加密缓存与用户选择的第三方服务。客户端补充说明不伪造服务端已发布协议版本，也不绕过现有同意流程。
- Apple 依据：官方 https://developer.apple.com/app-store/review/guidelines/ 及国内版 IMPLEMENTATION-20261013-APP-REVIEW-1022.md。所有 iOS 用户统一活动/睡眠范围；免责声明不替代监管/准确性证据，新增戒指不能重新开放生理测量。

## 验证记录

- 修改前工作区干净；main fetch/ff-only 无更新。较新审核分支按需下载后检出成功。首次比较旧分支中不存在的新拆分页面路径报错，仅查询失败，无源码修改。
- flutter pub get --offline 通过，使用已有 Flutter 3.44.9/Dart 3.12.2 缓存；未修改依赖版本。
- 待执行：静态分析、双时区全量测试、Android 原生和 Debug/QA Release、串行 iOS Debug/Profile、SDK 原件哈希与用户可见页面验证。物理戒指握手/历史/长时恢复、服务器地域审计和商店发布分别验证，不由编译推断。


## 实施结果与修正

- 启动、扫描/去重、连接/恢复、能力握手和数据同步接入 LuckRing/CoolWear 与 QRing；SDK 原件只读复制。Android 隔离 QRing BBPro Java 包，22 个 JNI 库保持原字节；iOS 动态 BluetoothLibrary 嵌入，静态 QCBandSDK 只链接。
- 设备与首页使用真实戒指名称、通道和连接状态；无电量显示 `--`，无读回的设置不伪装成关闭/成功。设置读写使用设备代次防止旧设备异步回调污染当前设备，断开失败保留重试路由。
- P2 回归：全量测试显示通用文案覆盖既有手表提示，恢复手表显示，戒指按设备类型显示；名称改为 SayDian 的测试同步更新。
- P2 扫描缺陷：所有 SDK 都失败时原国内参考返回空列表，现保留 Bluetooth/权限异常原因；可用通道仍允许部分成功。新增异常与部分成功用例。
- 隐私：九个 locale 文件（八种语言含中文简繁）新增美国存储、手机缓存、共享/注销、可选第三方服务说明；不更改已发布协议与同意版本。原生补充 Required Reason API 声明；两处 Android 供应商异常日志改为仅输出异常类型，避免通知内容或设备身份随异常文本进入 Debug 日志。原有 Release 日志剥离继续生效。
- 名称更改覆盖 Flutter、iOS 多语言、Android 及现有 Harmony 显示文本，标识符和国际端点保持不变。Harmony 本轮只涉及名称，不宣称新增原生戒指功能。
- [提审与在线政策补充草稿](release/IOS-REVIEW-RINGS-PRIVACY-20261013.md) 包含真实剩余材料要求。旧已发布文件没有被重写或冒充新版本。

## 逐轮验证

本机日志/预览统一位于 `build/rings-review-20261013/`（构建产物忽略目录）。命令在本仓库执行，Gradle 命令在 android 目录执行。日期为 2026-10-13 Asia/Shanghai；运行环境 Flutter 3.44.9、Dart 3.12.2、JDK 17、Xcode 27。

| 轮次/命令 | 实际结果及处理 |
| --- | --- |
| `flutter pub get --offline`；`pod install --no-repo-update` | 通过，未调整依赖版本；CocoaPods 使用本机 Ruby 3.3.12，24 pods。保留供应商 SPM/弃用提示。 |
| `dart format` 新增/修改 Dart 文件；`flutter gen-l10n` | 通过，生成九个 locale 文件对应本地化。 |
| `flutter analyze --no-pub` 前两轮 | 首轮 7 个新增枚举/标签穷尽错误，第二轮品牌组件括号错误；补全 case、修复括号。第三轮和最终 `analyze-final.log` 均无问题。 |
| 七组戒指定向 Flutter 文件 | 初轮 72 通过/1 失败：LuckRing 状态提醒使用了通用标题，补充多语言专有标题。 |
| 新隐私/戒指、设置、路由、协议定向 | 第二轮测试框架未在断言前恢复 debug 平台和文字查找同时匹配标题/正文，12 个失败；移除无关平台 override、查找精确正文。后续全量全部通过。不是生产页面溢出。 |
| `TZ=UTC flutter test --no-pub --reporter expanded` | 首轮 1073 通过/14 失败，均为手表提示兼容性/名称断言；修正按类型显示和更新名称断言后，第二轮 **1087/1087** 通过 (`tests-utc-second.log`)。 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded` | **1087/1087** 通过 (`tests-shanghai.log`)。涵盖国际鉴权、协议版本、数据隔离、待确认上传、账号切换及两戒指通道。网络日志来自 mock clients，不代表在线账号验收。 |
| 七个 `test/native/*.m` 以 `xcrun clang -fobjc-arc -framework Foundation` 编译执行 | 全通过：活动睡眠与设置范围、CoolWear 握手/历史/提醒、QRing 相机/取消/手势/记录映射。 |
| `xcrun swiftc ios/Runner/WearablePayloadMapper.swift test/native/ios_wellness_policy_main.swift` 后执行 | 通过；首次误指不存在的单独 IOSWellnessPolicy.swift，实际定义在 WearablePayloadMapper.swift，修正命令后通过。 |
| `flutter build ios --debug --no-codesign --no-pub` | 首轮 160.6 秒通过，最终 8.7 秒通过 (`ios-debug-final.log`)；明确为未签名 iPhoneOS 构建。 |
| `flutter build ios --profile --no-codesign --no-pub` | 在 Debug 完成后串行执行，38.9 秒通过，64.1 MB (`ios-profile.log`)。使用忽略目录 xcconfig 设置本机 iOS 最低版本 15，未改源项目签名。 |
| Android `:app:testSideloadDebugUnitTest :app:assembleSideloadDebug -Ptarget-platform=android-arm64 --offline` | 初次缺少对应仓库的 Flutter 引擎缓存。联网重试下载过慢，仅终止本轮 Gradle client（未终止共享 daemon/国内版进程），使用本机已有 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 缓存。 |
| Android 镜像离线重试 | QRing 单项 transform 缓存触发 immutable workspace 校验；将该缓存完整移动至 `quarantined-qring-transform` 保留后重建。16 秒通过；日志隐私修正后最终再次 5 秒通过。原生 **8 suites / 38 tests / 0 failures**。 |
| `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --flavor sideload --target-platform=android-arm,android-arm64 --no-pub` | 首轮 71.9 秒通过，70.6 MB。QA 使用 Debug 证书，不能分发为生产包。最终日志见 android-qa-release-final.log。 |
| `node --test tool/test_native_log_privacy.mjs` | **10/10** 通过，包括两戒指异常日志防泄漏。使用 Codex bundled Node；系统 PATH 中没有 node 的首次命令失败，改绝对路径通过。 |
| `node --test harmony-native/tests/layout-contract.test.mjs` | **25/25** 通过。仅名称与原布局契约，未做 Harmony 构建。 |
| `node tool/qa_ios_frameworks.mjs` | 将两个新增 SDK 纳入后 **9/9** 含 arm64；只代表架构检查。 |
| `release_gate.py apk-abis` | 首轮缺少 JPush 例外所需 dependency report 而失败；生成 sideloadReleaseRuntimeClasspath 报告后通过，限定既有 JPush/JCore 版本的 libjutils.so 单架构例外。 |
| 本地 Widget 渲染与检查 | 四张 en/zh 的隐私和戒指卡片预览通过。前两轮 host 测试字体缺失，换用本机 Hiragino Sans GB + Material Icons 并指定测试主题字体后可读；不修改产品字体。字体工具探测缺少 fontTools，未安装依赖。预览为 synthetic fixture，不是真机证据。九 locale 的 320px/1.8 倍字号滚动检查在全量测试通过。 |
| SDK/包内容检查 | 四个供应商二进制逐字节匹配国内参考；QRing 隔离包无原 BBPro core 路径且 JNI 原样。iOS Profile 含两桥接与 QCSDKManager 符号，BluetoothLibrary 嵌入、QCBandSDK 不嵌入；显示名、Bundle ID、隐私 manifest 均正确。 |
| 真机 | ADB 设备数 0。保留正在运行的国内版 iPhone 调试，不覆盖安装或操作其数据。本次国际构建的戒指真机握手/历史/重连/长时恢复未执行。 |

Android 构建环境：`JAVA_HOME=/Users/saydian/develop/jdk17`、`ANDROID_HOME=/Users/saydian/Library/Android/sdk`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。
iOS 构建环境：Ruby/Flutter 在 PATH，`SSL_CERT_FILE=/etc/ssl/cert.pem`，`XCODE_XCCONFIG_FILE=$PWD/build/rings-review-20261013/xcode27.xcconfig`。同仓库 iOS 构建均串行，未清理共享 DerivedData。

## SDK 原件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| coolwear_bluesdk-release.aar | ad482d5d69b99941d906038794165c1d479e5e038713954d9ca22059083d0f5f |
| qring_sdk_1.0.0.76.aar | 0021886ae500740945cf76e61d750812b96ff54d51fd0c32ebe77083862326d4 |
| BluetoothLibrary.framework/BluetoothLibrary | f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624 |
| QCBandSDK.framework/QCBandSDK | dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393 |

## 剩余发布验收

- 本次国际安装包的实际 LuckRing/QRing 连接、历史数据、断连/取消、设置读回、长期恢复以及审核视频。
- 国际账号线上登录/注销/上传确认，以及数据库、对象存储、备份和处理商的美国地域核实。
- 在线隐私政策正式版本、商店名称/截图/App Privacy 标签和新构建号。当前只生成本地代码与 QA 包，未上传 App Store、未部署后端、未发布政策。

## 最终本地产物

Android 日志隐私修正后 QA Release 再构建 30.4 秒通过，最终 ABI 门禁再次通过。aapt 读取 APK 确认显示名 SayDian、包名 cn.saydian.app.global、版本 1.0.1 (1014)。下面 iOS SHA 仅指 Profile 主可执行文件，不是签名 IPA。

| 产物 | 字节 | SHA-256 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-sideload-debug.apk` | 125386369 | `47dce151bd286091c08a5a09a058b06e35da040652d1cdaa0fb62f78b80fb1d9` |
| `build/app/outputs/flutter-apk/app-sideload-release.apk` | 70605057 | `0699d835840ce182b1753455c73647fb7e90d8bcd1e4261ba47daf5b862d2b78` |
| `build/ios/iphoneos/Runner.app/Runner` | 14284632 | `1e7cfdf42e7e06829ea9dfee15ff7e337f19e1e5a535ff217448b5acd7c0f648` |

最终暂存检查：首次 `git diff --cached --check` 仅报告供应商 BluetoothLibrary 原始头文件尾部空白；为保持原件字节一致不格式化供应商文件。排除 `ios/Runner/Vendor/**` 后自有源码/文档检查通过。提交包含 266 个文件（含 SDK 原始头文件和二进制），未包含构建日志、安装包、签名或账号凭据。
