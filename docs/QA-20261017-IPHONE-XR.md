# 2026-10-17 国际版 iPhone XR 全面测试

> 真机数据保护：所有 `flutter drive` 必须同时传 `--no-uninstall-first --keep-app-running`。仅前者不能阻止测试结束后的默认卸载。不得把0文件的比较当成数据保留通过。测试结束须覆盖恢复正常Profile，先核对非空数据库备份，所有错误须立即停止写入链。

## 范围与现场

用户明确要求安装到另一台苹果手机并全面测试。起始clean HEAD4cc2d72090554da8d0ea060bd1640d7d33e14df2；fetch成功，ff-only pull因当前新分支无tracking而拒绝，未合并/覆盖其他分支。阅读AGENTS、当前交接、最新U19S变更、复盘及回归检查。目标已明确识别为iPhone XR / iOS18.7.10 / USB wired / Developer Mode enabled；原15 Pro Max不可用，不操作它。XR安装列表没有国际版App，因此没有可导出的既有国际版容器；不复制其他设备账号、Keychain或数据库。

## 已执行

- 复用当前1019正常Profile包build/ios-ui-notice-move-1019/Profile-Runner.app，实际bundle cn.saydian.app.global / 1.0.1(1019) / minimum15.0，embedded.mobileprovision包含本XR，strict/deep签名检查通过。
- devicectl install及正常process launch成功；安装路径和运行进程匹配，正常Profile可独立启动。私有设备/安装/启动日志保存在/private/tmp/saydian-xr-qa-20261017，不输出凭据或健康记录。
- 需要XR现有用户会话和附近蓝牙设备才能完成登录态/硬件验收，已请用户仅在手机输入账号密码，并选择本轮设备。不复制上一台会话、不用审核账号存用户健康数据。

## QA方案

修正既有全页QA的过时英文定位及1019本机显示策略，并提供单独XR只读页面入口；原真实硬件首ACK/新步数门禁继续保留独立执行，不能因页面通过声称同步通过。XR页面检查使用生产控制器/既有手机会话，核对首页无额外提示、远程关爱底部、数据/趋势/设备/个人设置/权限/支持/隐私政策和协议。账号删除、对外发送反馈、OTA/表盘写入及医学准确性不由页面遍历触发。测试完成恢复正常Profile包，测试专用入口不作为交付包。

后续实际命令、失败、截图和未完成项在本文件追加，静态/主机夹具与真实手机结果分别记录。


## 实际验证与失败保留

- 用户确认XR已登录，选择U19S。首次正常Profile进程独立存活，XR系统当日Runner崩溃报告0。备份XR登录后的Documents/Application Support成功；Preferences复制报目标缺失，随后列目录确认为0文件，不假称已导出偏好或Keychain。
- 新只读页面Profile QA构建43.1s、签名通过，drive安装启动23.7s；真实既有手机会话通过，页面用例2:55成功，保存18张独立截图（单位页重复名称覆盖为同一张）。覆盖首页/通知/远程关爱/百科空态/全部数据/未连接设备/连接帮助/资料入口及编辑/单位/账号/权限/反馈/客服/关于/英文协议及隐私/语言。首次没有连接设备，因此没有血压等已连接页或同步验收。
- 目视18张联系表：首页新提示消失、布局无明显截断；英文百科为空，不当作正文阅读通过。隐私截图仍是加载状态，初版测试对正文就绪门禁不足，已补global-legal-body等待/断言，并补Data privacy页面、当前英文查找设备入口定位；准备第二轮真实测试。
- 主机414×896、1.3字级的离线global五页面截图通过；此为夹具布局验证，不替代XR实际截图或登录/蓝牙。系统Python没有Pillow，改用已有内置Python生成联系表，未安装软件。
- 美国公共只读smoke：readiness/数据库、国际注册能力、匿名会员401、英文已审核同版本协议/隐私全部通过；未由此声称登录或OTP完成。登录由XR实际会话证明。
- 发现旧硬件QA把携带手机token的回读地址写为.cn，运行该阶段前已改为.com；本轮没有向国内地址发送该回读请求。同步测试按1019设备本机范围修正能力断言，仍严格保留活动/睡眠云端范围、旧记录/待传保留、真实新样本首ACK/原值回读/当天步数增长及replay去重门禁，不通过则退出失败。支持的物理测量不由该同步脚本自动发起。
- 硬件QA首次r2 analyzer发现nullable manualMetrics.every，补空集合处理后零问题；首个Profile构建9.6s失败，Flutter只输出通用签名提示，未据此要求重新登录；类型修正后r3 Profile22.0s构建及签名成功。
- 首次硬件实机安装21.9s，但dailySummaryVersions=false导致测试1秒失败；因实现catch不保留内部原因，不能断言服务器不支持或已损坏。r4补固定HTTP阶段/异常类型诊断、保留true门禁，并把最终门禁放到蓝牙诊断之后；Profile21.1s构建/签名、安装21.3s通过。
- r4实际能力请求两次HTTP200、dailySummaryVersions=true，之前false未复现；不能称因QA诊断修复服务端。继续扫描后未找到唯一指定U19S，约30s测试失败，未进入新步数窗口/ACK/回读/去重。不把扫描失败解释为硬件协议失败。扫描SDK输出了附近设备原始广告日志，仅保存在私有目录；作为供应商日志隐私待核查项，不纳入Git。
- 已恢复最新正常Profile并独立启动，方便用户断开原手机并在XR手动连接U19S；当前运行路径与正常Profile一致，系统当日Runner报告仍0。等待用户连接确认后继续硬件及已连接页面第二轮。尚未执行的同步/物理测量/长期稳定性均不写通过。
- 默认driver另外写入build/integration_response_data.json，已把本轮53MB原始截图报告移至私有/tmp并设0600；后续驱动设置FLUTTER_TEST_OUTPUTS_DIR避免再落入仓库构建目录。完整健康截图/账号字段/广告标识/VM地址不入Git。

- QA脚本最终静态分析零问题，UTC/Asia-Shanghai完整主机回归各1110通过（17s/20s）。产品lib/ios/android/pubspec无变化，沿用本日已通过的Android Debug/QA Release、iOS Debug/Profile产品矩阵；新增两种真实QA入口另有签名Profile构建及设备执行证据。不把只改测试再跑主机矩阵写成硬件通过。
- 第二轮全页QA Profile已构建并保存build/ios-xr-page-qa-r2-1019/Runner.app（包含隐私正文等待、Data privacy和当前Search for devices定位），尚未执行，等U19S在正常App连接后一起复测已连接入口及关爱底部。
- SDK原始广告日志排查：应用调用Yucheng初始化已经logEnabled=false；现有插件会设置YCProduct .off/saveLevel .off。因此不能简单通过打开/关闭App开关解决本轮原始扫描输出，需要厂商SDK来源继续核查，本轮未修改pub缓存或全局日志重定向。


## 用户确认XR已连接后的接续

起始clean f6df37c，fetch成功。备份已连接后的Documents/Application Support，再覆盖同一已签名r4 QA，安装23.6s。美国能力实际两次HTTP200/true，但38s后再次因没有唯一U19S候选而失败，尚未完成连接恢复或同步；不否认用户在正常App连接成功，也不以该回报替代测试进程握手。调整仅QA：读取已保存绑定是否存在/transport及扫描是否看到目标的布尔诊断，不导出标识；如果无法自动连接，停在真实设备连接页等待用户，不选择其他设备或注入假连接。XR采集窗口180s，默认其他入口仍120s；只延长真实步行收集时间，保留所有首ACK/新步数/回读门禁。


r5 QA构建27.3s/安装22.5s；初次analyzer多余material导入提示，去除后零问题。实读绑定exists=true/transport=urion，排除“未保存绑定”的简单推断；扫描targetMatches=0且savedTargetSeen=false。XR请求出现_ClientSocketException，直接固定.com探测亦同异常，故每日汇总false不能据此判为服务端不支持。同期Mac公共smoke全部HTTP200/匿名401，服务可从Mac访问，不代替XR网络。r5进入人工等待，发现Flutter LiveTest binding默认shouldPropagateDevicePointerEvents=false，测试页人工点击可能被丢弃；已主动停止本轮，不计App失败/通过。仅QA修正：人工等待scope内启用真实触摸，finally还原；连接后重查真实HTTP能力，保留先前离线结果及所有ACK/新步数门禁，不把初始网络快照当后来状态。


r6 QA人工触摸修正后analyzer零问题、Profile21.2s构建/strict签名通过、安装22.3s。绑定仍exists=true/urion，但扫描targetMatches=0/savedTargetSeen=false，进入真正允许人工点选的五分钟等待。HTTP异常进一步记录osCode=8；本机iPhoneOS SDK netdb.h明确EAI_NONAME=8（主机名/服务名未知），表明XR当次域名解析失败。Cloudflare及Google两处公共DoH实查app.saydian.com均Status0/A47.85.43.52，私有public-dns.json留存；Mac同时readiness/能力/两份已审核法律正文200、匿名会员401。公共解析正常不等于XR DNS已经恢复，已告知用户切换可用网络。没有改App为IP访问、绕开TLS、回退国内或伪造同步成功。r6连接/云端结果仍须实际等待和核对。


## r6等待结束、工具清理纠正与数据恢复

- r6真实人工接入等待5分钟结束，05:25退出1；仍未取得当前测试会话连接，未进入新步数窗口/SDK首ACK/服务器回读/重复同步。不得写成“XR连接后全面通过”。真实触摸开关finally已还原。
- 随后恢复前发现Global App已不在安装列表，容器读取ContainerLookupError；查Flutter tools实际drive_service.dart:stop，默认停止后会uninstallApp。此前只设置no-uninstall-first，漏掉keep-app-running，是本轮测试操作疏漏，已向用户说明；不是用户主动删除或App自身丢数据。后续所有私有drive启动器已增加keep-app-running，安全命令作为本记录首行门禁。
- 首次“当前安装前/后”复制失败导致比较得到0文件/0bytes/identical=true，这是无效比较；原始失败记录final-install-data-proof.json保留，不计通过。
- 正常Profile已重新安装。只按本应用安装URL匹配并终止自身进程，随后把本轮测试前已保存的Documents-u19s-connected与ApplicationSupport-u19s-connected逐文件复制回原路径，没有导出或替换Keychain，没有改其他App。再从手机重新导出比对：2个备份文件合计70,187bytes逐字节一致（其中数据库69,632bytes），非空valid=true。证明为恢复文件一致，不冒称恢复后全部历史已在界面逐条验收。
- 正常1.0.1(1019)已再次独立启动，实际Profile安装URL与进程匹配；XR当日Runner崩溃报告仍0。已退出自动测试，不留下会被后续默认清理卸载的测试会话。
- 恢复依据及恢复核对副本另存本机0700目录 /Users/saydian/.local/share/saydian-private-qa-backups/20261017-iphone-xr，文件0600；原始临时失败/截图/广告日志仍在私有/tmp。不把恢复备份或钥匙串数据纳入Git。
- 当前未解决边界：XR DNS EAI_NONAME(8)及测试重启后的设备接入；隐私正文、U19S三项本机入口/实际新测量、活动睡眠首ACK/回读/去重均未完成最终通过。已告知用户先恢复XR可用网络并在正常App中重连。产品源码、服务器和1018商店审核本轮均未修改。


## 网络恢复后的实测与全页测试定位修正

起始clean df94acc49aab53d444243de3ca2d04f693c6e955，fetch成功；当前分支没有tracking，ff-only pull仍拒绝，未合并其他分支。用户确认当前页连接、网络正常，先重新导出当前Documents/Application Support：2文件70,742bytes，并保存独立私有备份；后续drive均显式no-uninstall-first及keep-app-running。

- 第二轮页面QA r2首次安装24.9s，driver在首张截图前报Service has disappeared退出1。App仍在安装列表且其实际进程仍存活；系统Runner搜索仅旧BackgroundShortcutRunner报告，无本轮App崩溃证据。不据调试服务丢失认定App崩溃，也不计通过。
- 复用r6硬件QA安装21.9s，当前真实手机会话初始化成功；美国能力多次实际HTTP200/dailySummaryVersions=true，保存绑定urion且本轮恢复真实Urion连接并通过能力门禁，未再触发人工连接等待。此前DNS问题当次未复现，不把它写成永久修复。
- 3分钟真实采集窗口已提示用户佩戴走动；尚未收到走动完成回报。基线currentDayStepsAvailable=false；第一次同步调用成功返回，但state=idle、allowedPending=0、accepted=0、rejected=0，healthRecords为空，03:36测试因Actual activity/sleep samples required退出1。没有样本可确认，不推断服务器拒绝、首ACK通过或当天步数增长；后续回读/去重未执行。
- 页面r2第二次安装21.3s，取得29张私有真实截图：首页无原位置本机提示、关爱底部提示存在、心率/血压/血氧详情、步数/睡眠详情和历史、连接的U19S设备信息/显示/设置、资料/权限/支持/关于、英文隐私及服务协议正文均实际覆盖。截图显示空指标为--，不伪造读数。两份正文实际已加载，非加载占位。
- 全页用例04:28退出1：About保留向下滚动位置，Data privacy位于懒构建头部，被find.text直接断言为0。截图证实入口存在；定位测试缺陷P2，不当成产品缺入口。仅integration_test/ios_full_page_qa_test.dart改用稳定data-privacy-link Key，先向上scrollUntilVisible再真实tap，保留正文/页面/异常门禁。产品lib/ios/android/pubspec未改，继续复用此前当日完整产品构建矩阵；测试入口重新构建、实机执行和主机回归在后续补记。


## r3最终页面通过与正常包交付核对

- 仅QA修改完成后，dart format（0变更）、flutter analyze --no-pub（零问题）通过；UTC与Asia/Shanghai各完整1110项测试通过。产品源码、原生配置及版本号未变，Android Debug/QA Release、iOS Debug/Profile产品矩阵沿用同日已记录结果，不重复声称本轮重新构建安卓产品。
- 新入口以 `flutter --no-version-check build ios --profile --no-pub --target=integration_test/ios_xr_page_qa_test.dart --build-name=1.0.1 --build-number=1019 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=` 构建，私有Xcode27 xcconfig与SAIDIAN_DISABLE_REMOTE_PUSH=true不变；Xcode25.2s，签名验证通过，缓存build/ios-xr-page-qa-r3-1019/Runner.app。
- r3实际执行 `flutter --no-version-check drive --profile --no-pub --no-uninstall-first --keep-app-running --target=integration_test/ios_xr_page_qa_test.dart --driver=test_driver/ios_full_page_qa_test.dart --use-application-binary=build/ios-xr-page-qa-r3-1019/Runner.app -d <XR-UDID> --device-connection=attached`，.com/禁推送及私有截图/报告环境与前述保持一致；安装24.3s，用例04:54退出0。31张独立PNG保存于私有screenshots-r3（单位页同名覆盖），原先失败轮的29张单独保留。
- 真实截图抽查：首页保留三项Urion本机指标，原位置长提示不存在；Family care末尾本机提示存在；三项详情Measure now入口/无记录空态正常；设备页真实Connected；英文隐私及协议正文已加载；Data privacy包含美国云存储、本机及选择说明；语言选择English已选。未观察到本轮所查页面裁切/异常，不据截图空态推定测量采集完成。
- 测试结束keep-app-running生效，App与容器仍在。按当前安装URL精确终止本App后导出数据，覆盖正常Profile后、首次启动前再次导出核对：2文件71,482bytes非空且逐字节一致。证据r3-normal-data-proof.json；当前数据另存私有持久备份r3-before-normal-data，不回滚到更早备份。
- 恢复工具首次launch把--device放在bundle之后，被解析为App参数导致缺少device错误，未启动；更正为 `xcrun devicectl device process launch --device <XR-UDID> cn.saydian.app.global` 后成功。正常1.0.1(1019)已独立运行，实际安装为Profile-Runner.app，精确匹配自身运行进程1个。系统Runner报告仅2025年的BackgroundShortcutRunner记录，本轮Runner崩溃报告0。
- 本轮产品/服务器/商店未修改；只提交QA滚动修正和测试交接记录。保留本地提交，未取得远端推送或CI新回执。用户已收到正常App内走动同步及分别实际测量的提示，结果待回报；不得把31页通过写成全面硬件验收。

### 当前剩余验收边界

1. U19S真实活动/睡眠样本、当天步数增长、新样本首ACK、服务器原内容回读、重复同步去重仍未通过；最近硬件轮无样本且未收到走动完成回报。
2. 血压/心率/血氧实际新测量、重启后持久显示及测量失败/取消场景未验证；当前只证明真实设备能力、入口和空态。
3. LuckRing/QRing不属于这台XR本轮指定设备，不能继承U19S通过；长期后台/弱网/耗电和传感器准确性均未由这次页面遍历证明。
4. 注册新账号、删除账号、发送反馈、OTA/表盘写入及第三方交付未由只读遍历执行；不自动删除用户账号或改写设备固件。


## 用户回报实际读数后的独立既有记录核查

起始clean 1dc42144e2cdf67e35c5790eaa87f5b2277a758c，fetch成功，当前分支无tracking的pull拒绝仍保留。用户明确暂时无法走动，同时回报正常XR步数和三项测量均显示；这是用户实测回报，不覆盖此前自动用例无样本的历史结果，也不计当天步数增长。仅新增integration_test/ios_xr_existing_records_qa_test.dart及共享QA内的独立既有记录用例，不更改原新样本门禁。目的：重启后以现有手机账号解密核对四项真实正值记录、活动/睡眠实际内容回读与原记录replay ACK/ID去重，并核对本机生理记录/待传未变。禁自动恢复蓝牙，不再次发起测量或要求走动；不插入假样本，不改产品/API/商店。真实执行及失败会追加。

- 首轮既有记录QA：format通过、analyzer零问题，签名Profile构建15.6s/签名通过；最新测量回报后的XR数据先备份2文件71,667bytes，不覆盖旧备份。实际安装26.8s，用例00:09失败：steps present=false，尚未遍历三项生理数据/回读/replay。UTC和Shanghai各1110通过。该失败仅证明当前测试账号下步数正值条件未满足，不据此认定用户说谎、数据丢失或产品缺陷。已请求澄清具体数值/占位/另一手机；QA补按指标输出无敏感值的存在布尔和记录数、独立只读服务器数量，再执行同样存在门禁，避免首项缺失掩盖其余结果。不放宽验收条件，不输出账号/记录ID/数值。

- r2诊断版format通过、analyzer零问题，Profile13.5s/签名通过，安装24.2s，00:11退出1。当前XR账号原始本机recent为0，steps/blood_pressure/heart_rate/blood_oxygen各matchingRecords=0；因此不是只因source或正值条件筛掉已有行。独立实际美国GET回读82条活动/睡眠记录，指标过滤、分页完整及无重复ID断言通过；因本机0条，不能比对本机原值或执行选定原记录replay，未进行该replay写入，也未声称新样本ACK。用户界面回报与本机持久化核对目前不一致，等待对具体数值/占位/另一手机的澄清，不擅自更改产品或合并其他账号数据。
- 最终QA源码完整UTC/Asia-Shanghai各1110通过；既有记录测试本身如实失败。lib/ios/android/pubspec未改，沿用本日产品构建及31张全页通过结果；新增两个诊断版本有实际Profile构建/安装证据，不能以主机回归代替实机失败。
- keep-app-running生效，没有卸载。当前QA结束到正常Profile覆盖前后2文件72,037bytes非空逐字节一致；更正后的启动参数顺序首次即成功，正常Profile独立进程1个，本轮Runner崩溃报告0。另把用户回报后、QA前的ApplicationSupport与QA后文件比对：1个加密数据库字节完全一致（existing-qa-db-preservation.json），说明这两轮QA未改变该库。不能由此证明其内部原本就有四项读数；不把当前账号0条查询当数据验收。当前最新数据私有备份另存existing-before-normal-data；没有恢复旧库、导出Keychain、操作原15PM或改商店。
- 当前状态：U19S/31张页面通过及用户回报均记录保留；用户暂不能走动，增长门禁未执行。现有四项本机持久化尚未验收，美国活动/睡眠历史可读，内容匹配/本轮replay/新SDK首ACK仍未完成。等待澄清后再定位，不依据单一回报推断整套通过或丢数据。
