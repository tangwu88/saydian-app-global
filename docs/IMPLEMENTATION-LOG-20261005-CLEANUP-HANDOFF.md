# 2026-10-05 发布工具整理与跨电脑交接

## 基线与范围

基线 `8dac803`，国际分支 `codex/global-device-admin-20261001`。
工作树干净；fetch / pull --ff-only 成功且无远端新增。
已阅读 AGENTS、国际交接、最新 iOS 记录、复盘和回归清单。

本轮只整理发布校验与离线交接工具，不修改运行时、页面、API、算法、签名或版本。
安卓真机测试和鸿蒙构建保持停止；原始素材、历史交接包、1013 IPA 保留。
不把工具源码提交当成新 App 构建或新设备验收。

## 变更计划

- release_gate.py：分块读取安装包计算 SHA-256，避免完整大文件内存分配；原拒收行为不变。
- 发布门禁测试：验证多块文件与损坏文件，不允许 read_bytes 整包读取。
- tool/handoff：统一打包、逐项校验与离线克隆；拒绝覆写、脏源码、路径逃逸和未校验输入。
- 当前交接说明：准确区分源码、已上传 IPA、商店状态、未完成验收和安全转移材料。
- analysis_options.yaml：排除 ignored build 产物；不排除任何已提交的生产源码或测试。

## 验证记录

执行结果和交接包干净目录导入回执在完成后追加；此初始记录不代表验证通过。

- 初轮交接夹具 9/9、完整发布 Python 25/25 通过；锁冲突、CAS、坏哈希等失败文案为预期负向夹具，不是生产发布失败。本轮没有执行真实发布脚本。
- Dart 格式检查 lib/test/integration_test 186 文件、0 改动。首次 flutter analyze --no-pub 退出 1：旧 ignored build/ios-testflight-1013/health_sync_test.dart 的 use_null_aware_elements 提示。旧诊断源码保持不动，新增 build/** 排除，仅分析真实工程源码。
- 修改后 flutter analyze --no-pub：零问题。交接脚本加签名文件门禁与 malformed root 拒收后，夹具 11/11、完整发布 Python 25/25 通过。
- TZ=UTC 与 TZ=Asia/Shanghai flutter test --no-pub --reporter expanded：各 1011/1011，退出 0。日志保存在本机 /private/tmp/saydian-health-cleanup-20261005-*.log，不复制原始输出至交接包。
- 按仓库跨端要求串行启动 Android sideload 双 ARM Debug/显式 QA Release、iOS 无签名 Debug/Profile 编译回归；不安装或驱动手机，不执行任何鸿蒙命令。结果待本条后追加；原正式 IPA 和归档不改写。
- Android `flutter build apk --debug --flavor sideload --target-platform=android-arm,android-arm64 --no-pub`：成功，Gradle 37.7 秒。`SAIDIAN_ALLOW_QA_RELEASE=true` 同命令 release：成功，113.6 秒、约 68.3 MB。仅本机回归产物，不进本次包、不上传或安装；Kotlin 插件迁移及 Android SDK XML 版本警告保留，不宣称零警告。
- 最后一次交接夹具重跑 11/11，通过包含 SHA256SUMS.txt 的包内文件集合校验。没有实际生产写入、账号登录、重新签名或修改设备数据。
- 补充双仓库完整性断言后，最终交接夹具 12/12，退出 0；旧轮次 9/11 项记录保留，不冒称当时已执行新增用例。
- iOS `flutter build ios --debug --no-codesign --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：成功，54.8 秒。Profile 同命令成功，88.7 秒，约 62 MB；均为编译，不是签名或安装。厂商 SPM 与微信 arm64 模拟器警告保留。
- 编译后 Git diff 确认 lib、ios、android、pubspec.yaml/lock 无本轮差异；原正式 IPA SHA-256 仍为 14363daa2d17155ba08ba4437b6f624dfa482d4b8aba0575d3243a3c0b094d45。未安装/驱动设备，不构建新正式 IPA，不重跑 Android 原生手机测试或鸿蒙任务；本轮发布 Python 门禁为完整 25/25。
- 服务端仅只读保留当前 main a9a884a；公开 /global/health/ready 读回同 revision，ready/database=ok。没有服务端源码修改、部署、后台表单保存或健康数据写入。
- 提交使用 skip-ci：本轮维护工具/分析范围/说明，运行时和工作流未变，本机全部上述门禁已实际执行；避免触发用户停止的其他平台任务，不据此宣布远端 CI 通过。普通交接 ZIP 不上传 Public GitHub 附件。
