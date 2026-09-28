# U19 扩展控制与国际版页面收口（2026-09-28）

## 范围与安全边界

- 工作区 `F:/xcodeplace/saydian-app-u19`，分支 `feature/u19-eb1`，基线 `abff0de440c4276e890ac27ac442c77b1076ae8b`。开工前检查工作树、fetch `origin` 并核实该功能分支与远端 `0/0`；没有回退既有 U19、品牌与商城隐藏改动。
- 对照用户提供的 EB1 协议，补 4.1 时间/语言、4.9 自动息屏、4.15 脉搏历史、4.16/4.17/4.18 动态血压设置、4.19 心率启动、4.20 血氧启动、4.21 脉搏启动和 4.24 新数据通知。`0x73` 的运动数据通知不解析为不存在的运动记录。
- **本轮不在真表启用定时充气，不再次启动血压测量，不修改或清除历史健康数据。** 动态血压设置必须先编辑、再单独确认；App 只允许 60/90/120/180 分钟间隔，写入后读回比对。脉搏测量 ACK 不是结果；用户在手表结束后，App 才允许重新发起，且“已结束”仅清除等待状态，不向手表发送不存在的停止命令。

## 修改与预期

| 范围 | 修改 | 预期 |
| --- | --- | --- |
| 协议 | 增加 `0x34` 脉搏记录和 `0x36/0x37` 设置解析；校验 16 字节帧、范围、无数据哨兵和多包完整性 | 无数据/异常值不成为健康结果 |
| 设备桥接 | 能力读取后按真实结构开放 U19 心率、血氧、脉搏和动态血压；`0x38/0x39/0x3A` 发起与 `0x73` 后回读新结果分离 | 不把启动应答或旧历史记录当新测量；会话切换忽略旧回包 |
| 功能页 | U19 显示脉搏分析与定时血压设置、当前状态和确认；亮屏时间读写回读；每次同步时间可选择要请求的手表语言 | 不把协议中“语言不响应”误称为切换成功，发送后提示核对手表 |
| 能力过滤 | U19 连接后隐藏未支持的心电、HRV、体温、运动和血压校准入口；既有历史仍保存 | 不用型号名称猜测能力，也不删除其他设备历史 |
| 国际版视觉 | 首页、健康页、设备页与我的页收紧密度，移除健康页硬编码中文及重复的重装饰标题 | 英文默认界面更简洁，仍保留必要安全提示 |

## 修改、测试与失败记录

1. 协议与定向 Widget/会话测试：`flutter test --no-pub test/urion_eb1_protocol_test.dart test/urion_wearable_bridge_session_test.dart test/u19_measurement_dialog_test.dart test/prototype_coverage_test.dart test/qa_user_flows_test.dart test/ui_shell_test.dart`，141 项通过。新增覆盖旧结果不冒充新结果、五包血氧隔离、设置读写回读、通知更新、定时充气和脉搏二次确认、同一脉搏测量不可重复发起。
2. 首轮新增确认测试失败：弹窗取消键随默认中文本地化，测试错误查找英文 `Cancel`；改为按弹窗内按钮类型定位后通过。随后一个正向测试在确认弹窗未关闭时再次点击页面按钮，导致遮挡；测试补取消步骤后通过。产品没有为使测试通过而跳过确认。时间/语言测试首次因安全存储插件在 Widget 测试环境缺失失败；仅为测试夹具添加内存式方法回包后通过，没有削弱设备逻辑。
3. `flutter analyze --no-pub` 通过；`dart format` 后 `git diff --check` 通过（仅仓库已有 CRLF 提示）。最后一次 `flutter test --no-pub` 全量 **913 项通过**；Android `:app:testDebugUnitTest --offline --no-daemon` 构建/测试通过；Harmony 原生现有 `node --test harmony-native/tests/*.test.mjs` **482 项通过**，**该套测试不等于 Harmony U19 接入验收**。
4. 最后 UI 调整后重跑 `flutter build apk --debug --target-platform=android-arm,android-arm64 --no-pub` 与 `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --target-platform=android-arm,android-arm64 --no-pub` 均通过。两包实际标识均为 `cn.saydian.app.global` / `0.1.23+1007`；Debug SHA-256 `E8011BF2B693CCE0A4F27FF2AB2A177F25CCE39152CADD5F12786C30F5503FB0`，QA Release SHA-256 `9862EB418B2AC97BBBBA0A1B141D49F4BB4B089373C21524319EF955BC543FF0`。QA 签名不是正式发布签名；两包均未发布。
5. 通过 `adb` 确认华为手机在线，已装包与新 Debug 包均为 `cn.saydian.app.global`、`0.1.23+1007`，签名 SHA-256 相同。两次 `adb install -r` 均返回 `INSTALL_FAILED_ABORTED: User rejected permissions`，没有卸载或清数据；已请用户在手机确认 USB 安装，**新代码尚未装入真机，新增功能不能标记实测通过**。在手机授权状态变化前不再反复弹出安装请求。

## 未验收与下一步

- 用户回复允许后，新增两次保留数据覆盖安装尝试仍为 `INSTALL_FAILED_ABORTED: User rejected permissions`。并发检查显示安装器启动时系统 `keyguardLocked=true`，随后 `mWakefulness=Asleep` / 显示屏关闭；截图仅为黑屏。此为**安装确认无法在锁屏状态完成的现场证据**，并不能排除解锁后还有其他安装权限限制。已请用户解锁并保持屏幕亮着后再试；本轮不清数据、不卸载，也不通过绕过系统确认的方式安装。
- 用户进一步授权今后直接安装后，再次确认设备在线、工作树干净和 Debug APK SHA-256 未变；`KEYCODE_WAKEUP` 使屏幕短暂亮起，但窗口仍为锁屏 `StatusBar`。直接覆盖安装仍返回 `INSTALL_FAILED_ABORTED: User rejected permissions`；普通上滑未解除锁屏，屏幕再次熄灭。未尝试输入或绕过锁屏凭据，也未卸载旧版。必须由用户在手机上完成解锁，保持屏幕亮着以便安装器正常完成确认。
- 手机确认安装后，覆盖安装、冷启动、U19 连接，逐项只读核对时间/语言当前状态、息屏时间、动态血压状态、脉搏历史、自动监测；再经用户另行允许测试心率/血氧/脉搏启动及新数据通知。重复三轮连接—只读同步—断开—重连；检查崩溃与旧域名请求。**定时血压启用和血压充气不作为自动回归项目。**
- 官方协议的 5 包血氧解释与 4 包单值冲突，当前仅接受已知 4 包结构；未验证结构隐藏相关测量，不上传推测结果。脉搏三个指数仅作设备原值展示，不生成诊断或上传到缺少契约的服务端。
- 服务端每日汇总能力端点在前次真机检查仍为 404；本轮未取得部署、云端保存与回读证据。Android 安装前的模拟测试不等于手表实测。iOS 共享 Dart 契约但本机无 Xcode/真机验收；原生 Harmony U19 通道尚未接入，不得称三端完成。
- 本功能分支不合入 `main`、不触发线上部署；下一位同事先 fetch 并核对分支、工作树、远端，再读本记录与 `U19-FUNCTION-FIX-20260928.md`。
