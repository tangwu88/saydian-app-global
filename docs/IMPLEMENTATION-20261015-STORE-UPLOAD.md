# 2026-10-15 两端提审接续与 QRing 构建缓存修复

- 用户要求完成 Google 正式包、Apple 英文截图上传，检查通过后提交两端审核；已有提审授权保留。
- 修改前：`git status --short --branch` 工作树干净，`git fetch --prune origin`、`git pull --ff-only` 完成。基线 `13fe1158986a68864f9a1174bc0fd9ca89d69752`，新分支 `codex/qring-cache-stability-20261015`；未合并 main，未修改国内库。
- 发现：1018 源码 CI PR 38549542319 / push 38549535810 的质量、鸿蒙契约、iOS 任务通过，Android 任务在 release 后执行原生测试时失败于 `mergeSideloadDebugAssets`，尚未运行测试。不能把此前单次 AAB 构建通过当作整个 CI 通过。
- 本机复现：`JAVA_HOME=/Users/saydian/develop/jdk17 ./gradlew :app:mergePlayDebugAssets --offline --console=plain`，6 秒失败于同一 immutable transform `7f73751249d83a4932d8c5b5c5acab22`；原始日志和失败前 SHA256 清单位于忽略目录 `build/store-us-1018/`。失败调用前后文件字节无变化。
- 根因：缓存内额外 `map.txt` 是本应用 R8 9.0.32 映射，时间晚于 AAR 解压约 100 秒。QRing 原 AAR `proguard.txt` 第 44、626 行各含 `-printmapping map.txt`，R8 相对依赖规则路径写入缓存，之后 immutable 验证拒绝复用。
- 修改范围：`android/sdk-tools/IsolateQRing.java` 在已有生成 AAR 隔离过程中只去掉这两条映射输出指令；保留所有 keep/优化规则、类重定位、DSP/JNI 名称、其他文件和原始 AAR。遇到未知映射规则或数量变化即报错，便于厂商升级重新审核。应用自身 mapping 输出仍归 Gradle 管理。
- CI 最后一步同时执行 sideload/play 原生单元测试，验证 release 后可复用 SDK transform。未关闭 immutable 检查，未弱化发行签名、16KiB、权限或美国域名门禁。验证结果随后追加。
- Apple 1018 已上传处理完成并关联正式草稿；当前网页会话过期，已请求在内部浏览器重新登录。英文 Dashboard / Device / Data privacy 三张 1179×2556 截图已核验，尚未上传。Google 英文资料已保存，1018 AAB 尚未上传。文件选择接口不可用，已请求允许使用系统文件窗口，未绕过会话或提取凭据。
- 新 1018 两戒指真实活动/睡眠及美国同步反馈仍未收到；此前 1016 连接反馈不等于本次通过。

- 修复验证：生成 AAR 成功。22 个 JNI 库和其他非 Java/规则条目保持原字节，所有生成 Java JAR 与已接受 1018 完全一致，规则只删除两条确切映射输出。Play Debug 3.4 秒、正式 AAB 54.6 秒成功。
- 首次离线双渠道测试缺少未选用的 Flutter x86_64 引擎（10 秒，非 immutable 错误）；显式指定既有双 ARM 后 22 秒成功，两渠道各 8 suites / 38 tests / 0 failures / 0 errors / 0 skips；连续再执行 4 秒成功。Release 和两轮原生测试后新 transform 清单逐字节不变，无 map.txt。
- 完整 Flutter UTC 1105 / Asia-Shanghai 1105 全通过；analyzer 2.3 秒无问题，Dart format 192 文件零改动，发行 Python 25 项通过，git diff --check 通过。iOS 输入未改，Apple 已接受的 1018 IPA 和已成功 iOS CI 保持有效，不重复上传同构建号。
- 新正式 AAB 包名 cn.saydian.app.global / 1.0.1(1018)。JAR 签名、原上传证书及全部 22 个 arm64 ELF PT_LOAD >= 16KiB 校验通过。所有 DEX、Flutter、原生库和 manifest 与前份 1018 AAB 相同，仅依赖元数据和签名条目变化；旧实际权限检查继续成立。SHA256 `d097ac2ae4a2041991293b30d2d357d3fdb485bba459d441113e12dd05c00e78`，保存于 `build/store-us-1018/qring-cache-fix/app-play-release.aab`，前份保留。初次 jarsigner 成功输出为中文，英文字符串断言失败，改为显式英文后确认 jar verified，未改签名。
- 本次浏览器上传诊断找到正确受支持接口：filechooser 事件对象的 setFiles，而非 locator.setInputFiles。实际上传 65.5MB AAB 到 Google，现处优化阶段，不再依赖系统窗口。
- Apple 实时记录发现外部已于 10 月 14 日 18:36 提交 1018，审核 ID `c7e09585-0973-4c50-b7f1-1e8abb65d36c`，状态等待审核。视觉实查旧 global-dashboard-appstore-v2.jpg 含 AI wellness assistant、Health alerts、Watch，与当前 iOS 边界不符。按用户替换截图后重新提审要求处理这一审核项目，不动其他 App。
- 指定真实 iPhone 在本轮 devicectl 中仍不可用，未覆盖安装，新戒指美国同步实机反馈仍待。
- 实施记录首次通过 shell stdin 追加中文时出现 Non-UTF-8 编码错误，正文没有写入；随后通过文本 patch 完整追加。本地源码 checkpoint `9f8947a` 保留，未覆盖失败证据。

## 实际商店上传与最新用户验收范围

- 修复源码及本轮日志由已连接 GitHub API 发布，树 `ad41e801ca7689aefa2486abc43e396473548918` 与本地 ad0bd39 完全一致；远端 `69e1ecfe0845aab8e2ebfeedd2db1b9003b5c49e`，PR2 原分支 fast-forward 更新，未合入 main。原本地 checkpoint 保留，fresh tracking checkout clean。普通 Git push 因终端缺少凭据失败，未提取密码或伪称推送成功。
- Apple 旧审核 `c7e09585-0973-4c50-b7f1-1e8abb65d36c` 为替换截图而退回，仅此 App 的一项 1018。三张新截图实际上传、3/10 持久显示；6.5 英寸旧 AI/Health alerts/Watch 图片引用移除，原素材库保留。Apple 1.0.1 仍关联已接受的1018，新增 10-15 00:21 审核草稿，状态“可供审核”，最终“提交以供审核”按钮可用但未点击。截图自动持久保存；无新增账号、构建、邀请或其他 App 操作。
- Google 成功接受 65.5MB AAB，版本1018/1.0.1、min26、target36、2 ABI，包含 ReTrace 和原生符号。已保存到正式轨道发布概览，自动常见问题检查完成，显示“您的更改现在可以送审”，仅一项正式版1018未送审变化。没有点击最终“提交1项更改以供审核”。既有 en-US SayDian、2832字符说明、三张英文/Device截图、512图标和1024×500英文大图再次核对，未加入第四张错误态/旧About图。
- 用户最新明确回答“仍未测试，先完成上传和提审准备”，撤销本轮立即送审时机，保留最终测试后提交的目标。指定 iPhone 仍 unavailable；新两戒指数据及美国同步未实测。不能沿用1016的连接反馈作为通过，也不能把可供审核等同已提交或已上架。
- 公共 HTTPS readiness/database为OK，revision仍a5198b8；浏览器实读r3英文隐私、协议、支持及注销页。审核专用账号通过正常美国HTTPS邮箱/密码登录、本人资料回读及登出，密码/令牌未输出。完整账户删除及跨国令牌证明仍使用前轮已接受真实HTTP证据，本轮不删除审核账号。
- 本轮 native/auth Node 91项：90通过、1跳过，与前轮一致；没有新增厂商下载或模拟硬件通过。云端CI38596674403/38596665683目前质量与两时区鸿蒙成功，Android编译中，iOS排队，不能声称整轮CI完成。
- 额外公开注销页显示问题已形成服务器独立CSS候选：`form {display:grid}` 覆盖HTML hidden；修正后本地真实浏览器SMS隐藏、密码仍可见。生产尚未修改。观察到国内/美国自动发布均true，需要独立美国发布范围处理，不能盲合 main 引发国内升级。见服务器 `docs/implementation-log/2026-10-15-global-deletion-hidden.md`。
- 上传、草稿、Google预检查及截图证据保存于忽略的 `build/store-us-1018/`，无受保护登录字段的密码、原始健康数据或图片提交Git。接续先检查CI真实结论、独立美国页面修正及用户1018实机反馈，再进行最终送审。

## 最终自动检查与候选保全

- 完整源码 push CI `38596665683` 对 `69e1ecfe0845aab8e2ebfeedd2db1b9003b5c49e` 实际 conclusion=success；质量、UTC/Shanghai鸿蒙、Android和iOS全部success。Android已实际完成Release后两渠道原生单元测试，不再触发immutable workspace错误。并行PR CI `38596674403` 的质量/鸿蒙/Android成功，iOS取消，不能把该PR run称为整轮success；完整证明使用上述push run，不是推测取消原因。
- 注销CSS候选源码 `d8ac2d5abfac43d5ebadccfaf1ba33cd619fb5af`、tree `8a051840e715cbc74ff9be84d8529a4d9ad64f45` 与保留本地3af9d0b逐字一致，发布为独立草稿[服务器PR31](https://github.com/tangwu88/saydianserver/pull/31)，已附当前任务；未merge或触发中美生产部署。根级typecheck/test/build/API文档，58工具、62H5流程、38H5契约及44部署测试通过；API的25个实库测试本地跳过仍保留，不假称成功。实际本地浏览器使用真实US公开能力响应，隐藏SMS、保留密码表单；生产尚为原CSS。
- 本轮最终商店状态：Apple1018可供审核的未提交草稿，三张新版英语素材已保存；Google1018唯一未送审正式版变更，官方自动检查完成并允许送审。遵从用户“仍未测试，先完成上传和提审准备”，最终送审均未执行。
