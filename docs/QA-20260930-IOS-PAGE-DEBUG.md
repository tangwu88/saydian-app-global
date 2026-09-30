# 2026-09-30 iPhone 15 Pro Max 逐页检查与 Debug 恢复

## 范围与基线

- 用户要求连接 iPhone 真机调试，并延续逐页测试。目标是有线连接的 iPhone 15 Pro Max `00008130-001C098C2290001C`，国际版 `cn.saydian.app.global` `0.1.23 (1007)`。
- 修改前 `feature/u19-eb1@441ecec5761c9302ead1296d9678607b60da89aa` 与 `origin/feature/u19-eb1` 一致，工作树干净。执行 `git fetch --prune origin` 和 `git pull --ff-only`，结果 `Already up to date`。
- 只调整两份测试文件：`integration_test/app_ui_smoke_test.dart` 更新国际版入口、已连接设备及全球客服断言；`test/support/ios_inner_page_capture.dart` 初始化日期语言数据。未改业务代码、设备数据或原始素材。

## 真机测试经过

真机测试与普通 Debug 均使用以下参数：

```bash
--dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
--dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update \
--dart-define=QWEATHER_API_KEY=
```

1. 执行 `flutter test -d 00008130-001C098C2290001C integration_test/app_ui_smoke_test.dart --no-pub` 加以上参数。测试包安装并实际执行；首页三项入口、三栏导航和 AI 卡片在首个失败前通过。第 25 行旧断言仍要求国际版显示已隐藏的“赛电商城”，故失败。根因是测试脚本过期，不是已证实的产品故障。
2. 修正测试脚本后以相同命令重试：Xcode 构建约 43 秒、安装启动约 115 秒，但 Dart VM Service WebSocket `Connection reset by peer`，测试在加载阶段失败，没有进入页面断言。此次不能算逐页真机通过。
3. 尝试 `flutter run ... --debug --no-build --no-pub` 及完整 `flutter run ... --debug --no-pub`，均因可重建构建缓存中的 `objective_c.framework`、`sqlite3.framework` 只剩签名目录，缺二进制与 `Info.plist` 而失败。设备连接及手机 App 进程仍可见。
4. 无其他 iOS 构建进程后运行 `flutter clean`、`flutter pub get`、`cd ios && pod install`，只重建本仓库缓存和 Pods；未卸载手机 App、清除账号或健康记录。`flutter gen-l10n` 独立提示项目未开启 `flutter: generate`，该命令未成功；已有本地化源码仍可编译，不把此提示记为通过。
5. 再执行完整 `flutter run -d 00008130-001C098C2290001C --debug --no-pub`，使用同样国际域名参数。Xcode 构建约 47.7 秒，手机安装/启动约 147.4 秒；Dart VM Service 与 DevTools USB 隧道建立并保持运行。`devicectl` 回读设备已连接、版本 `0.1.23 (1007)`，手机存在 `Runner` 和 `debugserver` 进程。主机从 VM Service `/getVM` 读到 iOS VM JSON 响应。启动日志有国际 API 请求，更新清单尚未验收；本会话由非交互式终端启动，标准输入关闭，因此尝试发送 `r` 热重载未执行，不能把 VM 可读写成热重载通过。

## 离线页面与回归

- 首次执行 `flutter test --no-pub test/support/ios_inner_page_capture.dart --dart-define=IOS_REFERENCE_OUTPUT=/tmp/saydian-page-qa-20260930 --dart-define=IOS_REFERENCE_CAPTURE=false`：心率及心电趋势页因测试夹具未初始化 `intl` 日期格式而失败。补 `initializeDateFormatting()` 后原命令通过，离线空数据夹具中的 **34 个内页**均完成渲染与异常检查。它们不是手机实机逐页点击，也不验证真实账号、蓝牙、服务端写入或购物支付。
- `dart format` 两份修改文件、`flutter analyze --no-pub`、`git diff --check` 均通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：929/929；`TZ=UTC flutter test --no-pub --reporter compact`：929/929。
- Android Debug/Release、iOS Profile、真实 U19 手表连接/测量、每个内页的手机实机点击均未在本轮执行；本轮仅修改测试代码，且保持手机 Debug 会话，不能将这些未测项写成通过。
- Mac 的“iPhone 镜像”仍显示 `iCloud 已退出登录`，系统设置的 iCloud 面板仍显示登录表单；因此未取得手机屏幕视觉逐页证据。用户称已登录，但本轮 UI 状态尚未证实镜像可用。Flutter USB 真机调试与该镜像阻断是两个独立状态。

## 后续待验

- 先保持当前 Flutter Debug 会话；若要继续全量真机逐页自动化，需要在稳定的 USB/VM Service 通道下重新运行修正后的 integration test，并逐页记录结果。不能把本轮离线 34 页或首轮局部通过扩大为真机全页面通过。
- U19 每日同步已有 `StateError` 历史现象，需单独取得堆栈及页面状态后按缺陷模板判断；本轮未修改手表或健康数据逻辑。
