# 2026-11-07 苹果1025正式构建上传与安卓真机调试

## 授权、基线与 CI

用户要求“检查下CI结果，全部通过后构建苹果新版本并上传到App Store”，随后补充“同时安装到安卓手机，真机调试”。两项继续在国际版仓库执行，不操作国内客户端、XR的独立Say Ring或Google商店。

起点codex/us-storage-notices-20261104 / 345622313c9e07622792a99181966d24c3acfe8f，工作区干净；origin fetch及当前分支ff-only核对通过。相对产品源码31bfda130d4f5bfde75416d6138e66a35cd8b89e仅有三份文档差异，排除docs的完整diff为空。

GitHub [42355059740](https://github.com/tangwu88/saydian-app-global/actions/runs/42355059740) 已实际completed/success，质量、Android、iOS、Harmony UTC及Asia/Shanghai五个job分别success。此回读更新上一轮16:27时仍在运行的快照；不使用旧1023 CI作为本次源码证明。源码包含U19脉搏50组历史/本机加密持久化/趋势及iOS实际Urion监测入口；闹钟按用户要求不做。上一轮双时区各1162、两端构建及15pm两条历史/入口的证据见[功能记录](IMPLEMENTATION-20261107-U19-PULSE-MONITORING.md)。

## 预检与安排

17:12（Asia/Shanghai）实际App Store Connect国际版6817980969/TestFlight最高上传构建仍1.0.2（1023）。本次选择1.0.2（1025），正常lib/main.dart / cn.saydian.app.global / SayDian / 美国.com接口 / 远程推送关闭。CLI覆盖版本，保留跟踪的pubspec开发标识，不改变经CI验证的产品代码。

本机磁盘余量约13GiB。钥匙串列出有效Apple Development身份；自动App Store发行签名是否可用，以实际导出结果为准。复用上一轮已成功的临时自动签名导出设置，团队W7SXQ4A226，不撤销证书、不修改苹果账户或接受新协议。归档、导出、上传、Apple列表回读分别记录；本次上传不等于正式送审或上架。

adb只显示一台已授权USB安卓设备，华为PPA-LX3 / Android10 / API29 / arm64。先核对国际包安装状态；只向该手机安装国际版调试包，不卸载或清数据，不改变其他包。真机调试、首页/VM、热重载和蓝牙业务分别验收。同一仓库Flutter/iOS构建串行，另一XR的Say Ring Profile会话不动。

正式包放忽略目录build/store-upload-20261107-1025/，构建及签名日志、设备私有证据存受限/private/tmp/saydian-ios-upload-1025-20261107/，不提交账号、密钥、手机内容或原始日志。后续每轮实际结果与失败继续追加。

## 发行门禁与归档

`python3 -m unittest discover -s scripts/release -p 'test_*.py'`：25通过，6.446秒。输出中的拒绝跨源、恢复/锁失败及回滚文字均为预期合成反例，不是本次实际发布失败。

沿用正常1.0.2（1025）CLI版本覆盖、.com/API更新地址、无推送、SAIDIAN_PRODUCTION_RELEASE=true / SAIDIAN_ALLOW_QA_RELEASE=false；iOS15最低版本和团队设置为本次忽略目录临时配置。旧默认archive/ipa输出若存在先移动到本次目录的preserved-default-*，旧1023正式包及1024调试候选均保留，未清理系统缓存。

Xcode归档60.8秒完成，257.1MB；实际Info.plist/深度严格签名/团队与应用标识、iPhone-only/iOS15/无推送或HealthKit/无Bonjour调试声明、AOT美国域名和无QA入口/Always定位请求检查通过。归档仍为Development签名（get-task-allow=true），不是最终发行IPA；自动App Store导出另验。

安卓`pm path`和`pm list packages`均确认未安装cn.saydian.app.global，run-as不可用与尚未安装一致，没有执行提权或读其他App数据。只做首次安装，无旧国际版数据可备份。私有APK验证辅助脚本首次生成引号错误，py_compile报SyntaxError；修正脚本三条字符串断言后py_compile通过，未修改产品代码或降低校验要求。

## 发行包已核验、上传开始

自动App Store导出158.0秒成功。实际IPA为build/store-upload-20261107-1025/export/SayDian.ipa，37,957,007bytes，SHA256 846efd878c95023bdb5c4d0655cd794175aa7125bc806bc2688d7ad6db690687。Apple Distribution签名、严格deep/strict校验、W7SXQ4A226团队/包名/1.0.2（1025）/iPhone/iOS15均正确，get-task-allow=false，App Store描述文件无设备列表/全设备分发，推送/HealthKit及调试Bonjour声明为空。实际导出可执行文件的美国地址、QA入口/Always定位检查也通过。

归档与导出中的Runner、App.framework/App的arm64 UUID及所有有文件内容的Mach-O section摘要分别一致，签名变化不被误判为程序变化。ipa-verification.json仍标uploaded=false，仅表示本地验证；上传以独立回执为准。没有因钥匙串仅列Development身份而提前判定发行签名不可用，本次自动发行导出真实成功。

以上核验通过后，使用同一份已隔离的Runner.xcarchive启动destination=upload的xcodebuild -exportArchive / -allowProvisioningUpdates。该步骤重新打包上传，不能把本地IPA压缩文件hash当成传输压缩包hash。苹果Flutter归档/导出已结束，之后才开始安卓Flutter构建；苹果上传只读隔离归档，不再共用编译产物。

## 安卓调试包

正常main / Play Debug / 双ARM / CLI1.0.2（1025）构建18.9秒成功，远程推送关闭、生产/QA发行模式均false、SAIDIAN_PLAY_STORE=true及美国API/更新定义明确传入。产物隔离为build/android-debug-1025-20261107/app-play-debug.apk，159,143,727bytes，SHA256 c16b5e4dd4d33b40521bf5b13dc382d6113361ee6aac33f137b79b6f3633aa58。

实际aapt/apksigner/ZIP检查确认国际包名/1025/最低API26/Debuggable/Android Debug证书、armeabi-v7a和arm64-v8a两ABI及kernel美国地址通过。最低API26适配目标API29。此APK是手机调试包，不是Google Play正式提交包。

核验后才对指定唯一USB手机执行adb install -r -t；没有-g批量授予权限、-d降级或卸载/清数据。安装成功、启动、VM与热重载在后续回执独立记录。

## 苹果上传成功与后台回读

实际upload-mode xcodebuild退出0，日志2026-11-07 17:22:31.921（Asia/Shanghai）明确Progress 100%: Upload succeeded及EXPORT SUCCEEDED。upload-receipt.json已标uploaded=true，并关联实际源码CI、归档和独立核验IPA。15项既有厂商dSYM缺失警告未阻断上传；不伪造符号文件，也不把它们误写为上传失败。

App Store Connect国际版6817980969/TestFlight真实列出1.0.2（1025），构建资源8657266b-b314-46dc-805b-a5e257a29072，当前状态“缺少出口合规证明”；1023仍在原列表。截图已实看并保存于忽略的release目录app-store-1025.jpg。首次刷新仅有加载骨架的截图保留为app-store-1025-loading.jpg，不把空白帧当回执。

这证明本次包已送达正确苹果App，尚需补充该构建的出口合规信息，不能记为准备测试/已送审/审核通过或已发布。本轮没有填写新的加密声明、替换1023审核关联、添加测试群组或触发测试邮件。没有改苹果账号、接受协议或操作Google商店。

## 安卓安装、启动和调试成功

安装先停在华为系统“风险提示/继续安装”；实拍确认阻挡后请用户在手机确认，用户回复“已确认并完成安装”。随后adb实际退出0/Performing Streamed Install/Success；安装后dumpsys确认versionName1.0.2、versionCode1025、installed=true、DEBUGGABLE。首次安装，没有卸载/清库或改其他包。

正常MainActivity启动返回Status: ok；用户已经打开应用时返回intent delivered to currently running top-most instance，未强行重启。实拍为SayDian英文登录页，账号和密码均为空。空输入验证提示不是登录接口故障，不用此页面声称账号登录或蓝牙业务通过。

以指定USB序列号和--app-id=cn.saydian.app.global执行正常Flutter attach，不禁用VM认证；SOURCE同步8.0秒完成。实际getVM HTTP200/typeVM/main、VM PID与手机国际版PID32537一致。第一次私有身份校验脚本错误要求命令中snapshot与attach连续出现，因中间正常存在--no-version-check而AssertionError；尚未发信号，修正为shlex逐参数核对后通过。未向未识别进程发信号。

官方--pid-file/SIGUSR1热重载8/2226库、2371ms成功，未重启、清数据或替换QA入口。内部浏览器DevTools真实显示Connected app / Flutter native(debug build) / arm64 android，Dart3.12.2/Flutter3.44.9。当前会话保持，连接令牌与手机/主机PID仅存受限android/debug-session.json，页面截图及原始日志不进Git。已请用户在手机登录美国测试账号并保持前台，密码不在聊天输入；登录后业务、U19S连接、新测量或云回读不从安装/调试成功推断。

## 复现命令与交付边界

```sh
python3 -m unittest discover -s scripts/release -p 'test_*.py'
flutter --no-version-check build ipa --release --no-pub --target=lib/main.dart --build-name=1.0.2 --build-number=1025 --export-options-plist=build/store-upload-20261107-1025/ExportOptions-Local.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
xcodebuild -exportArchive -archivePath build/store-upload-20261107-1025/Runner.xcarchive -exportPath build/store-upload-20261107-1025/upload-1025 -exportOptionsPlist build/store-upload-20261107-1025/ExportOptions-Upload.plist -allowProvisioningUpdates
flutter --no-version-check build apk --debug --flavor play --no-pub --target=lib/main.dart --build-name=1.0.2 --build-number=1025 --target-platform android-arm,android-arm64 --dart-define=SAIDIAN_PLAY_STORE=true --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
```

环境标志见上述归档/安卓章节；发行签名、私有验证脚本和实际回执分开保留。普通1162项双时区与四项平台门禁沿用同一产品源码上一轮结果，并由本次五job成功CI独立覆盖；本轮只做版本覆盖构建、发行核验/上传与安卓安装调试，不修改产品源码，因此没有重复全量回归。本轮没有给iPhone重装1025或验证Release1025的实体新测量。XR独立Say Ring会话未动。

文档及索引一起提交当前国际分支，使用[skip ci]避免仅记录变化重跑同源构建。归档/IPA/APK、手机截图、账号、认证令牌、原始日志和原始协议均留在忽略或私有目录，不入Git。最终Git全树及工作区核对在交付前完成。

## 安卓调试连接恢复（17:35复核）

收尾getVM遇到ConnectionRefused，初次主机Flutter进程已退出，原日志末尾Lost connection to device、退出0。adb仍可用但transport_id从8变10；手机国际版PID持续为32537。此证据表明主机调试连接需要重建，不把它写成App崩溃，也不推定是用户或其他任务引起。没有重启adb server、卸载/重装、停止App或清数据。

从指定PID的原生Flutter日志读取实际VM公告，建立仅本轮设备/端口的只读转发并getVM确认同一main/PID。第一次重附加误将已转发的Mac URL作为Android --debug-url，Flutter再次转发该端口，实际退出2/Connection closed before full header was received；保留flutter-attach-r2.log。核对本机Flutter attach.dart的buildVMServiceUri实现后，改传设备原始VM URL，让Flutter只转发一次，不关闭服务认证。

第三轮附加同步5.5秒成功；getVM HTTP200/main/PID32537，重新热重载8/2226库、2427ms成功。DevTools现有页已换到新会话，实际再次显示Connected app / arm64 android。17:35源码页面树仍是GlobalAuthPage，最后一轮无Lost connection、Unhandled Exception或Widget异常头。没有用户登录回报，不将登录或U19S业务计为已验。当前唯一有效会话以私有android/debug-session.json为准，旧连接日志保留；不再沿用失效的初次端口。上述连接恢复不改变APK、苹果归档或上传结果。

## 安卓登录后复核（17:54，Asia/Shanghai）

用户补充“已登录并保持前台”。实时VM仍HTTP200/main，手机与VM的国际版PID均32537，ADB transport维持10；最后附加日志无断连、Unhandled Exception或Widget异常头。实拍当前是英文Connect a device / Devices found页，已发现多台附近设备，页面与可见刷新/连接入口正常，不把扫描当成成功配对。

只读VM对象字段确认唯一生产AppController的session为Session实例，API实际类型GlobalSaydianApiClient，运行中_baseUri为https://app.saydian.com，connectedDevice为null。读取前明确验证字段存在及类型，不从缺少字段推断登录成功；未读取/输出Session令牌、密码或健康原值。本轮验证了已登录会话和实际运行域名，与国际版配置一致。

辅助检查最初尝试VM evaluate纯布尔表达式，返回No compilation service available；未修改源码、注入编译服务或重启应用，改用只读getObject字段完成核对。网络摘要扩展getHttpProfile返回0条，未开新抓包或凭空补样本，因此本轮不声称复验了登录HTTP状态、新测量上云或ACK。查询一个不存在的本机SDK参考文件路径时rg退出2，改读实际network_profiling.dart及http_impl.dart；这不是产品故障。

因附近有多台设备，已请用户选择本轮测试型号，可继续末尾27:65的U19S、改其他型号或仅保持调试。17:54仍未连接，不自动选择其他设备，不启动测量或修改监测计划。用户密码只在手机输入；当前App和调试会话继续保持。此轮仅补充真机记录，未改产品代码、构建/安装包、苹果或Google后台，既有CI和发行回执不变。

## 安卓 U19S 只读功能验收（18:01，Asia/Shanghai）

用户选择继续此前末尾27:65的U19S。随后实拍设备页U19S_SD_2765 / Connected / 48%，Health monitoring与Pulse insights入口均显示；运行Controller的connectedDevice.id精确匹配该已确认目标，urion前缀按现有DeviceInfo.sdkSource规则路由，未按同名设备猜测。设备地址和原始截图仅存私有证明，不在此公开完整标识。

用户按提示完成Sync device、查看监测页及Read device history，并回复“已同步，两页正常，已停留脉搏页”。最后实拍Pulse insights含Saved readings (2)、两条记录及三条原始指数趋势，7天/30天/全部筛选可见。Controller健康评估缓存也为pulseHistory长度2、有最新pulse。原值和设备时间保留，不生成额外样本；没有以主机合成截图代替此轮安卓样本。未重启手机/App验证重开持久化，不能把已有SQLite关闭重开自动回归改为本轮实体重开验收。

对唯一、仍匹配该目标的UrionWearableBridge做只读对象核对，_dynamicPressure为由协议解析得到的Eb1DynamicBloodPressureSettings，enabled=false；关闭态的开始时刻与日/夜间隔原始字段均0。这是已有设备状态，不是本轮设定的计划。用户确认监测页面正常；本轮没有启用计划、写间隔或开始自动充气，不声称定时硬件执行/写后回读已验收。

同步结束状态isDeviceSyncing=false，syncStatus“设备暂无新数据”，cloudSyncState=idle，本次上传0/拒绝0，errorMessage=null。因此本轮读取/同步流程无返回错误，但没有新增可上传传感记录，不能声称验证了新测量、首次云ACK或服务器逐条内容回读。脉搏三指数继续按既有范围本机保存；血压/心率/血氧已有美国云策略未改。

本次登录记录已另交付bc3e75a，完整tree与本机一致；本地等价提交0750660保留。恢复本地跟踪分支时一条命令因工作目录漏写前导斜杠未能启动，校正绝对路径后成功，源码/手机数据无变化。所有VM读取均不用evaluate编译服务，不输出密码、令牌或真实健康原值；原始字段/截图和同步摘要在同一受限android目录。

本轮只追加真机证据与交接说明，没有发现需要修改产品代码的新增异常，未再构建、重装或操作两商店。调试会话和已连接U19S保持，闹钟仍按用户要求暂不做。上面的17:35登录页和17:54未连接是过程快照，以本段最新验收为准。
