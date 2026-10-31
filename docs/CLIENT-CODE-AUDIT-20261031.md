# 国际版客户端代码审查与防复发记录（2026-10-31）

> 后续：六项已于 2026-11-01 修复源码并验证自动回归，原反例已进入常规测试。见 [修复记录](IMPLEMENTATION-20261101-CLIENT-AUDIT-FIXES.md) 和 [当前门禁](CLIENT-REGRESSION-GATES.md)。以下 OPEN/红灯为 10-31 当时的历史证据，原始结果不覆盖；新真机/正式签名验收另列。

## 结论与范围

本轮审查发现 **4 个可离线复现的问题、2 个源码确认的防御缺口**，均为 OPEN，尚未修复产品代码。既有测试通过不代表这些问题不存在；新增安全断言目前全部失败，作为后续修复的可执行证据保留。

- 审查对象：当前本地国际版 `cn.saydian.app.global`，版本 `1.0.1+1020`；基线 `6b197e9228b0a3148e81de54cb62f0c2f261eb55`，原分支 `codex/ios-device-debug-20261029`。
- 本轮分支：`codex/client-code-audit-20261031`。开始时工作树干净，已执行 `git fetch origin --prune`；没有合并、重置或覆盖其他分支。
- 方法：追踪入口、状态与数据流，检查 Flutter 业务层和关键 Android/iOS 桥接、权限、存储、网络及发布脚本；运行已有测试，并用真实客户端类配合内存存储、MockClient 和合成账号做异常路径复现。
- 修改范围：审查文档、回归清单、交接索引及独立复现测试；没有修改运行时、权限、版本、服务器、商店或手机数据。
- 边界：这不是逐行覆盖所有厂商二进制的安全认证。未做在线攻击、实时 CVE/依赖公告检索、服务器授权审计、支付实单、OTP 投递或新的实体设备验收。本轮没有重建、安装、上传和提审。

优先级沿用项目定义：P1 为核心功能异常，P2 为异常状态、隐私或稳定性防御缺口；不是 CVSS 评分。没有证据支持“已发生远程入侵/用户数据泄露/数据已丢失”的结论。

## 问题清单

| ID | 优先级 | 问题 | 当前证据 | 状态 |
| --- | --- | --- | --- | --- |
| AUD-01 | P1 | 无效元数据占据队首，后续有效记录无法上传 | 两次同步均未提交第 11 条有效记录 | OPEN，已复现 |
| AUD-02 | P2 | 旧退出请求完成后清除了新会话 | A 退出延迟、B 写入后，vault 实际为 null | OPEN，已复现 API 竞态 |
| AUD-03 | P2 | 只有本机生理记录时仍显示云同步完成 | iOS 上传 0 条，状态却为 complete | OPEN，已复现 |
| AUD-04 | P2 | 退出后仍挂载的订单页保留旧账号内容 | controller 已退出，旧订单仍可见 | OPEN，已复现组件生命周期 |
| AUD-05 | P2 | Android Debug 仍可能打印压力值和采样时间 | CoolWear 桥接两处直接 Log 输出 | OPEN，源码确认，未采集真机日志 |
| AUD-06 | P2 | ECG 下载/解压在完整分配后才限制长度，且缺专用请求超时 | 波形读取实现与通用请求封装不同 | OPEN，源码确认，未压测 |

### AUD-01：队首拒绝导致同步饥饿

**来源：** [sync_service.dart](../lib/services/sync_service.dart) 第 47、73、144 行；[global_health_api.dart](../lib/services/global_health_api.dart) 第 72、287、339 行；[local_health_store.dart](../lib/services/local_health_store.dart) 第 1147 行。

**复现：** Android 策略下，在内存健康队列按顺序放入 10 条数值合理但 timezone 为无效字符串的记录，再放入 1 条完整有效记录；使用真正的 GlobalSaydianApiClient 和可 ACK 的 MockClient，连续调用同步两次。

**预期：** 保留无效原始数据及失败原因，同时允许后面的有效记录进入上传。**实际：** 两次都取相同前 10 条；数值检查放行，V2 元数据检查全部拒绝，acceptedIds 为空后立即返回，第 11 条从未提交。生产 SQLCipher 队列也是按时间从旧到新限量读取，存在同类阻塞条件。

**影响：** 异常旧记录可能长期挡住新记录；未证明数据被删除。不能用“保留 pending”代替“队列可继续前进”。ECG 准备失败、服务端逐条拒绝也应检查相同模式，未在本轮一概认定为同一根因。

**修复建议：** 区分永久元数据错误、可恢复准备失败、网络失败；建立保留原始内容的隔离/重试状态和有界队列遍历。不能靠删除原始数据、伪造时间、跳过 ACK 或无限循环绕过。

**关闭条件：** 前 10 条坏记录 + 第 11 条好记录；部分拒绝；网络重试；跨批次游标；换号取消；隔离记录可追溯和恢复。有效记录须拿到对应 ID 的 ACK，未确认记录仍在正确账号下保留。

### AUD-02：迟到退出清除新会话

**来源：** [global_api_client.dart](../lib/services/global_api_client.dart) 第 1700–1725 行；[secure_vault.dart](../lib/services/secure_vault.dart) 的 clearSession。刷新写回已有比较保护，退出清理没有相同保护。

**复现：** A 会话发出 logout 后暂停响应；向同一 vault 写入 B 会话，再让旧 logout 成功返回。**预期：** 仅清除被退出的会话，保留 B。**实际：** finally 无条件 clearSession，B 也消失。deleteAccount 成功后的清理有相同源码模式，尚未单独动态复现。

**影响边界：** API 层并发/迟到回包缺口已复现。正常 controller 的 busy/账号转换限制会降低常规 UI 触发机会；不据此宣称所有手动退出都串号，更不代表获取了其他账号权限。

**修复建议：** 对 vault 增加与 session 写入同队列的 compare-and-clear，绑定预期会话及代次；同时覆盖旧会话过期、退出、注销和重新登录路径。仅按 memberId 比较不足以识别同账号新登录。

**关闭条件：** A→B、同账号重新登录、旧 401/refresh、logout 失败/成功和注销迟到各有测试，旧操作不能删除或替换新会话。

### AUD-03：本机记录被算入“云同步完成”

**来源：** [app_controller.dart](../lib/services/app_controller.dart) 第 3490–3527 行；[ios_wellness_policy.dart](../lib/domain/ios_wellness_policy.dart)。

**复现：** iOS、Urion/U19S 条件下只放入一条本机心率记录，没有允许上传的活动/睡眠记录，调用 synchronizeCloud。**预期：** 显示本机保存/没有可上传内容等准确状态。**实际：** uploadedCount 为 0，却因 healthRecords 非空进入 complete，并生成“数据已同步，无待上传记录”状态。

**影响：** 容易误导用户及测试人员，以为本机生理数据已上云。该用例没有发起实际健康上传，不是 iOS 生理数据出站的证据。

**修复建议：** 状态统计以当前平台、账号、设备和允许指标的云同步候选集为准，明确本机保存、待传、已 ACK 和无可传内容；不能扩大 iOS 上传范围来消除提示差异。

**关闭条件：** 空库、仅本机记录、已 ACK 活动/睡眠、混合记录、被拒记录、设备切换和换号均验证界面文案及实际 HTTP 指标。

### AUD-04：已加载私有页面未随退出清空

**来源：** [global_shop_account_pages.dart](../lib/ui/global_shop_account_pages.dart) 第 639–690 行；[app_controller.dart](../lib/services/app_controller.dart) 第 166–181 行；[app.dart](../lib/app.dart) 第 242 行。

**复现：** 挂载真实 GlobalShopOrdersPage，加载合成 A 账号订单；页面保持挂载时调用真实 controller.logout 并刷新组件。**预期：** 会话失效后不再展示 A 私有内容。**实际：** controller.session 已为 null，页面 `_orders` 仍渲染 A 的订单。

**影响边界：** 已证实的是“私有路由保留时的已加载缓存”。Controller 已有迟到 commerce 请求的账号检查，但它不能清理早已载入的组件状态。常规 Profile 退出是否总能保留该路由、强制失效与换号的真机入口仍待端到端验证；未证明服务器越权读取。收藏、地址、订单详情、物流、积分、购物车应逐页排查，不能把订单单例当成全部页面已经复现。

**修复建议：** 建立可复用的账号所有者/代次监听，退出、注销和换号时清空私有数据、取消旧加载；应用根路由撤出私有页面作为额外保护，不仅在下一次网络请求时检查。

**关闭条件：** 已加载页面与在途请求分别覆盖；A→B、失效、注销、返回栈、重新进入、地址草稿均不能显示/提交 A 内容；公共商品页不应被不必要清空。

### AUD-05：Debug 日志存在健康值输出

**来源：** [CoolWearRingBridge.java](../android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java) 第 951–953、987–989 行；[test_native_log_privacy.mjs](../tool/test_native_log_privacy.mjs) 末尾 ring adapter 检查。

源码在 BuildConfig.DEBUG 中将压力数值、设备时间和转换时间拼入 android.util.Log。现有原生日志测试主要保护部分厂商日志、异常文本和栈，没有断言这两处原始值输出不存在。

**边界：** 源码条件为 Debug；Release 的 DEBUG=false 及 Log 移除规则是现有保护。本轮没有检查新正式 APK 字节或采集真实用户 logcat，不能声称已确认正式包泄露。

**修复/关闭条件：** 所有桥接在真实账号调试时也只记录固定阶段、状态和必要计数；脱敏测试覆盖 Debug/Release 和全部五种桥接，不把真实健康值、设备标识、坐标、凭据或原始 SDK 对象写入日志/Git。诊断夹具仅用合成数据。

### AUD-06：ECG 资源上限检查过晚

**来源：** [global_health_api.dart](../lib/services/global_health_api.dart) 第 9–69 行。

波形路径直接 `_client.get`，没有经过通用 `_performRequest` 超时；完整接收 body 后检查 25MiB，再完整 gzip.decode 后检查 32MiB。限额和 SHA 校验存在，但不是接收/解压过程的内存上限。相同 host、禁止重定向和账号回包检查仍存在。

**影响边界：** 异常/过大响应可导致等待过长或瞬时内存压力，是否形成可利用攻击还取决于服务端上传约束和访问条件。本轮没有发送大压缩包或重现 OOM。iOS 的当前传输策略禁止 ECG，因此不能把本项描述为 U19S iOS 已发生的崩溃原因。

**修复/关闭条件：** 流式读取设置字节数与截止时间，解压时有界计数并保留 hash、采样数、采样率和账号验证；使用小型合成流覆盖慢流、超限、损坏 gzip、超时、取消和换号，不对生产服务器压测。

## 已检查的保护与覆盖边界

| 范围 | 已核对的代码/测试保护 | 不可推导的结论 |
| --- | --- | --- |
| 国际网络隔离 | GlobalEnvironment 固定美国 HTTPS/.com/global；生产禁任意 origin；HTTP 最后边界禁跨源、禁重定向、iOS 禁止接口 | 本轮没有证明服务器地理位置或每个真实厂商请求 |
| 第三方资源 | SafeResourceClient 分用途白名单；SafeNetworkImage 流式限额/超时；资源不能任意接收登录请求 | ECG 路径不共享图片保护，见 AUD-06 |
| 会话和私有数据 | 环境命名空间、OS 安全存储、refresh 单飞与比较写入；controller 多处账号代次校验 | 清除会话及已加载页面仍有 AUD-02/04 |
| 本机数据库 | SQLCipher、owner 查询、串行操作、不可读库与 sidecar 保留/隔离；旧域名缓存须身份映射 | 内存复现不等于已完成 SQLCipher 文件恢复演练 |
| 上传和回读 | 小批次、ACK ID 子集验证、未 ACK 保留 pending、无效数值隔离、平台投影 | 队列前进性与状态文案有 AUD-01/03 |
| 蓝牙与能力 | 当前 production bootstrap 包含 Veepoo/Yucheng/Urion/CoolWear/QRing；恢复限已绑定设备；按 SDK 能力与平台限制入口 | 发现、匹配、连接、真实采集、历史、ACK、回读、去重是不同阶段 |
| iOS 范围 | Urion 的已支持生理入口仅本机；云与关爱仍活动/睡眠，传输层再拦截 AI/ECG 等 | 不能把其他设备能力或新版 UI 套到 1018 审核包 |
| 远程关爱 | 指标授权投影、页面账号/请求代次、撤回入口 | 本轮不是服务端关系授权/撤回穿透审计 |
| 商城 | 账号请求代次、报价/金额/币种、幂等相关既有测试 | 未真实支付、退款、物流验收；组件缓存另查 AUD-04 |
| 法律和语言 | reviewed/version/type/locale 核对；英文法律正文拒绝中文混入；默认英语、设备通用表述的既有测试 | 本轮未复核线上每篇内容、每个 SKU 和全部语言视觉效果 |
| 权限与发布 | Android 禁备份/明文及多余权限；RestrictedCoolWearProvider 有调用 UID 限制；正式签名、ABI、hash/更新下载门禁 | exported=true 本身不是越权证据；发布工具测试不是实际正式产物检验 |
| 日志 | 网络记录无 query/header/body，仅安全字段；多个厂商关闭原始日志 | 全日志无健康值尚不成立，见 AUD-05 |

## 测试与检查结果

环境：macOS，Flutter 3.44.9（framework 6b182d2c75），Dart 3.12.2。所有 MockClient 请求均截获于本机；日志中的 `.com` 只是请求对象的地址，不是实际生产访问证据。

| 检查命令 | 本轮实际结果 |
| --- | --- |
| `flutter --no-version-check analyze --no-pub`（添加复现前） | 退出 0，No issues，3.1s |
| `TZ=UTC flutter --no-version-check test --no-pub --reporter=expanded` | 1110/1110 通过，退出 0，36.3s |
| `TZ=Asia/Shanghai flutter --no-version-check test --no-pub --reporter=expanded` | 1110/1110 通过，退出 0，25.9s |
| `python3 -m unittest discover -s scripts/release -p 'test_*.py'` | 25/25 通过；负向夹具中的拒绝/回滚输出是预期测试结果，含旧国内发布工具夹具，不代表国际正式包重新验收 |
| Node `--test` 下列四文件 | 91 项：90 通过，1 跳过，0 失败；Windows ACL 用例在本机跳过，不计通过 |
| `flutter --no-version-check test --no-pub --reporter=expanded tool/audit/client_review_regressions_test.dart` | 退出 1，4 条目标安全断言全部失败；成功复现 AUD-01/02/03/04，不是编译/环境失败 |
| `dart format --output=none --set-exit-if-changed lib test tool/audit/client_review_regressions_test.dart` | 新复现文件先格式化一次；最终检查 194 文件、0 改动、退出 0 |
| `flutter --no-version-check analyze --no-pub`（新增复现后） | 退出 0，No issues；包含新审查测试源码 |
| `git diff --check` | 退出 0，无空白错误 |

Node 实际使用本机已存在的 `/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node`，四文件为：

```text
tool/test_native_log_privacy.mjs
tool/test_urion_native_lifecycle.mjs
tool/global_auth_smoke.test.mjs
tool/global_auth_account_qa.test.mjs
```

新复现测试在 [tool/audit/client_review_regressions_test.dart](../tool/audit/client_review_regressions_test.dart)，有意放在独立 audit 目录，须显式运行。**普通 `flutter test` 的绿灯目前不包含这四项。** 修复时将对应场景转入正常回归并接入 CI；不能删断言、改为接受坏结果或 skip 后宣布修复。

执行中的工具问题：首次 Node 调用因 PATH 没有 node 而失败，改用已有绝对路径后成功，没有安装或升级依赖。查找旧文件名/空 glob 失败已按实际路径修正，不属于产品失败。Flutter 日志中 `Reviewed analysis document changed` 是既有“协议变化不得授权”负向用例的捕获日志，该用例实际通过；不能误报为测试后仍未处理的线上崩溃。

原始日志保留在本机权限受限的 `/private/tmp/saydian-client-audit-20261031/`，未提交；汇总见 [机器可读结果](audit/20261031-client-results.json)。格式化、新增测试后的分析和最终 diff 检查结果在该汇总及下方完成记录中维护。

**未执行：** Android Gradle/JVM 构建与原生编译测试、iOS Xcode/XCTest/签名构建、Harmony HAP、全量设备/传感器回归、线上登录与服务器回读、恢复演练、当前远端 CI 运行。本轮仅审查、测试和文档，没有产品源码改动；这些未执行项不能沿用历史成功冒充本次通过。既有设备调试未主动停止。

## 分支、审核和发布防复发

1. fetch 后 `origin/codex/global-update-20261018` 为 `f5d632b973834aaab3aaabe11777c93be75cc76d`，与本地不是同一树，包含 R12 路由及额外 QA/资格记录。当前分支没有合入这些差异；不得将不同分支的测试与产物混用。集成需先比较源树、保留历史，再重跑相关门禁及对应实体设备。
2. 现有质量 CI 是 analyzer、lib/test 格式化、双时区 Flutter 测试和发布脚本测试等；不能覆盖尚未加入的 audit 四项、商店实际选包、审核账号现场可登录、真实配对视频和当前政策正文一致性。
3. 当前工作区 1020 含 U19S 本机模块；历史 App Store 1018 的功能范围和说明不能直接复用。版本号、源 commit、产物 hash、iOS/Android 能力矩阵、英文截图/政策/审核说明必须成套核对。
4. 此前审核反馈含审核账号访问与实体设备配对流程证据。用户确认登录恢复、已发送回复，不等于苹果验证通过或硬件视频已齐备。本轮没有访问商店更新审核状态，历史拒绝原因仅作验收背景。
5. 关闭问题必须记录：负责人、修复 commit、反例测试转绿、相关全量测试、受影响构建、实际设备与型号、私有证据位置和剩余限制。未提供证据的条目持续 OPEN。

建议处理顺序：AUD-01 队列前进性 → AUD-02/04 会话与私有页面 → AUD-03 状态准确性 → AUD-05/06 日志和资源上限。后续执行统一使用 [客户端长期回归门禁](CLIENT-REGRESSION-GATES.md)，不依赖聊天历史。

## 本轮完成记录

- 审查发现、失败复现、通过/跳过/未执行边界已写入本文件；未修改产品行为或消除上述失败断言。
- 格式化后显式复现再次得到相同四项失败；最终 analyzer 零问题，格式检查 194 文件零改动，diff 检查通过。详细结果见 [结果汇总](audit/20261031-client-results.json)。本轮 Git 提交只包含审查资料及合成复现测试，不包含密钥、日志、数据库或构建产物。
