# 2026-11-07 U19S 脉搏历史与动态血压入口

基线559e040c4b987b7a16dd8fd2526a5f5a9b1e6f6f，codex/us-storage-notices-20261104，工作区干净，origin fetch/ff-only均通过。当前运行国际版1023 Debug，指定iPhone15pm，XR另一SayRing不动。

## 修改前定位与预期

- P1：iOS动态血压入口缺失。连接真实U19S后，Dart与原生的旧命令范围拒绝0x36等读取，Dart功能投影隐藏healthMonitoring/healthAssessment。预期仅针对实际Urion通道的已验证能力开放脉搏和监测，其他厂商范围、原健康原值、云上传和分享契约不变。动态血压保留明确确认、间隔校验及写后回读，不自动开启定时充气。
- P2：脉搏只有最新一次。原readDeviceFeature仅count1且仅放内存feature缓存，无历史库。预期读取协议最新50组，按账号/环境/精确设备保留加密历史，重复读去重，增加实际采样点趋势和分页记录；不混为bpm，不做医疗判读、不上传无契约的三个指数。时间使用原厂4字节秒时间戳，不用读取时间伪造历史，异常/未来时间不作有效趋势。
- P2：U19S闹钟提醒未接入。只读找到用户提供的EB1原始docx，闹钟事件标“暂未使用”，没有可用闹钟/久坐/喝水读写命令。用户明确“闹钟功能先不做”，本轮不发猜测指令，也不添加虚假功能入口。

涉及policy/routing、Urion桥接与协议展示、本机SQLCipher metadata可选专用存储接口、Controller、脉搏历史组件及相应回归；不改变国内App、服务器、法律正文、账号/Keychain或商店审核。只读原协议提取在受限/private/tmp/saydian-u19-features-20261107，原件不改不入Git。每轮测试/失败/真机/构建结果继续追加。

## 第一阶段自动验证

新增普通测试覆盖：原值/零分/无效分数、未来时间不绘图、iOS精确Urion功能边界及路由、50组原始历史包、重复读取去重、新结果与历史合并、Controller重建回读、跨设备迟到读取、真实SQLite关闭重开和账号/设备隔离、不进入健康云队列；三条图表曲线按真实时间和指数、单点与空态、筛选/分页、中英文320宽1.8倍字号，以及动态血压编辑不暗写。生产仍用原SQLCipher，FFI测试不声称验证了手机加密算法。

首轮格式化发现命名参数括号后多余逗号，修正后analyzer无问题。首轮定向72通过/2失败：一项揭示原桥接还存在iOS专用提前返回，已移除重复分支，统一使用逐协议只读发现而不是按型号猜能力；另一项为Widget平台覆盖变量未在框架检查前复位，改try/finally。未改掉“发现能力绝不启动测量/写监测”的正确预期。复测74项全部通过。最终analyzer无问题，UTC全量1161项通过，原安全回归包含在普通test中。

原生Swift固定范围验证编译/运行通过；随后Node生命周期命令因本机登录Shell缺少node报command not found，尚不计通过。另一次Node工具中的process未定义，仅为工具定位失败，未改变产品源码。继续使用可核实的现有运行时，不下载新依赖或修改全局环境。另一时区全量与Android/iOS新构建继续记录。

## 最终自动回归、布局及构建

人工实看合成25条历史的390宽截图和320宽1.8倍字号截图，发现图表纵轴10因宽度不够换行，已按文字缩放扩展轴宽；没有把仅自动渲染无异常当作视觉通过。测量/读取按钮移至历史列表之前，防止20条记录把主要操作推到底部。监测状态只接受协议1/2，其余不显示为“关闭”。补充未知监测状态回归。

以上最后产品代码的analyzer无问题，UTC全量1162项、Asia/Shanghai全量1162项均通过；原AUD安全测试均在普通回归中。最后两张标准/窄屏大字截图已重新生成，均通过并实看；它们明确是主机合成页面，不是真实健康样本。布局用原生产组件，不把合成记录写入手机或服务器。保存页显示3个原始指数，7天/30天/全部，实际时间点直线、0..10固定轴及分页；大量点仅为绘图保留每条序列峰谷，完整历史仍保存在库中。

首轮Android Debug58.3秒、QA Release109.1秒、iOS Debug36.7秒、Profile无签名90.2秒均通过。之后布局/未知状态修正，最终Android Play Debug14.3秒、QA Release48.2秒、签名iOS Debug63.1秒重新通过；最终iOS Profile结果按实际结束回执追加。既有SwiftPM/模拟器arm64/Kotlin迁移提示不作为新功能异常。QA APK不用于商店，iOS新1024仅为真机调试，未替换1023审核。

原生固定范围Swift编译并执行通过，Urion以外桥接仍保留旧范围。Node源码生命周期辅助检查因本机没有可用node CLI未执行；Node REPL也明确禁止process模块，停止该工具定位，不改系统/SDK/环境或绕过工具限制。此辅助测试涉及未改的Gatt生命周期源；不把它记成通过。

## 手机安装数据保护（启动前）

1024已生成严格Apple Development签名包，团队/应用标识、指定15pm授权通过。最后Runner SHA2565c953918a9242854986137fd253ea9c3f05266b751755de044ed698489ffde5c。隔离候选在build/u19-features-1024-20261107/final/Runner.app；包名cn.saydian.app.global/1.0.2/1024/正常lib/main.dart，美国.com接口且远程推送关闭，不含QA入口。

对原1023创建新受限备份，随后初版1024覆盖安装并在启动前证明5文件/3数据库10,146,893bytes全部一致。由于最终布局修正，初版不当最终结果；保留初版候选，另生成最终候选，再创建一次当前数据备份后安装。最终启动前的5文件/3数据库10,146,893bytes同样逐字节一致，无需恢复/卸载/清库。只有实际已确认的国际App进程及本轮旧调试器结束，XR未动。启动后的正常数据库写入不承诺字节不变，原件和两轮备份保留。

正在用全新原生LLDB和单个Flutter attach启动最终1024。只读原设置/打开编辑器/取消可验收，定时充气或新测量需要用户在手机明确操作；本轮不自动启用、改间隔或启动充气，不以入口出现声称硬件计划执行通过。实际VM、页面、历史数量及用户反馈将继续追加。

最终iOS Profile无签名构建46.3秒成功，四项最终构建门禁均已通过。原生Swift验证使用xcrun swiftc编译WearablePayloadMapper.swift和test/native/ios_wellness_policy_main.swift后运行；固定命令范围与其他厂商限制都有断言。

## 最终1024调试已建立（设备页专项仍待用户连接）

最终包原生启动回执PID20221，单个Flutter attach源码同步5.9秒完成。getVM实际HTTP200/typeVM/PID20221且main存在，正常英文原账号首页已实拍；只保留当前一组LLDB/Flutter会话，旧1023的Lost connection来自本轮计划停止/覆盖，不记为新版本自发崩溃。热重载请求及最后设备页结果继续追加。会话地址/令牌与日志只放受限debug-session.json，不进Git。

已请用户在15pm连接U19S并打开Health monitoring，暂未获得本轮实体返回。因此“代码/自动测试/构建/安装/调试”与“真实动态血压回读、脉搏历史数量/持久化、计划执行或新测量”仍分开；本轮不代替用户启动充气，不宣称硬件全部通过。Swift仅另修正两行旧注释，明确脉搏指数本机保存、传感云同步与关爱策略分别管理，无运行逻辑差异。

## 复现命令与证据位置

```sh
flutter --no-version-check analyze --no-pub
TZ=UTC flutter --no-version-check test --no-pub --reporter=expanded
TZ=Asia/Shanghai flutter --no-version-check test --no-pub --reporter=expanded
flutter --no-version-check test --no-pub --reporter=expanded test/urion_pulse_history_test.dart test/urion_wearable_bridge_session_test.dart test/urion_ios_local_health_test.dart test/ios_wellness_policy_test.dart test/prototype_coverage_test.dart
xcrun swiftc ios/Runner/WearablePayloadMapper.swift test/native/ios_wellness_policy_main.swift -o PRIVATE_TEST_BINARY
```

Android沿用正常Play双ARM、.com、无推送构建参数，QA Release显式SAIDIAN_ALLOW_QA_RELEASE=true；iOS串行Debug/Profile均显式CLI1.0.2/1024、正常main、.com/update、无推送，使用此前临时XCODE_XCCONFIG_FILE。主机截图使用test/support/ios_inner_page_capture.dart的global-u19-pulse与390/844、320/900+1.8参数。完整原始构建/测试/失败与签名回执在/private/tmp/saydian-u19-features-20261107；受限手机原始图和备份不入Git。

源码及所有新增普通回归、可选合成截图夹具、实施和索引记录一起提交当前国际分支；不合main、不触发国内服务。源码Git/本机与远端完整tree、CI实际状态在交付时分别记录，不用旧CI冒充本次源码绿灯。闹钟按用户最新指示跳过，不计故障已修复。
