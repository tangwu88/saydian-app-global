# SAYDIAN Health 当前交接说明

更新日期：2026-10-05。此说明覆盖当前工作；旧记录仅作历史证据。
新版交接包独立生成，旧 ZIP、素材、签名与安装包不覆盖。

## 内容与版本

- App：`tangwu88/saydian-app-global`，分支 `codex/global-device-admin-20261001`。
- 服务端：`tangwu88/saydianserver` 当前已提交主线，只读携带；不替同事修改或部署。
- `manifest.json` 固定两份离线 Git Bundle 的分支、完整提交号和逐文件 SHA-256；另附 `SHA256SUMS.txt`。
- `README.md`、`IMPORT.py`、当前测试/代码导航；可选携带已上传的 1013 App Store IPA。

本轮只优化维护工具。`lib/`、Android/iOS 原生行为、API、算法和版本不变。
App 名称 `SAYDIAN Health`，包名 `cn.saydian.app.global`，iOS 团队 `W7SXQ4A226`。
第一方请求须保留 `https://app.saydian.cn/global` 隔离；不要合入国内仓库。

## 苹果、安卓与服务端状态

2026-10-05 实时核对：Apple 已接收 `1.0.1 (1013)`，上传状态“完成”，TestFlight“正在测试”。
外部 `say public` 组已出现该版安装记录；公开邀请为 https://testflight.apple.com/join/Tp2ThpNm 。
正式分发页面读取超时，不能宣称已正式上架；不撤回旧审核，也不重复上传 1013。

原 IPA 为 2026-10-04 的已有正式签名产物，37,092,454 bytes。
SHA-256：`14363daa2d17155ba08ba4437b6f624dfa482d4b8aba0575d3243a3c0b094d45`。
它不是本轮工具整理重新构建的包；只能经 TestFlight/App Store 安装，不能当 Ad Hoc 侧载。

下载页入口：https://app.saydian.cn/global/down ，兼容入口 `/down`。
原赛电 `/down/legacy`、Say Ring `/down2` 独立；四个 Health 协议/客服/注销入口保留。
下载页此前的“等待审核”是历史配置，后续可按真实审核结果独立更新；不要擅自混入其他产品。

安卓真机测试已按用户要求停止，本轮仅做工程编译回归，不安装、测试或分发新 APK/AAB；鸿蒙不构建。
公开 Android 1012 是内部 QA 包，不是 Google Play 正式版；不能覆盖旧 Windows 签名 3012。
禁止卸载旧版、清空数据、换签名强装；不要把手机容器复制进普通交接包。

## 在新电脑上导入

需要 Git 与 Python 3.10+；先通过可信渠道取得 ZIP 和独立 `.sha256`。
在 ZIP 所在目录执行 `shasum -a 256 -c <ZIP名称>.sha256`，成功后解压。
进入解压目录，先 `python3 IMPORT.py verify .`，再导入不存在的新目录：

```sh
python3 IMPORT.py import /绝对路径/SAYDIAN-Health-workspace
```

脚本逐项验证、离线克隆、核对 HEAD、Git fsck，并设置原远端；不会网络拉取或覆盖现有目录。
两份仓库当前提交在包内 `manifest.json`，以脚本输出为准。
若发生错误，保留部分导入目录供检查，不向该目录重试或删除已有项目。

接手时先 `git status --short --branch`、`git fetch --prune origin`，干净且可快进再 `git pull --ff-only`。
不要直接 checkout main 代替当前任务分支，也不要覆盖未推送修改。
源历史含国内导入历史和受许可证约束的厂商 SDK，应受控传输，不上传公共附件。

## 工具链与代码导航

原机参考：Flutter 3.44.9 / Dart 3.12.2，Xcode 26.6，CocoaPods 1.16.2。
Android 参考：JDK 17、SDK 36、NDK 28.2；新电脑独立恢复，不复制整机缓存。
页面模块见 `docs/CLIENT-CODE-MAP.md`；每轮先读 `AGENTS.md` 和 `docs/CHANGE-TEST-LOG.md`。

以后重新打包时先提交已验证的源码，再运行仓库中的工具；输出 ZIP 必须是新文件名：

```sh
python3 tool/handoff/portable_handoff.py build --app-repo /App仓库 --server-repo /服务端仓库 --output /新文件.zip
```

默认不包含二进制；`--ipa` 只接受上述校验值的已有 1013 IPA，不能以任意历史包冒充新版。

```sh
flutter pub get
flutter gen-l10n
flutter analyze --no-pub
TZ=UTC flutter test --no-pub
TZ=Asia/Shanghai flutter test --no-pub
python3 -m unittest discover -s scripts/release -p 'test_*.py'
python3 -m unittest discover -s tool/handoff -p 'test_*.py'
```

## 必须独立安全转移的材料

不复制未提交配置、Keychain、签名私钥、证书、Provisioning Profiles、Play 上传密钥或生产推送配置。
不包含密码、验证码、会话、真实健康库、原始健康日志、公司证件或带个人信息的截图。
由账号持有人通过独立加密渠道恢复需要的材料；原上传密钥不能随意重新生成。

Git Bundle 仅从明确的已提交分支构建；它保留已有历史，不表示旧历史已完成全面秘密扫描。
本仓库当前可见性为 Public；本轮不变更可见性、不发布普通交接包到 GitHub Release。
生产签名和推送门禁不弱化，不以占位值绕过。

## 验收边界和继续工作

最新实机记录见 `docs/IMPLEMENTATION-LOG-20261004-IOS-TESTFLIGHT.md`：已验证新手表历史通知自动上传和服务端 ACK/回读及稳定 ID 重试。
用户物理操作/手表表盘时间确认、全部指标/型号、超距自动重连、30 分钟经过和后台运行仍非全面验收。
旧 drive 默认清理曾卸载测试 App；后续必须 `--keep-app-running`，不能声称所有未确认本地记录均保留。

本轮主机测试、脚本夹具和 ZIP 干净导入各自单独记载；它们不代替新设备验收。
继续时优先核对正式商店状态、下载页真实试用入口，再按用户授权补剩余真机矩阵。
天气暂缓、法国不发布；Google Play 的 D-U-N-S、单位验证和正式 AAB 状态须重新核实。
