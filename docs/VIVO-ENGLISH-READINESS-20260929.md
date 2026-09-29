# vivo X300 英文体验与通知入口整改

## 范围与基线

- 2026-09-29，国际 U19 分支最新基线 `2e1e590f0b76439badaa2f7b72301e5faa2149d2`。
- 新建独立工作副本与 `fix/vivo-u19-english-readiness` 分支；原交接资料只读。
- 修改前完成 status、remote、fetch、干净分支 fast-forward 核对。
- 阅读 AGENTS、国际交接、U19 最新记录、回归清单与跨端复盘。

## 已复现问题与计划

1. P2：英文 Profile → Permissions 的标题、权限名称、授权状态仍为中文。
   预期为英文，并区分检查中、拒绝、受限与部分授权；权限请求失败不能静默。
2. P2：Health → Messages 空态直接显示中文控制器状态，空表不能下拉刷新。
   预期显示本地化加载/空态/失败，失败可重试；保留真实通知与读取状态。
3. P2：347 逻辑像素屏幕上健康监测、关爱人数和问候语被截断。
   预期调整排版容纳英文和较大字体，不删除入口或改变能力限制。

涉及 `lib/ui/pages.dart` 与 UI 回归测试；不改健康算法、记录、U19 指令、
服务端、天气供应商或推送凭据，不伪造消息/天气能力。

## 环境与已有检查

- 手机已安装 QA APK 的 SHA-256 与交接包一致，版本 0.1.23+1007。
- 蓝牙权限已授权；App 通知/定位未授权，通知读取服务未启用。
- 真机只读检查见上级 qa/VIVO-U19-FUNCTION-CHECK-20260929.md。
- 本机原 PATH 缺少 System32 导致 Flutter 首次启动报 WHERE/git 不可用；
  为当前构建进程补齐路径后 Flutter 3.44.9 / Dart 3.12.2 启动成功。
- 本机 debug.keystore 证书与已安装包不同；不卸载、不清除用户数据。
  新包覆盖安装需原测试签名，已向用户询问本地文件路径。
- Windows 无 Xcode/iPhone，本轮不能声称 iOS 本地构建或真机已验收。

## 验证记录

后续追加定向复现、全量测试、格式、静态检查、构建和实际安装结果。

### 实施与失败修正

- 用户确认没有原测试签名，要求先完成代码与安装包；不卸载手机旧版。
- 页面层本地化权限名称/授权状态、消息加载/空态/错误与本地关爱消息；
  健康提醒复用已有英文文案函数。服务器正文保持原样，不伪造翻译或改写业务数据。
- 通知未授权时使用系统请求，永久拒绝/受限时引导设置；失败可见且能重试。
- 空消息列表也可下拉刷新；错误不再误当作空表成功。
- 手表功能卡改为内容自适应高度，大字体单列；欢迎语与关爱人数标签允许两行。
- 新增 `test/english_readiness_test.dart`。初次测试因错误使用 DeviceInfo.sdkSource
  构造参数未编译；改用已存在的 urion ID 推导，不修改设备模型。
- 基线定向 7 项全失败，验证原英文/刷新/截断问题；第一次修改后 4 通过、
  3 项布局溢出（16/34/124 像素）。去掉固定高度后 7/7 通过。
- 再补永久拒绝与请求异常两项真实交互测试，共 9 项。
- `dart format lib/ui/pages.dart test/english_readiness_test.dart` 已执行；
  最终 `dart format --output=none --set-exit-if-changed ...` 两文件 0 改动。
- `flutter analyze --no-pub` 两次因 Windows 中文路径/LSP JSON 截断异常退出 255，
  不是源码诊断。以 S: 临时映射同一工作树并运行 `dart analyze` 得到正常诊断；
  补齐新代码 if 花括号后以 `dart analyze --fatal-infos` 再验。
- 首轮 `TZ=UTC flutter test --no-pub --reporter expanded` 936/936 通过。
- 最终 `TZ=America/New_York flutter test --no-pub --reporter expanded` 938/938 通过。
  Windows TZ 环境变量由进程设置；此结果不替代美区手机真实跨天/夏令时验收。
- 构建工具首次安装：Flutter 3.44.9、Dart 3.12.2、Temurin JDK 17、Android SDK 36。
  新版 sdkmanager 包参数分割失败，改用官方 Android CLI `sdk install`
  安装 `platforms;android-36` 与 `build-tools;36.0.0` 成功；无源码依赖升级。
- QA 版本通过构建参数设为 0.1.24+1008；仓库 pubspec 版本未更改。
- 最终 `TZ=UTC flutter test --no-pub --reporter expanded` 938/938 通过。
- `dart analyze --fatal-infos` 在 S: 映射下通过，No issues found；`git diff --check` 通过。
- `node --test tool/test_urion_native_lifecycle.mjs tool/test_native_log_privacy.mjs`
  12/12 通过，仅为源码契约检查，不代表蓝牙真实交互验收。
- 首次 Debug 自动安装 NDK 28.2.13676358：输出长时间未刷新时检查下载进度，
  启动备用官方 curl 下载；确认原下载已开始解压后立即中止备用下载（退出 1），
  Gradle 自身安装最终成功。未更改 NDK 版本或绕过证书验证。
- 全目录 `dart format --output=none --set-exit-if-changed lib test`：157 文件，0 变更。
- 首次 `flutter build apk --debug --build-name 0.1.24 --build-number 1008` 失败：
  `:jni:buildCMakeDebug[arm64-v8a]` 未在中文构建路径找到 libdartjni.so，耗时 17m18s。
  Android 34/35、NDK 与 CMake 3.22.1 安装均已成功。为避开路径问题，创建独立
  ASCII 构建副本 `G:/codex/saydian-global-build-20260929`，从同一 Git 基线复制
  本轮 pages.dart 与测试；pages.dart SHA-256 两处均为
  `4134995D8CB572454F964FC6B0939DA504393C7D3AA3A2AA3CAAA1D4A24ED6A6`。
  未修改仓库构建配置、依赖版本或原始交接资料。
- 原 .ninja_log 记录的产物路径确有乱码；独立 ASCII 副本 Debug 同命令
  成功（133.6s），生成 156,564,762 字节 app-debug.apk。
- ASCII 副本 `flutter analyze --no-pub` 通过，No issues found（50.0s）。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub
  --build-name 0.1.24 --build-number 1008`：成功，283.0s，约 65.2 MB。
  既有 camera/jpush Kotlin 插件兼容性、弃用 API 提示保留，未升级插件。
- `apksigner verify --verbose --print-certs`：Debug 与 QA Release 均校验通过。
  QA Release 包名 `cn.saydian.app.global`，版本 `0.1.24`，build `1008`，
  `aapt2 dump badging` 确认 ARM64 与 ARMv7、targetSdk 36。
- QA APK SHA-256：`C9D3612150943352F8CF3D31ECF79F81C3824149440FD8CDDD71759DBB191405`。
  Debug SHA-256：`01BBA32F65A6D7E54BE5EE9AEB0CDF4ECC93AEE8CF3FBD5C0381BE9D41269279`。
- 新签名证书 SHA-256：`8243CFDB6830BB8A3D2BDB503E950089810A5BF1843FA92ABF7705F19EFCD94E`。
  与手机旧包不同；未尝试安装，原数据与旧 App 保留。
- QA Release 未配置生产推送凭据，属于内部测试包，不是可发布商店的生产包。
- `gradlew :app:testDebugUnitTest --offline --max-workers=2`：45s BUILD SUCCESSFUL；
  XML 报告 5 组、22 项、0 failures、0 errors。
- `gradlew :app:dependencies --configuration releaseRuntimeClasspath --offline
  --max-workers=2`：成功；用于核验实际 APK 内原生库架构。
- 已复制 QA APK 到上级 `qa/SAYDIAN-Health-US-vivo-0.1.24-internal-QA.apk`，
  68,359,544 字节；复制后 SHA-256 与构建产物一致。
- 初版 APK 架构门禁失败（退出 2）：`apk-abis --apk ... --dependency-report
  release-dependencies.log --pubspec-lock pubspec.lock` 发现 JPush 6.2.0 的宽范围
  JCore 依赖自动解析到 5.5.7；现有 libjutils.so ARM64 例外只验收过 5.5.2。
  此初版包不作为最终交付。计划仅在 android/build.gradle.kts 固定
  `cn.jiguang.sdk:jcore:5.5.2`，保持既有门禁版本，不放宽规则、不升级 SDK。
  影响范围为 Android 打包可复现性；需要重做 Debug/QA Release、原生测试及包体检查。

### 验收边界

- 仅修复已实现功能的手机适配；U19 天气及手机通知转发缺少已验证协议，未擅自启用。
- App 内消息可读/可刷新不代表后台推送已配置或已收到真实推送。
- 原 APK 真机读回自动心率/血氧开关，不等于所有测量、历史上传和云端读回都通过。
- 国际日汇总服务能力路由先前记录 404；本轮没有部署服务，也未改接口/上传成功判定。
- 新签名 APK 不可保留数据覆盖旧包；本轮不执行安装、不清数据、不改手表设置。
- iOS Debug/Profile 与新包真机复核未执行，完整跨端发布门禁仍未满足。
