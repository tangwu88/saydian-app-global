# 修改与测试记录索引

本文件是项目长期执行约定。每位同事开始修改前必须先同步 `origin/main`，再阅读最近记录；每组修改和每次验证都写入对应日期的实施记录，并随源码一同提交。

## 执行顺序

1. 检查分支、工作树、本地与远端提交号；工作树不干净时只做安全合并，不覆盖既有修改。
2. 阅读最近实施记录中的已完成项、失败方法、待验证项和真机边界。
3. 记录本次修改原因、文件、影响范围和预期结果后再实施。
4. 逐次记录格式化、静态检查、自动测试、构建、安装、真机流程和日志检查结果。
5. 失败记录保留，并补充根因与最终修复；交付时提交记录并核对远端提交号。

## 最近记录

- [2026-10-03 Health 易用性优化](IMPLEMENTATION-LOG-20261003-USABILITY.md) — W8 ECG、充电状态刷新、关爱概览与私有波形读取、八语言短文案；995 项测试与静态分析通过，Android Debug／内部 QA Release 构建通过；上线和新版真机验收单独记录。

- [2026-10-03 手机天气开发记录](IMPLEMENTATION-LOG-20261003-WEATHER-CONFIGURATION.md) — 手机预报入口、第一方缓存接口、网络定位及显式城市查询已完成代码和 Android 构建验证；977 项回归通过，Debug 已覆盖安装。用户要求先忽略天气，真实预报页面验收和手表同步保持未验证。

- [2026-10-03 W8 手表自主测量同步](IMPLEMENTATION-LOG-20261003-W8-WATCH-SYNC.md) — 补上手表测量完成通知至历史读取/上传的触发，已确认记录重复同步后保留成功状态；966 项回归与静态分析通过，新心率记录无须点击同步即进入 App 和服务端，最终 Android Debug 覆盖安装与调试恢复。

- [2026-10-03 W9 完整心电波形上传](IMPLEMENTATION-LOG-20261003-W9-ECG-CLOUD.md) — 接通全量 gzip 波形文件与健康记录关联，上传凭据持久化后提交，保留未确认数据；963 项回归与静态分析通过。私有对象存储已配置，真机 17,498 点 / 500 Hz ECG 文件读回、哈希、健康记录 ACK 和待传队列均已验收。

- [2026-10-03 Google Play 准备与单位申请](IMPLEMENTATION-LOG-20261003-GOOGLE-PLAY-READINESS.md) — D&B 香港网站确认收件但尚无 D-U-N-S；Google Play 单位注册到支付资料步骤。客户端 Play/侧载渠道隔离、独立上传签名和审核素材已准备，双时区各 953 项通过；Android 产物及网站送审仍待完成。
- [2026-10-02 全 App 真机逐页复测与手表同步闭环](IMPLEMENTATION-LOG-20261002-IOS-FULL-QA-HEALTH-SYNC.md) — iPhone 15 Pro Max 真机逐页驱动通过并生成 36 张截图（访客预览态）；旧会话待上传记录触发 401，退出后等待用户确认协议再恢复账号。真实测量、服务端 ACK 与连接演示视频尚未完成；最终 Debug 重连因 Mac 锁屏/Xcode 自动化授权及 VM 未发现而中止。
- [2026-10-02 手表血压同步、30 分钟补传与 Health 顶栏头像](IMPLEMENTATION-LOG-20261002-WATCH-SYNC-HEADER.md) — 修复 U19 手表端血压历史识别、前台周期补传/ACK 去重与顶栏头像；昵称现占原“健康”标题槽并恢复大字粗体样式，通知铃铛贴右；双时区全量各 951 项通过，iPhone 镜像复核通过；实机传感器至服务端闭环与全 App 逐页检查仍未验收。
- [2026-10-02 Health 顶部个人资料同步](IMPLEMENTATION-LOG-20261002-HEALTH-HEADER-PROFILE.md) — Health 顶部头像/昵称改读当前资料并加空值回退；iPhone Debug 安装和 VM 附加通过，双时区全量各 1,026 项通过；Android 构建因依赖网络等待中止，见记录。
- [2026-10-02 个人资料头像保存根因修复](IMPLEMENTATION-LOG-20261002-PROFILE-AVATAR.md) — 对照戒指 App 修正旧上传 503 和 canonical 头像地址；真实演示账号头像写入/回读后恢复，iPhone 客户端上传/图片读取通过，真实空资料的完整表单写入未执行；双时区各 944 项通过。
- [2026-10-02 国际版连接、资料、客服与英文界面修复](IMPLEMENTATION-LOG-20261002-CLIENT-UX-FIXES.md) — 修复超距自动恢复、资料保存验证、英文混中文/连接状态/权限按钮及用户截图发现的错误提示/客服文案问题；基础轮 23 张、扩展轮 36 张实机截图复核，扩展真机驱动、940 项全量测试与后续 45 项定向回归及真机调试通道状态均如实记录。
- [2026-10-01 国际 App 设备后台联调](IMPLEMENTATION-LOG-20261001-DEVICE-ADMIN-INTEGRATION.md) — 在独立分支加入连接就绪与自动重连上报；仅已验证的真实硬件地址可作为可选 MAC，测试和真机边界见本轮记录。
- [2026-10-01 国际版 SAYDIAN Health 首版 App Store 准备](release/IOS-GLOBAL-APPSTORE-MVP-20261001.md) — 独立 App Store Connect 记录、iPhone-only 正式签名归档与 IPA、测试及真实审核阻断；与国内 SayRing/赛电 App 分离。
- [2026-09-30 iPhone 15 Pro Max 逐页检查与 Debug 恢复](QA-20260930-IOS-PAGE-DEBUG.md) — 修正过期国际版真机测试断言，离线 34 页渲染检查及双时区 929 项回归通过；真机逐页自动化因 VM 通道断开未完成，缓存重建后 Flutter Debug/DevTools 恢复并保持运行。
- [2026-09-30 U19 最新交接说明](U19-HANDOFF-20260930.md) — 固定国际 App/服务端分支、当前 QA APK、真实验收边界及下一轮安全接手顺序；交接包清单与哈希另见打包校验记录。
- [2026-09-30 iOS U19 最新分支更新、覆盖重装与真机调试](QA-20260930-IOS-U19-LATEST-BRANCH.md) — 本地跟踪 `origin/feature/u19-eb1`；iPhone 15 Pro Max 已覆盖安装 `0.1.23 (1007)`，Dart VM Service、DevTools 与 285ms 热重载通过；22:24 新建 `flutter run` 会话并再次核对安装容器、运行进程、debugserver 与 USB 端口转发，当前保持运行。
- [2026-09-30 U19 Android 内部 QA 包与 Git 交付](release/U19-ANDROID-QA-20260930.md) — 记录国际仓库改回 Private、JCore 动态依赖漂移与固定版本、双时区/原生/ABI 门禁、安装包哈希和真机/线上未验收边界；APK 作为私有 GitHub 预发布附件，不入源码历史。
- [2026-09-29 U19 隔离 API 真机联调准备](U19-ISOLATED-API-PREP-20260929.md) — 本机 API 与 `/global` 路径差异、仅本机代理、隔离 Debug APK 构建及哈希；手机不在 ADB 列表，安装、真实日汇总上传/回读未执行。
- [2026-09-29 U19 交接](U19-HANDOFF-20260929.md)与[打包校验](U19-HANDOFF-VERIFY-20260929.md) — 固定国际 App 与服务端功能分支、CI/真机证据和未验收边界；交接包仅含受控源码快照、脱敏记录与内部 QA 包，逐项哈希/解压校验通过；协议原件/凭据/原始健康日志不入包。新增文档，不改变运行时代码。
- [2026-09-29 U19 Android 与国际服务联合复核](U19-JOINT-LIVE-QA-20260929.md) — U19 真机重连/当天读取、步数英文单位、GATT 单次重建、国际日汇总能力门禁测试及两时区 929 项回归；服务端隔离分支 CI 通过但未部署，线上能力路由仍 404；保留真机恢复分支与云端读回未验收边界。
- [2026-09-29 U19 安卓真机连接、校时与英文提示复核](U19-ANDROID-LIVE-QA-20260929.md) — 真实 U19 查找有振动/提示音、手动校时保持英文、同步前自动校时代码和 927 项回归；最终包仍复现 GATT 服务发现超时，云端日汇总 404 未验收。
- [2026-09-28 美国版图标语义、标题与文字收口](US-UI-COPY-20260928.md) — 英文导航、连接/电量、U19 设置、反馈和健康提示；含旧断言失败与修复、全量回归及真机保留数据安装记录。
- [2026-09-28 U19 扩展控制与国际版页面收口](U19-EXTENDED-CONTROLS-UX-QA-20260928.md) — 新增脉搏、动态血压、心率/血氧启动及通知回读，按能力隐藏未支持模块；记录二次确认、测试通过和手机拒绝覆盖安装后的真机验收边界。
- [2026-09-28 SAYDIAN Health 黑色品牌、美国默认体验与 U19 提示](U19-BLACK-BRAND-US-UX-20260928.md) — 记录黑标与虚构美国医生素材、应用改名、商城隐藏、美国默认设置、901 项 Flutter 与 482 项 Harmony 回归及未验收边界。
- [2026-09-28 U19 功能修复与回归](U19-FUNCTION-FIX-20260928.md) — 测量会话/通知补读/连接排空及页面提示修复；保留失败复现与真机、服务端部署边界，最终结果见记录。
- [2026-09-28 U19 连接、同步、测量与查找功能检查](U19-FUNCTION-AUDIT-20260928.md) — 三次受控重连及当天汇总读取通过；测量与查找入口未接通、云端日汇总能力 404；850 项原测试通过，新增诊断 1 通过/4 失败，未改产品代码。
- [2026-09-28 U19 每日汇总日期真机复核](U19-DAILY-DATE-QA-20260928.md) — U19S 当天回包通过日期校验；首次安装拒绝后按用户要求重装成功，冷启动再连成功；安装后首次 GATT 超时和线上日汇总能力 404 仍待解决。
- [2026-09-28 U19 Android 真机重连](U19-ANDROID-RECONNECT-20260928.md) — 记录服务发现超时、失败的首轮修复和第二轮有界重试；U19S 两次手动断开重连通过，每日汇总仍因日期不符拒绝上传。
- [2026-09-28 国际 App 设备连接后台上报](IMPLEMENTATION-LOG-20260928-DEVICE-ADMIN-REPORTING.md) — 连接就绪后以登录态上报最小设备快照，服务端按会员作用域保存；上报失败不影响连接，真机后台回读待联合验收。
- [2026-09-27 国际版 Android 模拟器调试](INTERNATIONAL-ANDROID-EMULATOR-QA-20260927.md) — API 36 Debug 启动、匿名登录/注册与协议页面、21 项定向测试和静态检查通过；更新清单 404、手机号区号体验差异及登录后/手表流程未验收。
- [2026-09-13 国际商城账号、推广与 App 支付隔离](INTERNATIONAL-COMMERCE-AUTH-REFERRAL-PAYMENT-20260913.md) — 原生支付只接受独立 App 配置，客户端结果不冒充到账；双时区各 841 项、域名 37 项、Android 原生 16 项及 Debug/QA Release 构建通过，真实交易和真机支付回跳仍明确未验收。
- [2026-09-13 国际 App 商城与 H5 能力对齐](INTERNATIONAL-COMMERCE-PARITY-20260913.md) — 源码、双时区 837 项、服务端 755 项、域名 37 项及 Debug/QA Release 构建已完成；华为手机拒绝 USB 安装，待开启手机端安装权限后做冷启动验收；仍未推送或发布。
- [2026-09-12 Android 真机 Debug 启动](QA-20260912-ANDROID-DEBUG-START.md) — 从最新干净 `main` 以 `app.saydian.cn` 配置覆盖安装并保持 Flutter Debug；登录和手表自动连接恢复、当前进程无崩溃，国际更新清单 404、闭源 SDK Debug 原始日志和单次启动跳帧继续明确记录。
- [2026-09-11 Android 扫描、能力展示与同步反馈修复](INTERNATIONAL-ANDROID-DEVICE-FIXES-20260911.md) — 扫描信号原位刷新、通知按真实支持项展示、健康提醒间隔与屏幕能力往返修复、同步结果八语提示及发行日志移除；双时区各 827 项、真机连接/两次同步/冷启动恢复和新域名日志检查通过，设备写入与其他型号继续明确未验收。
- [2026-09-11 Android 双型号设备与新域名联合复验](INTERNATIONAL-ANDROID-MULTIWATCH-QA-20260911.md) — 原目标受经典蓝牙连接影响未广播后，按用户授权实连 W8Pro 与 W9；两类能力按型号展示、同步与主要登录后页面完成只读复验，第一方结构化请求仅到 `app.saydian.cn`，国际更新清单未发布、闭源 SDK 原始扫描日志风险及三轮重连继续明确保留。
- [2026-09-10 登录后真机功能检查](INTERNATIONAL-POSTLOGIN-DEVICE-CHECK-20260910.md) — 保留真实会话的逐页只读检查、12 项专用账号 GET、4 项 P1 缺口；双时区各 822 项通过不等于功能全通过。17:24 追加：USB 调试已授权，连接状态下通知/屏幕/设备信息可读，并真机确认不支持通知项仍显示；冷启动后精确绑定目标未被扫描发现，未猜选同名设备，自动重连及其余控制继续未验收。
- [2026-09-10 健康/AI/关爱审计](INTERNATIONAL-POSTLOGIN-HEALTH-AUDIT-20260910.md) — 缺云端历史拉取；真实客户端/换号成功响应复现旧档案显示，3 项纯 mock 诊断及 187 项现有定向测试，保留探针失败与修正。
- [2026-09-10 资料/商城/设置审计](INTERNATIONAL-POSTLOGIN-COMMERCE-AUDIT-20260910.md) — 头像迟到串写、资料回读失败仍报成功、单位不持久、国际地址未接入；4 项纯 mock 缺陷探针、公开接口现状与 86 项回归。
- [2026-09-10 设备能力与契约审计](INTERNATIONAL-POSTLOGIN-DEVICE-AUDIT-20260910.md) — 通知可见性、运动模式推断、屏幕时长与提醒间隔四项源码缺口；134 项定向测试、8 项原生日志源码检查不替代真机能力验收。
- [2026-09-10 国际注册登录真机复验](INTERNATIONAL-AUTH-DEVICE-20260910.md) — 隔离国际服务已部署、真实只读门禁通过；专用账号与 Android 登录同意流程逐项复验，旧 404 失败记录保留。
- [2026-09-10 登录隐私同意 P1 修复](INTERNATIONAL-AUTH-CONSENT-20260910.md) — 登录/注册/重置显式同意，失败不覆盖状态，通知权限不冒充隐私同意；93 项定向回归。
- [2026-09-10 专用测试账号验证工具](INTERNATIONAL-AUTH-ACCOUNT-QA-20260910.md) — 显式授权创建单个隔离账号，注册/会话轮换/退出/密码登录；私有凭据不进 Git，真实结果单独记录。
- [2026-09-10 国际注册登录只读检查](INTERNATIONAL-AUTH-SMOKE-20260910.md) — 固定新域 /global、拒绝跳转、真实能力与已审协议检查；47 项测试通过，线上 404 与腾讯云重新登录阻塞明确保留。
- [2026-09-10 国际媒体相对地址兼容](INTERNATIONAL-MEDIA-COMPATIBILITY-20260910.md) — 仅补已允许媒体路径的相对解析，保持新域名、路径与重定向保护。
- [2026-09-10 联合验收覆盖矩阵](INTERNATIONAL-JOINT-COVERAGE-20260910.md) — 页面、域名、接口与回读证据逐项区分通过、失败、未验收。
- [2026-09-10 独立真机 QA 驱动](INTERNATIONAL-JOINT-QA-DRIVER-20260910.md) — 私有配置指定精确设备，三轮只读同步测试；不执行 OTA、覆盖联系人或表盘，不把设备侧成功计为云端通过。
- [2026-09-10 正式协议入口修复](INTERNATIONAL-LEGAL-ROUTES-20260910.md) — 登录、账号、关于统一走真实协议及版本；禁止旧文章路径与未审核替代文本，98 项相关测试通过。
- [2026-09-10 重连独立复查](INTERNATIONAL-RECOVERY-INDEPENDENT-REVIEW-20260910.md) — 每 SDK 实际排空与迟到清理，独立 48 项验证；不凭有并发操作的旧真机日志臆测原因。
- [2026-09-10 Dart 日志隐私](INTERNATIONAL-DART-LOG-PRIVACY-20260910.md) — 健康保存异常仅记类型；供应商直打日志与本地依赖替换边界单独保留。
- [2026-09-09 Android 与隔离国际服务联合验收](INTERNATIONAL-JOINT-QA-20260909.md) — 新域名固定 /global 路由、下载/媒体请求保护、环境数据隔离及真机联调；逐项记录已通过、失败与未验收边界。
- [2026-09-09 更新重定向防护](INTERNATIONAL-UPDATE-REDIRECT-GUARD-20260909.md) — 下载每跳发送前检查、国际安装器独立门禁与 72 项定向测试。
- [2026-09-09 原生日志隐私审计](INTERNATIONAL-NATIVE-LOG-PRIVACY-20260909.md) — 厂商日志开关及 App/插件日志脱敏；玉成闭源日志残留单列待验。
- [2026-09-09 环境持久化隔离](INTERNATIONAL-ENVIRONMENT-STORAGE-20260909.md) — 旧记录/密钥保留、环境绑定与精确目标恢复，113 项相关回归。
- [2026-09-09 国际商城只读闭环](INTERNATIONAL-COMMERCE-READONLY-20260909.md) — UUID 商品详情、搜索/分页及缺币种安全展示；交易能力保持关闭。

- [2026-09-09 国际版生产域名直接切换](INTERNATIONAL-PRODUCTION-DOMAIN-SWITCH-20260909.md) — 清除通用 API/更新/真机 QA 中的旧 `.cc` 默认值，强制国际版使用 `https://app.saydian.cn`。
- [2026-09-09 国际版真机扫描定位开关](INTERNATIONAL-DEVICE-SCAN-20260909.md) — Android 10 权限允许但系统定位关闭导致搜索为空；用户开启定位后确认已发现设备，补共享扫描前置检查、八语设置引导和返回重试。
- [2026-09-09 国际版临时免验证码注册](INTERNATIONAL-UNVERIFIED-REGISTRATION-20260909.md) — 服务端能力明确驱动邮箱/E.164 手机免码注册，联系方式仍保持未验证；Flutter 636、Harmony 481、Android 原生 15 项通过，模拟器与隔离 API/数据库闭环完成，生产开关默认关闭。
- [2026-09-09 国际版实施与测试](INTERNATIONAL-IMPLEMENTATION-20260909.md) — 独立私有仓库、三端身份、隔离账号/V2健康同步、八语基础、真实协议与渠道门禁；所有失败、修复、尚未验收项保留。先读[国际版交接](INTERNATIONAL-HANDOFF.md)，不得按以下国内历史记录直接发布国际版。

- [2026-09-08 Android 微信授权登录真机联调](QA-20260908-ANDROID-WECHAT-LOGIN.md) — 已补 Android 微信入口、原生授权回调和 App 登录接口契约；真机可到达微信授权成功回调，但当前服务端接口要求客户端直接提交 `openid`，与 Android SDK 实际仅返回一次性 `code` 不兼容，完整登录待服务端按 `code` 换取身份后复验。
- [2026-09-07 三端设备型号展示回退](IMPLEMENTATION-LOG-20260907-DEVICE-MODEL-FALLBACK.md) — SDK 型号为空时仅在展示层取蓝牙名最后一个 `-` 后的非空内容；Flutter 双时区各 525、鸿蒙双时区各 429，Android/iOS/鸿蒙 Debug 编译通过。
- [2026-09-07 鸿蒙运动与记录完整闭环](IMPLEMENTATION-LOG-20260907-HARMONY-SPORT-PARITY.md) — W9S 真实能力限制为跑步/步行/骑行，跑步启停、51 秒加密记录和详情真机通过；双时区各 428 项、Debug/Release 构建与验签通过。
- [2026-09-07 三端包 GitHub 上传确认](release/QA-UPLOAD-20260907-R6.md) — `qa-20260907-r6` 私有预发布，5 个安装包加说明/校验共 7 附件，远端 SHA 和大小一致；标签 `1110a5f`，不等于商店或 CI 验收通过。
- [2026-09-07 最新三端 QA 安装与发布说明](release/QA-RELEASE-20260907-R6.md) — Android r6 两包、iOS r6 Profile、Harmony r12 两包及安装/签名边界；仅 GitHub 私有预发布，不能作为正式上线结论。
- [2026-09-07 Android r6 真机安装预检](QA-20260907-ANDROID-R6-LIVE.md) — 重连后确认现装 r5 与新包同签；随后 USB 三次断续，未执行安装或清绑定，不启动未知保存目标抢占手表。
- [2026-09-07 三端续测、授权恢复与 r6 构建](IMPLEMENTATION-LOG-20260907-CARE-PUSH-RESUME.md) — workflow 已推送但 CI 计费仍阻断；P40 r5 已装而 USB 未授权，r6 / 鸿蒙 r12 独立记录最终构建与验证边界。
- [2026-09-07 共享保存回读与账号隔离](IMPLEMENTATION-LOG-20260907-CARE-SHARE-READBACK.md) — POST 后原账号回读一致才成功、换号拒绝迟到响应、保留未知键；新增 44 项、完整双时区各 524 项通过，不替代服务端撤销授权修复。
- [2026-09-07 Android r6 安装包门禁](QA-20260907-ANDROID-R6-ARTIFACTS.md) — 首轮原生推送配置漏注入拒收，重建后按实际 APK 复核签名、原生参数、ABI 与 16 KB。
- [2026-09-07 鸿蒙 r12 构建与签名](BUILD-20260907-HARMONY-R12.md) — 同源重新生成 Debug/Release，双时区各 423、官方验签；开发 Profile 不等于商店发行。
- [2026-09-07 三端整改阶段总结](QA-SUMMARY-20260907.md) — 已完成、真机失败、开发验证包、服务器与系统限制分开；优先从此进入本轮最终结果。
- [2026-09-07 关爱组合读取账号归属](IMPLEMENTATION-LOG-20260907-CARE-READ-SESSION.md) — r5 拒绝换号后的迟到成功/错误与旧 401 刷新，同账号刷新保留；定向 90、完整双时区各 480 项，现网 HRV 撤销仍须后台修复与复验。
- [2026-09-07 关爱单项结果权威性](IMPLEMENTATION-LOG-20260907-CARE-METRIC-AUTHORITY.md) — r3 真机撤销 HRV 仍显示摘要失败后，Flutter r4 删除无类型总表预读/回填，完整双时区各 463 项通过；旧后台单项失败不再伪装成功。
- [2026-09-07 鸿蒙关爱单项权限边界](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-AUTHORITY.md) — r11 同步删除总表补偿，403/空/不可用分开，完整双时区各 423 项；服务器单项授权与后台推送仍须现场闭环。
- [2026-09-07 鸿蒙离线运动与资料保存回读](IMPLEMENTATION-LOG-20260907-HARMONY-OFFLINE-SPORT-PROFILE.md) — 按账号查询本机运动而非依赖连接及全局快照；实际提交字段逐项回读，保存不完整不报成功。
- [2026-09-07 CI 鸿蒙双时区契约检查](IMPLEMENTATION-LOG-20260907-HARMONY-CI.md) — 新增独立 Node 测试矩阵，非 HAP 编译；工作流授权及远端计费门禁仍阻断。
- [2026-09-07 鸿蒙命令排空与迟到回调隔离](IMPLEMENTATION-LOG-20260907-HARMONY-COMMAND-DRAIN.md) — 8 类旧操作补真实 Promise 排空及断开确认；生产服务 53 项、完整双时区各 380 项通过，最终 r9 构建和验签通过。
- [2026-09-07 鸿蒙单位设置非目标字段保护](IMPLEMENTATION-LOG-20260907-HARMONY-UNIT-SAFETY.md) — 避免官方单字段接口随手机覆写手表时制；保存前后逐一核对 32 字段，真机恢复原 24 小时并完成距离/温度切换回归。
- [2026-09-07 三端关爱授权撤销核查](IMPLEMENTATION-LOG-20260907-CARE-AUTHORIZATION.md) — 修复 Flutter 单项 403 被总表回退吞掉及未授权旧值显示；若现网只返回 200 空表，仍需服务端明确授权状态，不能据此声称撤销联调通过。
- [2026-09-07 鸿蒙心电无效值与佩戴状态](IMPLEMENTATION-LOG-20260907-HARMONY-ECG-VALIDITY.md) — 厂商明确 ECG HRV 255 为无效值；补真实佩戴回调、单次安全取消和迟到结果隔离，双时区各 344 项通过，独立日历史 255 未做推断性删除。
- [2026-09-07 关爱红点、前台横幅与通知点击复核](IMPLEMENTATION-LOG-20260907-CARE-NOTIFICATION-UNREAD.md) — 远端0不抹本地邀请未读；完整双时区439项通过；旧安卓包系统通知点击异常仍待新包现场复验，不能标完整通过。
- [2026-09-07 现网旧后台关爱推送](QA-20260907-CARE-PUSH-LIVE-BACKEND.md) — 已用Chrome核实旧Yii与有效极光配置；P40单设备通道约1秒到达，实际业务自动触发仍缺旧控制器/主机证据。
- [2026-09-07 鸿蒙前台关爱邀请提醒](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-POLLING.md) — 补前台定时兜底、按账号本地收件箱、通用系统通知、稳定邀请去重和迟到请求隔离；后台即时投递及跨通道系统去重仍待服务端与真机验收。
- [2026-09-07 三端统一、账号隔离与真机回归](IMPLEMENTATION-LOG-20260906-THREE-PLATFORM-QA.md) — 本轮持续实施记录；Flutter账号/连接代次、通知契约、iOS原生表盘路由与响应式布局已补定向及全量回归，三端真机与后台通知仍在联调，不能作为整体上线通过。
- [2026-09-07 账号与手表会话防串写](IMPLEMENTATION-LOG-20260907-ACCOUNT-WEARABLE-SESSION.md) — 登录切换排空旧测量/连接，拒绝迟到回调和未绑定记录；保留手动取消与自动完成边界。
- [2026-09-06 Android 连接、权限与发行安全细节检查](IMPLEMENTATION-LOG-20260906-ANDROID-DETAIL-QA.md) — 修复蓝牙权限竞态闪退风险并收紧发行权限；华为 P40 已完成覆盖安装、ET488 自动重连、同步、趋势、表盘读取、查找手表和前后台恢复回归，404 项测试通过；当前账号 401 阻断远程关爱、消息与推送验收。
- [2026-09-06 鸿蒙 Vep 设备全功能真机验收](IMPLEMENTATION-LOG-20260906-HARMONY-ET488-FULL-QA.md) — ET488 历史问题与 W9S 现场回归已归档；已修复距离单位、血氧结束卡住和末帧覆盖有效读数，W9S 连接/同步/设备控制/测量/重连通过，完整心电终态及非零运动数据仍待后续真实样本。
- [2026-09-06 鸿蒙资料、关爱与设备发现整改](IMPLEMENTATION-LOG-20260906-HARMONY-PROFILE-CARE-DISCOVERY.md) — 资料编辑/头像选择、关爱指标状态与成员人数一致性已修复并真机验证；扫描链路正常但目标表未广播，非空成员健康数据与正式发行签名仍有外部阻断。
- [2026-09-06 鸿蒙内页逐页对照、功能补齐与手表发现复查](IMPLEMENTATION-LOG-20260906-HARMONY-INNER-PAGES.md) — 商城详情/规格/购物车/确认订单/订单详情/物流/售后续补；鸿蒙双时区各 198 项、Flutter 各 403 项、Debug/Release 编译及真机覆盖安装。交易写入、部分内页和目标表待验；GitHub CI 计费/额度阻断，非整体验收通过。
- [2026-09-06 鸿蒙设备发现与蓝牙广播排查](IMPLEMENTATION-LOG-20260906-HARMONY-DISCOVERY.md)
- [2026-09-06 鸿蒙版全面对齐 iOS 界面](IMPLEMENTATION-LOG-20260906-HARMONY-IOS-UI.md)
- [2026-09-05 iOS 微信登录与界面文案精简](IMPLEMENTATION-LOG-20260905-IOS-LOGIN-COPY.md)
- [2026-09-05 鸿蒙推送、支付与发布检查](../harmony-native/docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)
- [2026-09-05 健康档案、付费报告与 StoreKit 接入](IMPLEMENTATION-LOG-20260905-HEALTH-REPORTS.md)
- [2026-09-04 iPhone 与 W9S 真机测试](IMPLEMENTATION-LOG-20260904-IOS-W9S-DEVICE.md)
- [2026-09-04 合入 main 并保留 iOS 支付修复](IMPLEMENTATION-LOG-20260904-MAIN-MERGE.md)
- [2026-09-02 新服务端平滑迁移联调](IMPLEMENTATION-LOG-20260902-SERVER-MIGRATION.md)
- [2026-08-30 华为 P40 鸿蒙真机回归与窄屏溢出修复](IMPLEMENTATION-LOG-20260830-HARMONY-P40.md)
- [2026-08-30 iOS 心电手动测量崩溃修复与真机回归](IMPLEMENTATION-LOG-20260830-IOS-ECG.md)
- [2026-08-29 通知、表盘、电量、在线升级与多设备真机整改](IMPLEMENTATION-LOG-20260829-ONLINE-READINESS.md)
- [2026-08-29 关爱、跨端历史、运动、预警与 iOS 表盘修复](IMPLEMENTATION-LOG-20260829.md)
- [2026-08-28 远程关爱、小程序参数、双支付与健康链路回归](IMPLEMENTATION-LOG-20260828.md)
- [2026-08-27 心电、AI、关爱、监测间隔与连接恢复](IMPLEMENTATION-LOG-20260827.md)
- [2026-08-25 全界面体验与型号能力收口](IMPLEMENTATION-LOG-20260825.md)
- [2026-08-24 远程关爱、商城、头像与心电真机回归](IMPLEMENTATION-LOG-20260824.md)

## 固定防复发资料

- [2026-08-29 跨端问题修复复盘](BUG-RETROSPECTIVE-20260829.md)
- [赛电 App 修改与回归检查清单](REGRESSION-CHECKLIST.md)

## 记录模板

```text
### HH:mm 修改/验证名称

- 原因：
- 文件/范围：
- 预期：
- 结果：通过 / 失败 / 未执行
- 失败原因：
- 修复结论：
- 后续待验：
```
