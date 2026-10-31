# 2026-10-29 国际版 iPhone 15 Pro Max 真机调试

用户要求安装到已连接的 iPhone 15 Pro Max 并开启真机调试。本轮使用正常 `lib/main.dart`、包名 `cn.saydian.app.global`、版本 `1.0.1 (1020)` 和美国 `.com/global` 服务，不改产品代码、用户账号、服务器或商店审核。

## 基线与设备

- 起始 HEAD `4fc04cb9395825b6836beb5d8eb933800fe3677c`，工作树干净。已读取工作约定、国际交接、最近修改记录、历史真机调试与回归约定。
- `git fetch origin --prune` 成功；现有产品树与 `origin/codex/u19s-local-health-ios-20261017` 完全一致。另一个 `origin/codex/global-update-20261018` 有新提交，未自行合并或覆盖。新建本轮记录分支 `codex/ios-device-debug-20261029`。
- 官方设备信息确认目标 iPhone15pm / iPhone 15 Pro Max / iOS 26.6，USB wired、paired、booted、Developer Mode Enabled。指定 UDID 沿用既有设备记录，未操作另一台 XR。
- 发现一个运行中的 Flutter drive 属于独立 SayRing 工作区和 XR；未停止该进程，没有同一国际版工作区的并发构建。

## 数据保护与构建

- 手机原安装为 `1.0.1 (1019)`。先备份本 App 的 Documents、Application Support、Preferences，不读取 Keychain 或解密健康内容。确认已安装应用路径后，只终止匹配的旧国际版 PID 3231，再做静止状态备份。
- 私有数据和完整日志仅保存于本机受限目录，备份另存于用户私有备份目录。目录 0700、文件 0600；原始健康数据、会话地址及凭据不进入 Git。
- 使用既有 Xcode 27 兼容方法：私有 `XCODE_XCCONFIG_FILE` 仅设置本次 Debug 最低版本为 15.0，`SAIDIAN_DISABLE_REMOTE_PUSH=true`。正常 Debug 构建成功，未修改跟踪的 Podfile 或项目配置。
- 编译参数明确使用 `SAYDIAN_API_BASE_URL=https://app.saydian.com`、美国 `/global/api/saydian-app/v2/support/app-update` 和空 JPush key。
- 实际产物签名严格验证通过：国际包名、1.0.1/1020、开发签名 `get-task-allow=true`、团队 W7SXQ4A226、描述文件包含指定手机。Runner SHA256 为 `adc983186a3f0c5b2b84ef345b9d4c33195f76835c8dccaabd77ef3acf0c4322`。
- `devicectl device install app` 覆盖安装成功，没有卸载。安装后、启动前比较：Documents 和 Application Support 的 5 个文件、5,989,547 bytes 全部逐字节一致；其中 3 个数据库、5,513,216 bytes 全部一致。此比对只证明该次手动覆盖阶段，不冒充之后正常运行和 Flutter 内部再次安装的同一次比对。

## 实际调试结果

- 使用完整正常源码 `flutter run --debug --no-pub --target=lib/main.dart`、指定手机和 `--device-connection=attached --no-uninstall-first` 启动；没有使用 QA 入口或旧预编译调试内核。
- run 的增量 Xcode 构建 15.2 秒，安装启动 22.0 秒，同步文件 77 ms。官方安装列表确认 1020，当前 App PID 3251 与该国际版实际安装 URL 匹配。
- VM service `getVM` HTTP 200、type=VM、main isolate 存在，Flutter 进程保持运行。SIGUSR1 热重载真实回执：`Reloaded 8 of 2222 libraries in 721ms (compile: 113 ms, reload: 143 ms, reassemble: 93 ms).`
- 当前启动日志未见 Lost connection、Unhandled Exception 或 EXCEPTION CAUGHT BY。已在内部浏览器打开本次 DevTools；调试会话继续附加。
- 首次更新记录索引时锚点不匹配，整组补丁未应用；核对实际标题后重新应用，仅修改本轮文档。

## 验收边界

本轮验证安装、静止数据保留、签名、调试连接及热重载。没有重新验收登录、LuckRing/QRing/U19S 连接与同步、健康测量或美国业务接口；不能当作苹果 2.1 反馈已经修复。产品源码未变，不重复全量跨端发行回归；未构建/上传正式包或重新送审。Debug 运行需要保持手机 USB 与 Mac 调试进程连接，独立冷启动应使用 Profile/TestFlight/Release。
