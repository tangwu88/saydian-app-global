# 2026-11-04 美国数据存储提示

用户要求在连接帮助、隐私政策、数据同步等位置增加美国本地存储提示。基线4bb0be63fcc7c10eef2345166923a44659a7348f，origin fetch/ff-only通过、工作树干净；独立分支codex/us-storage-notices-20261104。

本轮是已有已审核美国存储事实的界面提示，不改r4法律正文、协议版本、账号/采集/上传/ACK/关爱权限。说明SayDian云端数据位于美国；待上传数据在手机保留，直到服务器确认。美国声明只指第一方云端，不笼统保证手机或第三方服务都位于美国，不承诺绝对安全。首页不新增提示横幅，沿用用户此前的页面安排。

实施范围：共享短提示、连接帮助页、设备同步区域及已加载的隐私政策页；现有完整Data privacy说明保留。英文默认，其他现有语言同步。现有iPhone15pm/1022调试正常，采用热重载验证本轮UI，保留安装数据、登录态和另一XR的独立调试。

验证结果与失败记录随后按实补充。尚未将界面文案改动当作新的真实测量上云或商店发布。

## 过程修正

初次analyzer发现原私有_InfoPage因连接帮助改用可滚动的ConnectionHelpPage而不再使用，已移除未引用类；离线截图夹具误给只读deviceState赋值，已移除无效赋值。没有修改设备状态机。初轮自动测试日志保留，最终检查另记。

初次真机热重载后出现Flutter SDK ListenableBuilder构造器NoSuchMethodError，随后进程退出（status0）。没有据此声称新文案已在手机通过。保留堆栈；不改SDK或健康业务，改为完整iOS签名构建并对齐调试编译选项后重新启动正常入口。新一轮安装前再次独立备份当前手机数据，6文件，受限保留于用户私有备份目录。恢复与附加的实际结果后续追加。

新界面提示不触发同步、不标记ACK、不记录协议同意。r4已发布正文保持不变，无需创建新法律版本。

小屏截图额外复现320宽/1.8倍文字时设备同步区域右侧溢出29px。保留失败截图与日志；同步/断开按钮在窄屏或大字体下改为纵向排列，待上传说明与重试按钮使用可换行布局，操作回调及同步状态来源不变。美国提示本身保持自动换行，不压缩用户字体。随后重新运行截图和回归。

## 最终自动回归和布局

最终源码analyzer零问题（5.1秒）；UTC全量1151/1151（50秒）、Asia/Shanghai全量1151/1151（40秒），退出0。未新增为简单文案镜像实现的测试；复用现有全量及opt-in离线截图入口，扩展两个空数据页面用于视觉核对。

连接帮助411宽正常字体截图通过；设备同步320宽/1.8倍文字截图在自适应修正后通过，无RenderFlex溢出。两张截图已实际打开检查，文字均英文，图标与段落可读。图片来自离线空数据夹具，不是真实采集或云端成功证明。预览位于忽略目录build/us-storage-notices-20261104/help与sync-r2。

Android Play Debug13.3秒和内部QA Release30.1秒通过；推送仍关闭、ARM双ABI不变。串行iOS Profile及开发签名Debug正在运行，实际结果随后追加。dart format/diff检查通过。r4法律内容没有变更，不产生新的法律版本或发布动作。

## 最终构建、安装与调试结果

串行iOS Profile无签名50.4秒、开发签名Debug23.9秒通过；最初手动安装的已验证候选Runner SHA256 d1039ab558448d370ea07608d9e0fc7216851a286e24442cec14b4e7825b948c，实际cn.saydian.app.global/1.0.2(1022)，strict codesign/手机描述文件通过。手动覆盖后、启动前与最新私有备份逐字节核对，5个Documents/Application Support文件/10,127,599bytes（3数据库）一致；未出现空容器，未恢复或覆盖原记录。Preferences另有备份。

手动LLDB恢复时先遇到异步attach后过早continue的“Process must be launched”，再出现EXC_BAD_ACCESS；保留日志并停止本任务的旧进程/手动LLDB，不停止XR或其他产品会话。没有把这次手动附加当成功。随后改用标准Flutter run正常lib/main.dart、--no-uninstall-first、--track-widget-creation及相同美国defines，SDK自行管理编译/安装/LLDB。标准流程Xcode18.9秒、安装启动82.7秒、源码同步139ms；实际VM/main isolate及国际版进程PID1971匹配。

标准流程后SIGUSR1热重载真实回执 `Reloaded 8 of 2224 libraries in 675ms (compile:112ms,reload:128ms,reassemble:70ms)`，后续无NoSuchMethod/EXCEPTION/断连；调试器保持附加。新DevTools已替换旧会话。运行中设备文件元数据确认3个数据库仍在（9,650,176bytes）；这不是运行后的逐字节不变断言。临时运行时UI导航evaluate返回113未执行页面跳转；页面位置与小屏视觉证据使用已注明的离线真实组件截图，不冒充真机逐页点击验收。

当前活动会话指针在私有 `/private/tmp/saydian-us-notices-20261104/debug-session.json`，不要使用旧iphone15-debug目录里的会话URI。原始运行日志/截图/会话URI/备份不入Git；其余证据保留受限目录。手机可继续使用当前更新后的1022调试包，独立重启仍遵守Debug需附加工具的既有规则。本轮没有上传新商店包或改变在线法律文档。

## Git与CI

本机源码ff4007b5bb1a8f1805b4135a995ba884c38e80b5通过已授权GitHub连接发布为748aaaaed9884ade0e2ea84e66e59fbf0f2c0ef8，完整tree a6e3b6beb2eae49208e2cc0108139600a5c0a4bf一致。已fetch/diff核对并跟踪规范远端；原本机历史保留codex/us-storage-notices-local-20261104，没有main合并或force push。源码CI41774487076已触发，送交记录时仍在运行；最终状态另验，不将本机通过当云端已通过。本次追加仅文档，跳过重复CI。

手机前台切回本国际版同一PID1971后，实际设备页已显示已连接U19S、美国数据存储提示及独立的云同步状态。该页实拍已打开检查，当前手机使用中文设置；英文版连接帮助另有已标注离线组件预览。此单页实拍补充真实UI证据，不代表隐私/帮助全部真机逐页验收，也不证明三项新测量的逐条ACK。

## 用户截图后的界面收口

用户明确要求设备页去掉独立美国数据存储卡，把美国位置并入原有小字。已删除设备页该卡及间距，连接帮助与隐私页的共享说明保留。云同步上传中/待上传/已确认三种文案加入“云端（美国服务器）”及对应九份语言；仅本机状态仍明确留在本机，不改ACK/上传业务。手机使用标准Flutter run热重载，避免再次安装。结果随后追加。

用户进一步要求连接说明“变成一个整体”。步骤、美国存储说明和隐私入口合入同一Card，统一20px内边距，用细分隔线区分内容；隐私入口在卡内左对齐并去掉重复地球图标。其他页面继续使用原共享提示。相关语言连接步骤统一“设备”称谓，沿用戒指/手表共用要求；不改连接动作。

本轮基线bb86021682b3657355dc7d3b11bc078315fe1c53，首次收口前干净且已跟踪远端；修改期间仅fetch核对远端仍相同，不对未提交改动pull。涉及data_privacy_page.dart、device_pages.dart及九份ARB/生成文件，保留r4和原上传状态来源。

设备页收口热重载35/2224库、954ms成功。合并帮助页热重载35/2224库、30,961ms成功（编译334ms/reload191ms/reassemble108ms）；初次读取日志过早尚无完成行，检查脚本AssertionError只表示没有等到回执，后续已核对完成行，无新增异常/断连。该次过早截图实际为用户当时前台另一App，未作为SayDian证据；随后激活精确cn.saydian.app.global同一PID1971，实际设备页已显示英文US servers小字、无独立美国提示卡，U19S连接仍在。没有操作另一App的数据或XR。

帮助页正常411宽及320宽/1.8倍文字的离线真实组件截图均通过，已打开检查：同卡布局、换行正确，无横向溢出，小屏大字体使用滚动。不是新测量/云端验收。已请用户进入帮助页作真机核对；截至本段记录尚未取得该页实拍，不能用其他页面截图替代。

最新analyzer零问题2.9s，既有定向global_ring_privacy/client_review_regressions/global_legal_page共67通过；UTC/Asia-Shanghai全量各1151通过（39s/30s）。格式10文件0改变，git diff --check通过。继续复用现有测试和opt-in截图入口，没有为这次可逆布局新增镜像实现测试。

执行命令（原始输出在受限临时目录，不含入Git的会话/健康库）：

```sh
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub --reporter=expanded test/global_ring_privacy_test.dart test/client_review_regressions_test.dart test/global_legal_page_test.dart
TZ=UTC flutter --no-version-check test --no-pub --reporter=expanded
TZ=Asia/Shanghai flutter --no-version-check test --no-pub --reporter=expanded
flutter --no-version-check test --no-pub --reporter=expanded test/support/ios_inner_page_capture.dart --dart-define=IOS_REFERENCE_OUTPUT=build/us-storage-notices-20261104/help-unified --dart-define=IOS_REFERENCE_PAGE=global-connection-help
flutter --no-version-check test --no-pub --reporter=expanded test/support/ios_inner_page_capture.dart --dart-define=IOS_REFERENCE_OUTPUT=build/us-storage-notices-20261104/help-unified-narrow --dart-define=IOS_REFERENCE_PAGE=global-connection-help --dart-define=IOS_REFERENCE_WIDTH=320 --dart-define=IOS_REFERENCE_HEIGHT=800 --dart-define=IOS_REFERENCE_TEXT_SCALE=1.8
dart format --output=none --set-exit-if-changed lib/ui/data_privacy_page.dart lib/ui/device_pages.dart lib/l10n/generated
git diff --check
```

最新两端重建完成：Android Play Debug32.2s、QA Release33.1s；iOS串行Profile无签名45.7s、开发签名Debug23.7s，均退出0。QA APK为内部测试签名，不上传商店。沿用此前供应商SwiftPM/模拟器arm64、Kotlin未来迁移提示，无新编译错误。构建不另装手机，手机运行的是本轮已热重载的标准run进程；最终getVM/main仍成功。build ios生成的TRACK_WIDGET_CREATION=false不同于当前run的true；后续调试如再需完整编译/重载，使用标准flutter run对齐参数，避免重复此前手工混用产物的异常。

构建使用相同美国API/update defines、空JPUSH_APP_KEY、SAIDIAN_DISABLE_REMOTE_PUSH=true；Android另设JPUSH_VENDOR_CHANNELS=none、双ARM及SAIDIAN_PLAY_STORE=true，QA Release显式SAIDIAN_ALLOW_QA_RELEASE=true。执行顺序为：

```sh
flutter --no-version-check build apk --debug --no-pub --flavor play --target-platform android-arm,android-arm64 --dart-define=SAIDIAN_PLAY_STORE=true --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=JPUSH_APP_KEY=
SAIDIAN_ALLOW_QA_RELEASE=true flutter --no-version-check build apk --release --no-pub --flavor play --target-platform android-arm,android-arm64 --dart-define=SAIDIAN_PLAY_STORE=true --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=JPUSH_APP_KEY=
flutter --no-version-check build ios --profile --no-pub --no-codesign --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
flutter --no-version-check build ios --debug --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=
```

上述iOS命令均使用受限目录既有XCODE_XCCONFIG_FILE的iOS15/开发团队配置，没有分发证书或App Store上传。本轮隐私正文和已发布r4未变，不触发新的法律版本。

用户随后确认已打开Connection help；再次采集精确手机实拍并打开核对，真实英文页面已是一张完整圆角卡：连接步骤、分隔线、美国存储说明及Data privacy入口均在卡内，文字未裁切。文件位于忽略目录build/us-storage-notices-20261104/iphone-connection-help-final.png。该证据关闭前述帮助页显示待核对项，不代表新增测量或隐私入口点击已经真机验收。

最终文档补记脚本出现输入编码SyntaxError，shell未设置set-e仍创建了含先前记录的本地8540dd2提交；没有源码丢失。改用apply_patch补齐本段构建/真机结果，单独保留后续文档提交，不重写既有本地历史。后续关联命令统一要求失败即停。

## 收口交付

本机最终159e9d24466fb04b9d7d6df2b8ba13b158857fcd通过GitHub连接发布为0002cd743001a63235eac1fc2b27e039b56ac8bd，完整tree a31cdeb7ab3c31c203db88988d334f6ce52ecbbf一致。fetch/full-tree diff通过，本机跟踪同名规范远端，原本机历史保留codex/us-storage-notices-unified-local-20261104；没有main合并、force push或商店操作。最新源码CI41776718607已排队，交付时未完成；不以较早源码748aaaae的CI替代。此前41774487076最后观察质量、iOS和两时区主机契约通过，Android仍运行，不能写成全部通过。本段仅记录交付，跳过重复CI。

交付收尾一次getVM请求5秒超时；当前run进程仍在，无新增异常/断连日志，手机未锁定。仅将精确国际版App恢复前台后，同一getVM立即返回VM/main成功，没有重新安装、清数据或重启设备。因此该次超时不计为崩溃，也不以超时结果声称连接正常；实际恢复回执另记在此。

后续用户要求检查CI并构建上传苹果新版时已实读：41776718607及41774487076均completed/success；最新源码41776718607的质量、Android、iOS和两时区Harmony contracts五job逐一success。前述排队/运行中状态已被这次实际结果更新。后续正式1023构建/上传独立记录于IMPLEMENTATION-20261104-IOS-1023-UPLOAD.md。
