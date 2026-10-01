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
