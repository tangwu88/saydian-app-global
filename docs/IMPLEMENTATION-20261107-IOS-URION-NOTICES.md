# 2026-11-07 iOS Urion通知修复及新一轮设备验收

起点765d7cb，国际分支codex/us-storage-notices-20261104干净；origin fetch/ff-only再次核对通过。用户要求继续新数据美国上云/动态血压测试，全面检查后提交苹果审核。本轮继续可独立执行的修复、回归、构建和上传准备，未把“本轮暂时无法测量”解释成跳过核心验收并立即正式送审的授权。

## 修改前问题、范围及原反例

P1：iOS已允许U19脉搏与健康监测，但UrionWearableBridge._onNativeEvent仍保留旧过滤，直接丢弃0x37设置变更和0x73(5)脉搏完成通知。预期应更新当前设备的动态血压状态，并在真实脉搏完成通知后正常读取/结束当前会话；实际二者均无事件，脉搏会话可能一直等待。只涉及当前已连接Urion桥接，其他设备、会话代次、原始时间/数值、云指标和关爱范围不扩展。

先仅增加普通测试，再跑iOS定向原反例：原有只读发现测试通过，新增两项均失败（No element / Expected mock event was not delivered），日志ios-notices-before-fix.log。随后仅修改lib/services/urion_wearable_bridge.dart的旧通知过滤，允许0x37及0x73(5)进入现有处理，继续过滤未开放的0x73(4/6)。没有增加启动测量、写监测或云上传动作。

test/urion_wearable_bridge_session_test.dart新增两项同时验证错误设备及过期generation不能更新状态、有效设置通知不回写手表、脉搏新结果可以结束会话并再次开始、脉搏指数不成为普通健康云记录、原未开放通知仍不触发同步。两项原失败断言保留。一次apply_patch因格式化后上下文不匹配被拒绝，检查确认未部分写入后按实际上下文重试；没有覆盖其他文件。

格式化两文件无额外差异；修复后Urion会话、iOS本机范围、脉搏历史和iOS策略共52项通过。全量、构建及本次源码CI结果继续追加，旧31bfda1的绿色CI不能代表此新修改已通过。

## 调试恢复、数据来源及本轮实际设备

原/private/tmp受限会话文件已不可用，未假装复用旧VM或旧截图。本轮新证据位于已被Git忽略的build/private-qa/u19-20261107-r2，目录0700，健康原值/账号/令牌不进Git。华为PPA-LX3仍正常安装1.0.2（1025），原App PID32537，但电脑侧Flutter会话已结束。无日志服务公告；只读/proc/net/tcp遭Permission denied，未提高权限或尝试绕过；普通attach等待，主动停止该未连接的宿主命令，未删手机数据。

重启现有App前备份app_flutter/files/shared_prefs，停止App后再生成一致快照，两份各103650304bytes、13文件/1数据库、SHA256完全相同。没有卸载、重新签名或清空手机。重新启动原1025后实际新VM main/PID11781已确认，使用设备原生URL恢复单个attach。一次attach误用不支持的--flavor退出64，移除该选项后成功；保留原Play/.com/空JPUSH编译参数。直接启动现有Android Debug后恢复附加不代表iOS独立Debug冷启。

首页虽出现读数，实际连接是SD-WATCH-E8（Veepoo），本机59条为旧历史，不能作为U19新测量。首轮辅助汇总误用HealthRecord的metric键（实际toJson键为type），已修正；云端时间字段实际为observedAt，按正确字段重新核对仍无旧基线后新增，最新为07:40Z，HTTP200。辅助错误和修正保留，不修改原数据或据此作服务器故障结论。

用户回报连接U19S后，运行实读却为U19M_ZX_00B8；经明确询问，用户授权“本轮改测当前U19M_ZX_00B8”。后续必须按U19M单独记录，原U19S末尾27:65的无完成通知/无新增历史问题仍未解决。U19M初读历史9条、动态计划关闭、开始0、日30/夜45，仅读取未修改。用户随后明确“本轮暂时无法测量”，因此未自动启动新血压、未改时间、未启用定时充气，U19M新采集/云首ACK/内容回读/真实定时执行均待验。旧E8记录与U19历史、脉搏指数分开，不以界面有数值代替指定设备验收。

## 后续发布门禁

本次实际代码修改需全部本地门禁及新CI通过，并采用高于已上传1025的新构建（默认1026）。当前仅有Development身份，没有可用Distribution身份；先完成具体构建再处理实际导出/上传回执，不以旧1025 IPA代替新源码。新测量及定时测试未通过前保留验收限制，原1023审核关联不提前移除。本轮未重新创建审核凭据、接受新合同或改变发布方式。

## 本地最终回归及四项构建

最终analyzer无问题，UTC全量1164项/上海时区全量1164项均退出0，原AUD安全测试继续在普通回归中；发布Python25项通过，Swift固定范围测试编译/运行通过。第一次定向原反例1通过/2失败，修正后相关52通过，未删除或弱化正确断言。其他未修改的Node检查交由本次CI独立执行，不写成本机通过。

按正常main/.com/无远程推送，CLI指定1.0.2（1026），串行完成Android Play Debug30.5秒、明确QA Release84.7秒、iOS无签名Debug37.3秒/Profile48.0秒，全部退出0。Android两份实际APK包名/版本、双ARM ABI、签名验证通过，Debug可调试/QA Release不可调试；QA包不用于Google商店。iOS两份实际Info.plist包名/版本通过，无签名编译不是发行签名或真机运行。产物与逐项摘要保存在build/store-upload-20261107-1026/regression及私有证据目录。

四项构建没有并发iOS编译、清理共享DerivedData或操作手机原数据；沿用已存在的Xcode27/最低iOS15临时构建配置。保留原厂模拟器arm64、Kotlin及SDK XML版本提示，它们未阻断实际手机架构构建。未找到的verify_ipa.py路径是工具定位错误，改为核对现有工具和实际产物，没有伪造该脚本通过。

实时App Store Connect仍为国际版1.0.2等待审核（原提交ID不变）；旧链接失效后按实际tab1重新绑定。GitHub连接只列PR事件，改从已登录Actions网页取得本次push流程，再使用连接读取五job。当前准备发布新源码并核对其新CI，通过后才开始1026正式归档/发行导出；不能以765d7cb文档提交或31bfda1旧CI代替新源码结果。

## 新源码CI通过、美国旧历史逐条回读及审核资料

源码已通过GitHub连接发布为a30c6a581e09f828c908b9498c55c992cc191c7a，完整tree3fffdaf9227ec58b13ef96d66e0122fc2b62c497与本机一致；本地同树提交cc42406保留在codex/urion-ios-notices-local-20261107，当前国际分支跟踪远端，没有强推/重置/合国内main。新CI[42372007896](https://github.com/tangwu88/saydian-app-global/actions/runs/42372007896)实际五job全部completed/success，于2026-11-07 20:45:47（Asia/Shanghai）回读确认，之后才开始正式归档。iOS包括Debug/Profile/Release及RunnerTests编译，Android包括三个渠道构建、ABI/推送和双渠道原生测试；不是实体SDK/测量验收。

手机实际使用纽约时区，额外TZ=America/New_York的Urion协议/会话/历史43项通过。安卓正常1025调试会话热重载9/2226库、2691ms通过，运行API根仍https://app.saydian.com、当前U19M通道正确，计划保持Off、原30/45未改。U19M实读硬件U19_V1.0、固件9.01.105C1；不与原U19S的U19_V3.0验收混用。没有手动调整手机时间或人为快进设备以触发监测；正常连接/同步流程的协议对时保持原实现。

本机59条E8旧历史的ID，在当前同账号美国服务最近200条中全部找到；逐条数值、单位、observedAt/原measuredAt瞬时均一致，当前pending0、云complete、本次上传计数0。此证据证明这批旧历史可在美国服务回读，不证明本轮U19M新采集、首ACK或定时触发。observedAt早于基线仅说明不是基线后的新采样，不能据此断言期间没有旧历史上传；原临时云基线文件缺失，不能凭记忆重造ID差集。

美国公开auth/capabilities为global/en、registration.verificationRequired=false、consentVersion=r4；按其返回路径映射至/global后，两份英文法律文档均200、reviewed=true、active=true、版本global-appstore-2026-11-04-r4，正文无中文且保留美国存储说明，未修改或重新发布法律正文。独立保护的审核账号仍未在本轮重新密码登录，不能用当前物理测试账号profile200替代。

商店实际英语（美国）的“App预览和截屏”面板仍保存global-dashboard/global-device/global-privacy三张英文图，已目视核对设备通用/美国存储、无真实健康值或旧的云端仅活动睡眠表述。最初看到的空“标题和搜索结果”是可选新创意区域，不是截图丢失；通过实际下拉切回正确面板核对。当前发布方式仍AFTER_APPROVAL自动，未擅自改变。新英文[1026审核资料草稿](release/STORES-1026-20261107-DRAFT.json)已整理，3156字符、未写入商店，保留真实硬件/审核账号未验项。

## 1026归档完成，发行导出被Xcode账户阻断

CI全绿后，以正常main/.com/空JPUSH、production=true/QA=false及1.0.2（1026）正式归档。保留并移动旧默认archive/ipa至1026的preserved-default-*，没有删除旧正式包或缓存。实际Xcode27.2（27B52），xcode-select为/Applications/Xcode.app/Contents/Developer，无DEVELOPER_DIR覆盖；不是另一套27.1工具链。

归档40.8秒/257.1MB完成，整次Flutter命令47.7秒，开发签名严格deep/strict核验通过、正确包名/版本，新App.framework的代码及UUID与1025不同；产物在build/store-upload-20261107-1026/Runner.xcarchive。归档仍为Development签名，不是商店发行包。

发行导出640ms返回多项error: exportArchive No Accounts，没有生成IPA。Flutter命令本身却退出0，已依实际产物及签名门禁正确判定“导出失败/未上传”，没有据exit0宣布成功。本机Flutter导出实现已包含allowProvisioningUpdates，不能靠重复相同命令解决缺账户。登录后可直接复用此隔离归档重新导出，无需重编译。

本轮私有发行核验脚本先在旧1025已验证包上校对：初版只接受thin Mach-O，遇App.framework的单arm64 fat容器失败；按实际fat头/边界补齐后，旧1025发行签名、entitlements、UUID及全部有内容section比较通过。它不是1026已通过发行核验的证明；1026须在实际IPA生成后独立跑同样检查。

尝试打开Xcode账户页时bundle ID命中两套Xcode，按实际xcode-select改选/Applications/Xcode.app，随后工具明确“Mac已锁屏且自动解锁失败”。已请求用户解锁并在本次Xcode27.2的Apple Accounts登录/完成二次验证，未绕过锁屏、重置账户/证书、提取网页凭据或把网页登录当Xcode登录。原审核仍1023等待，1026没有上传或正式送审，正在等待账户操作。后续成功回执追加，保留此次No Accounts失败历史。
