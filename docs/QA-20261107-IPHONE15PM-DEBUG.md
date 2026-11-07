# 2026-11-07 SayDian 国际版 iPhone 15 Pro Max 真机调试

用户要求安装到指定15pm并开启真机调试。本轮为国际版 cn.saydian.app.global，不恢复上轮已经取消的 Say Ring 六项问题任务，不操作 XR 的另一 Say Ring 调试。起点408003a1b72d131569d435d34b4df8a5a5b87382，工作区干净；git fetch --prune origin / git pull --ff-only均成功且无需更新。正常lib/main.dart运行源码与之前接受的0002cd7相同，没有产品源码、依赖、法律文档、商店提交或服务器变更。

## 设备、备份与构建

指定15pm UDID00008130-001C098C2290001C，iPhone16,2 / iOS26.6，USB wired、paired、Developer Mode enabled、已解锁。原国际App为1.0.2（1023）。同仓库无其他编译；XR的Say Ring Profile进程和其他同事调试器保留。

原App没有运行进程。对Documents、Library/Application Support和Preferences创建新私有备份，位置在用户Library/Application Support/SayDian/DeviceBackups；不导出Keychain、不解密健康库。受限本轮日志为/private/tmp/saydian-iphone15-debug-20261107，截图/凭据/数据备份不入Git。

使用既有本机Apple Development身份、团队W7SXQ4A226与临时XCODE_XCCONFIG_FILE（iOS15最低版本），指定美国.com API/update并关闭远程推送。flutter build ios --debug --no-pub --build-name=1.0.2 --build-number=1023成功，Xcode25.5秒。旧厂商SwiftPM与模拟器arm64警告保留，不影响本次实体arm64设备。未改跟踪的pubspec开发标识或发行构建。

实际签名strict/deep通过；应用cn.saydian.app.global/1.0.2/1023、get-task-allow=true、应用标识/团队和描述文件含指定手机均通过，描述文件有效至2027-10-13。Debug kernel包含美国API，目标正常main；TRACK_WIDGET_CREATION=false。验证后复制到忽略的build/iphone15pm-debug-20261107/Runner.app。Runner SHA256983ec50c78eeca1270bd8052052bebe58887e26b648abe0671a9bd926a82967c。

## 实际安装与启动前数据证明

devicectl install app指定手机成功，官方安装列表回读为1.0.2（1023）。首次启动前回读对比Documents/Application Support：5文件/3数据库/10,141,687bytes全部大小和SHA256一致。容器路径变化而内容保留；无需恢复，也未卸载或清库。Preferences单独备份，不声称系统可变偏好或启动后数据库逐字节不变。

## 失败过程与纠正

- 最初旧备份助手期待默认app JSON含bundleContainerPath；新版devicectl默认省略该字段，KeyError在复制/安装前停止。改用实际已返回的url匹配；独立进程清单确认旧App本来没有运行，再成功备份。后续枚举显式--include-container-paths。
- 首次带console启动的launch.json尚未生成便读取，得到FileNotFoundError；改用实际进程清单确认精确国际App PID。没有从缺失回执推定启动失败或重装。
- 初次手工LLDB调用误填了不存在的PID20030，返回no such process；真实国际App为19995，未附加其他应用。随后复用该调试器附加19995遇到EXC_BAD_ACCESS(code50)的JIT启动异常，没有将启动画面/进程存在声称调试成功。
- 只结束本轮Flutter attach及对应LLDB；SIGTERM在调试暂停状态未使19995退出，第二次launch回执仍为同PID，未算成新的启动成功。随后对这个已确认的国际进程SIGKILL，再全新start-stopped启动得到20011；新LLDB在创建目标前加载Flutter官方JIT helper，PID直接从实际launch JSON读取，不再手填/重装/改代码。后续真实VM/页面/热重载结果单独追加，不把上述失败覆盖掉。

## 本轮命令

```sh
git fetch --prune origin
git pull --ff-only
flutter --no-version-check build ios --debug --no-pub --build-name=1.0.2 --build-number=1023 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
xcrun devicectl device install app --device 00008130-001C098C2290001C build/iphone15pm-debug-20261107/Runner.app
xcrun devicectl device process launch --device 00008130-001C098C2290001C --start-stopped cn.saydian.app.global
# LLDB: load ios/Flutter/ephemeral/flutter_lldb_helper.py before target creation;
# select the exact15pm, attach --pid from the actual launch JSON --continue.
flutter --no-version-check attach --debug --no-track-widget-creation --device-connection=attached --app-id=cn.saydian.app.global -d 00008130-001C098C2290001C --target=lib/main.dart --pid-file=PRIVATE_PID_FILE --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
```

备份和回读使用devicectl copy from的appDataContainer、精确国际包名及三个指定目录；严格签名/描述文件校验和逐文件比较的私有机器可读证明保留。此轮没有产品源码修改，不重复相同源码已记录的1151双时区回归/两端构建/CI；仅本轮新构建、实际安装、调试和数据保留证明另记。三项测量/蓝牙/云端ACK不因调试启动而自动验收。

补充调试启动方法纠正：初次新LLDB启动器使用Python heredoc后exec，导致交互stdin已到EOF；该调试器未持续存活，不能作为附加成功。改为受限目录中的独立启动脚本，保留PTY标准输入，再对精确国际bundle执行start-stopped/terminate-existing并从最终回执读取PID。此过程只重启本轮国际App，没有重新安装、改写数据、结束XR或修改产品代码。

一次附加已完成源码同步并打印VM URI，但随后结束前一等待附加进程时，新连接也报Lost connection，URI回查Connection refused；未将打印地址等同VM健康或成功热重载。手机当时切到微信，重新激活精确国际bundle后实拍为英文Connect a device搜索页，能发现附近候选，但没有替用户选择或绑定。后续mDNS能发现服务，直接连接旧服务端口仍拒绝；不改网络权限或数据。清理范围仅本轮遗留的国际附加/调试进程，重新启动精确bundle，最终阶段只保留单个Flutter attach及单个LLDB，结果在下段独立验证。

## 最终实际结果

单个Flutter attach在新进程20053上完成源码同步6.8秒并保持连接。手机曾切到微信/后台，首次DDS getVM HTTP超时，DevTools仍为加载动画；此时没有声称成功。向精确国际bundle重新activate使同一进程前台运行后，实际热重载完成：Reloaded 0 of2224 libraries in27,439ms（compile225ms/reload119ms/reassemble160ms）。没有代码改动，0库变化是预期；实际reload/reassemble成功，27秒为该次真实总用时，不伪写成仅编译耗时。

随后getVM实际HTTP200/typeVM、PID20053、main isolate均通过，与指定手机国际App进程匹配。本轮最终Flutter PID53148与原生LLDB均保持运行，会话地址/PID/回执存于私有debug-session.json、vm-info.json、debug-proof.json。DevTools已在内部浏览器打开并保留；实看Connected app /Flutter native(debug build)/iOS/Dart3.12.2/Flutter3.44.9页面，已越过加载动画。无须再次登录、卸载或恢复数据。

当前运行仍是正常main的1.0.2（1023）Debug，不是新商店构建；手机英文Connect a device页面及附近设备列表曾实拍确认，不因看到候选设备而宣称已连接、同步或新健康记录上云。用户上轮跳过的三项新测量不重启，已取消的Say Ring问题任务仍终止。15pm需保持USB、Mac调试进程与前台以便连续验证；独立冷启动使用Profile/TestFlight/Release。

额外诊断工具：一次直接执行SDK iproxy --help缺少DYLD_LIBRARY_PATH而报告dylib未找到；未改SDK或系统库。Flutter自己启动的iproxy进程与其库环境正常，本轮最终VM连接已实际验证。旧Bonjour查询及私有诊断进程结束，保留最终Flutter/LLDB及另一台XR，不清理其他同事或历史进程。本轮只补设备记录及交接，不改变产品源码、运行配置、健康原值或任何商店审核状态。
