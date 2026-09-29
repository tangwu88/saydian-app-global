# U19 安卓真机调试与英文提示复核（2026-09-29）

## 现场与范围

- 国际 App 工作区 `F:/xcodeplace/saydian-app-u19`、分支 `feature/u19-eb1`；修改前 `HEAD=04d86ee553f1be9ad7a945b15ab75ad94d21eebb`，工作树干净，`git fetch --prune origin` 后本地与远端 `0/0`。`origin` 为 `tangwu88/saydian-app-global`，未触碰国内仓库或生产发布。
- 华为安卓测试机经 `adb devices -l` 显示在线，USB 调试可用。任务只做国际版 Debug 包、U19 的连接/只读同步/查找及可见英文提示；不清库、不重置手表、不启动测量或定时充气。原始蓝牙日志、截图及安装包留在被忽略的 `build/`，不进 Git。
- 手机原先未安装 `cn.saydian.app.global`。首轮 `adb install -r -t build/app/outputs/flutter-apk/app-debug.apk` 返回 `INSTALL_FAILED_ABORTED: User rejected permissions`；已停止重试并询问。用户确认手机允许安装后，第二次同一命令返回 `Success`。包管理器核实为 Debug、`0.1.23+1007`；未卸载其他 App。用户自行在手机输入账号并登录，未在工具输出或记录中保存联系方式/密码。
- `flutter attach -d 2KTYD21714200059` 成功取得 Dart VM Service；随后只做热更新及观察，不把热更新当最终 APK 验收。

## 真机用例与问题

| 用例 | 预期与现场结果 | 判定 |
|---|---|---|
| 扫描与首连 | 扫描实际发现 U19。第一次 GATT 物理链路 `status=0`，服务发现已启动并重试，但无完成回调，约 25 秒初始化超时。App 未冒充已连接。 | **P1 间歇性故障待排查**；不能仅加长等待掩盖。 |
| 再次连接 | 再扫后服务发现、通知订阅与设备信息完成，Watch 页显示已连接及电量。之后一次受控断开—复扫—重连也约 0.4 秒完成服务发现，自动读取当天日汇总。 | 后续两次成功；不足以关闭首连故障或宣称三轮全链路通过。 |
| 每日数据日期 | 初次读到 `index=0/dayOffset=1001`，App 拒绝保存。用户确认手表实际显示 `2024/01/02 01:27`，与手机 2026 年日期不一致。 | 日期保护正确；不能通过放宽校验让旧日期进入健康记录。 |
| 时间同步 | 经用户明确允许，App“Time & language”选择“中文”并发送当前手机时间。App 仅提示请求已发送，不虚称协议读回成功。用户现场确认手表日期时间正确、仍为中文。再次只读同步得到 `index=0/dayOffset=0`。 | 时间/语言实体验证及日期校验通过；历史数据、云端保存仍需另验。 |
| 查找手表 | 只触发一次 Find my watch，Debug 日志显示手表应答，用户确认实体有振动或提示音。 | 通过本次设备与 App 的查找闭环。 |
| 设置只读 | 健康监测、基础设置、屏幕显示可读取；定时血压为关闭，息屏时间可见。脉诊历史为空时不生成结果；未启动脉诊或改动设置。 | 已覆盖可见只读状态，不等于写入回读验收。 |
| 恢复出厂后的日期 | 用户在上述校时之后恢复了手表出厂设置；手表回到 2024 年，界面由中文变为英文。最终包冷启动后再次读到 `dayOffset=1002` 并拒绝保存。 | 出厂复位解释了这次时间回退；**没有证据证明普通断连会让时钟回退**，不得据此改写固件持久性结论。 |
| 复位后手动校时 | 经用户确认要保持英文，在 App 中选择 English 发送当前手机时间。用户确认手表时间正确且仍为英文，随后旧 Debug 包只读同步显示 `index=0/dayOffset=0`。 | 手动校时与日期校验再次通过；无协议时钟读回，不等于云端上传。 |
| 英文提示 | 英文 Watch 页同步失败时弹出中文“设备已连接，但数据读取失败”；设备搜索的错误及连接过程也含中文。最终 Debug 包安装前，在真机上故意读取复位后的旧日期，Snackbar 实显 `Could not sync. Keep your watch nearby and try again.`。 | **P2 修复真机复验通过**；不更改控制器原始诊断或中文界面。 |
| 最终包复装与复连 | 新 Debug 包覆盖安装 `Success`，未清除 App 登录数据；冷启动仍是英文首页。自动恢复先发现 U19 厂商广播，GATT `status=0`，但服务发现无回调并在约 25 秒超时。重新复扫精确选择同一只 U19 两次，均复现同样超时。 | **P1 未关闭**。本轮最终包未达到通知订阅/协议命令阶段，所以不能宣称新增自动校时已通过实表验证。用户确认手表靠近、点亮且未连其他手机后停止重试。 |
| 网络与崩溃 | 当前进程的一段脱敏网络日志中只见 `app.saydian.cn`，无旧域名引用或本应用 `FATAL EXCEPTION`/ANR；出现一次 404，与尚未部署的日汇总能力接口一致。 | 抽样检查，不是全量出站域名审计；云端日汇总未验收。 |

## 本轮源码修正与验证

- 原因：英文版直接展示控制器的中文错误，以及扫描时硬编码中文连接状态。仅修改 `lib/ui/pages.dart` 的 AppShell Snackbar、设备搜索空态/错误提示与连接进度文案；非中文语言使用已有本地化资源，中文行为保留。新增 `test/ui_shell_test.dart` 英文同步失败回归。影响范围限可见提示，不改 BLE/EB1、日期校验、健康记录和 API。
- `dart format lib/ui/pages.dart test/ui_shell_test.dart`：通过，仅本轮页面文件发生格式调整；`git diff --check`：通过。
- `flutter test --no-pub test/ui_shell_test.dart --reporter compact`：**55/55 通过**，包含新英文失败提示测试。`flutter analyze --no-pub`：**No issues found**。
- 后续用户明确提出“同步数据时，手表时间跟手机同步”。仅对 **已在 App 选择过中文/英文的同一只手表**，在 `UrionWearableBridge.syncHealthData()` 的串行队列中先发送 `0x01` 手机当地时间和已确认的手表语言，再读取 `0x07` 每日数据；语言未知时不猜测、不自动改语言，仍可进入已有日期保护。手动时间设置复用同一发包实现。新增“先校时后读数、跨连接保留英文选择、未确认不校时”两项会话测试。不改健康算法或服务端 API。
- 对手机旧 Debug 会话热更新 9 个库成功；旧包在用户恢复出厂后复现英文失败提示，并经明确语言选择完成手动校时。最终包已覆盖安装、保留登录，但 GATT 服务发现阻塞，**自动校时的最终真机执行尚未验收**。
- `flutter analyze --no-pub`：**No issues found**；定向 `test/ui_shell_test.dart` **55/55**、`test/urion_wearable_bridge_session_test.dart` **16/16**；全量 `flutter test --no-pub --reporter compact` 在本地时区和 `TZ=UTC` 下均为 **927/927 通过**。首轮新测试曾因 nullable `String?` 无法传给 `String` 编译失败；增加明确非空判断后重跑通过，未忽略失败。
- CI 同款 `dart format --output=none --set-exit-if-changed lib test` 返回 1，点名 6 个本轮未改的既有文件；该只检查命令没有改写文件，`git status` 复核范围未扩大。仅对本轮 4 个 Dart 修改文件重跑同命令：`Formatted 4 files (0 changed)`，通过。全仓格式债保留为独立事项，不借本次 U19 调试改无关文件；若 CI 因全仓格式门禁失败，应按此记录单独收口。
- 首次源码提交 `c95ffcc` 的 GitHub [mobile-ci #36525165239](https://github.com/tangwu88/saydian-app-global/actions/runs/36525165239) 已完成：Harmony 两个时区均成功，`quality` 在上述格式门禁对同 6 个文件报 `Formatted 156 files (6 changed)` 后退出 1；依赖 `quality` 的 Android/iOS jobs 被跳过。失败已复核为本轮未改文件的格式债，**云端 Android/iOS 不能记为通过**。后续应单独做格式收口并重跑完整 CI。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64` 与 `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64`：均通过。Debug APK：`184587110` 字节，SHA-256 `5F796E0E565C291A80DEBAC21D0858B30F3A699E6C0C649AD22399CFD4310DC3`；内部 QA Release：`68343160` 字节，SHA-256 `4832A54D012FF538F1BF5A59CC51295976FB5F0DC21E79728BA07598BA12E6FD`。两个包名均为 `cn.saydian.app.global`、版本 `0.1.23+1007`、标题 `SAYDIAN Health`，同一内部测试证书；QA Release 不是正式上架签名。
- Android `:app:testDebugUnitTest --offline --no-daemon`：BUILD SUCCESSFUL；HarmonyOS `node --test --test-reporter=dot harmony-native/tests/*.test.mjs`：host tests 通过，但非 HAP/真机验收。Flutter/Gradle 插件的未来 Kotlin/Gradle 兼容警告未阻塞本次构建；Windows 无法做 iOS 构建。本轮命令原始输出保存在忽略的 `build/real-device-qa-20260929/`，不进 Git。
- 首次安装时 `flutter attach` 成功获得 VM Service；最终重装后尝试再次 attach，前台 App 进程在线但 60 秒内未发现 VM Service，已取消等待，继续以 ADB 与脱敏原生日志调试。**不能写成最终包仍有已附加的 Flutter 会话**；手机保留最终 Debug 包和登录数据。

## 尚未通过的边界

- U19 GATT 服务发现间歇超时在最终包上连续复现，需要继续取证；不能把先前的成功归为故障已修复，也不能把最终包的自动校时测试当作真机通过。
- 国际服务的日汇总能力端点仍返回 404；客户端应保持待同步，不把本机读取或普通 GET 200 冒充云端保存/回读。
- 本轮没有血压、心率、血氧、脉诊启动测量，也没有定时血压启用或其他设置写入；iOS、HarmonyOS 真机未执行。
- 这轮没有生产部署、正式签名或上架。下个同事先更新远端并阅读本记录，再处理开放问题。
