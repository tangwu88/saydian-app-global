# 2026-10-11 iPhone 15 Pro Max 真机 Debug 启动

## 范围与基线

用户本轮要求开启苹果真机调试。不启用 iPhone 镜像，不运行 QA 测试入口，不上传 Apple。
仅启动现有国际版正常产品入口 `lib/main.dart`；生产代码、版本、API 与 iOS 活动/睡眠范围不改。

仓库分支 `codex/global-device-admin-20261001`，起始 HEAD 为 `0978754f1ff05037d6ddd4b7ed6aee087036ac4b`。
工作树干净；`git fetch --prune origin` 与当前分支 `git pull --ff-only` 成功，Already up to date。
保留原 r7 归档、IPA、素材、设备账号和记录；Android 真机测试、鸿蒙构建仍停止。

## 手机与构建

- 指定手机 iPhone15pm / iPhone 15 Pro Max / iPhone16,2 / iOS 26.6。
  UDID `00008130-001C098C2290001C`；CoreDevice `A3DC94EA-18E8-52EB-B953-60133E11D071`。
  本轮实时 `transportType=wired`、tunnel connected、DDI available、Developer Mode enabled，IOUSB 有 iPhone。
- 现装 `cn.saydian.app.global / 1.0.1 (1014)`，没有该安装路径的运行进程。
  另外两个 Runner 进程属于其他安装路径，未终止或改动。
- Flutter 3.44.9 / Dart 3.12.2 / DevTools 2.57.0 / Xcode 26.6 (17F113)。
  `flutter analyze --no-pub` 零问题，2.7 秒；`git diff --check` 通过。
- `flutter build ios --debug --no-pub --target=lib/main.dart --build-name=1.0.1 --build-number=1014 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update` 成功。
  Xcode 构建 23.7 秒；正常 Debug 独立复制到 `build/ios-debug-20261011-normal-main/Runner.app`，没有覆盖旧诊断/发布产物。
- `codesign --verify --deep --strict` 通过；实际 Bundle/版本一致，Team W7SXQ4A226、UIDeviceFamily=[1]、get-task-allow=true。
  Profile 包含指定 UDID，有效至 2027-10-04；没有改变现有 RunnerDebug.entitlements。
  Debug 签名没有 aps-environment，本轮不作为 APNs 或发布签名验收，未临时移除生产能力。
- Runner 可执行文件 SHA-256：`9e5577f9bf5dd96fc0d9278fe571f7d4310c34c4b9c90b11b5175e472292a243`。
  两个插件尚不支持 Swift Package Manager；WechatOpenSDK 不支持 iOS 26+ arm64 模拟器。均为工具警告，不影响本次实体手机构建。

## 数据保护与覆盖安装

停止状态的 App 数据容器列出一个环境隔离加密健康库，无 WAL/SHM/journal。
通过 devicectl 复制到新建的 0700 私有目录，文件 0600；没有解密数据库或导出 Keychain。

手动 devicectl 覆盖安装 Debug 成功；启动前再次复制主库并比较，`cmp` 退出 0，331776 bytes。
安装后仍无 sidecar。证明本次手动覆盖安装没有改变加密库，不冒充后续运行中的全部记录/待传队列内容验收。
没有卸载、清库、回写旧备份、改动时间/值/ID、伪造 ACK，或影响其他 App。

## 附加调试结果

```sh
flutter --no-version-check run --debug --no-pub \
  -d 00008130-001C098C2290001C --device-connection=attached \
  --target=lib/main.dart \
  --use-application-binary=build/ios-debug-20261011-normal-main/Runner.app \
  --no-uninstall-first \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update
```

实际运行另加私有 VM URI/PID/日志文件参数，未把这些可访问调试会话的地址写入 Git。
Flutter 内部再次覆盖安装并启动，18.2 秒；同步文件 523 ms，未选择 uninstall-first。
前文逐字节保护核对针对手动安装，不能将它当成内部安装与启动之间另一次比较。

实际安装路径 `BEB9FE64-76D1-4947-8831-2DB7DF29A125/Runner.app/Runner` 对应本轮 PID 10959。
Dart VM Service HTTP getVM 返回 200 / VM / main isolate；DevTools 页面返回 200，页面壳存在。
已请求在 Codex 打开 DevTools，工具返回 queued，不假称已目视检查该面板。

向保持运行的 Flutter 会话发送 `r`，结果 `Reloaded 0 libraries in 313ms`。
没有源码改动，0 libraries 是预期；compile 23 ms / reassemble 79 ms。
之后 PID 10959 仍在相同安装路径运行；未出现 Flutter exception、RenderFlex overflow、Lost connection 或 Application finished。

日志 HTTP 状态字段为 200/201，没有明确 HTTP 401 或账号过期提示。
一次初步脚本用字符串 includes("401") 误命中哈希中的数字，已改为解析网络状态字段并纠正对用户的提示，不能保留为会话失效结论。
仅有启动请求的状态证据，不宣称登录写入、手表测量首 ACK、原内容回读、待传队列或去重已新验收。

## 交付与边界

保持 Flutter Debug 会话附加。需持续保持 USB、Mac 调试进程与手机连接；脱离调试器的 Debug 不能用于独立冷启动稳定性判断。
私有日志/设备 JSON/库/VM URI/PID 文件仅留本机 `/private/tmp/health-ios-debug-20261011.IHARKE`，不进 Git 或普通交接包。
构建前约 11 GiB、之后约 8.9 GiB 空间；无缓存/归档/素材清理。

本轮没有产品代码改动，全量双时区测试、Android/Profile/Release、XCTest、登录态逐页和新手表业务闭环未新执行。
10-07 的待验门槛保留：当天新步数增长、旧三行时间语义、登录态逐页及共用关爱摘要整改。
1014 上传/送审/批准与公开试用状态未核对或改变；不沿用历史 1013 状态当作本轮结果。
