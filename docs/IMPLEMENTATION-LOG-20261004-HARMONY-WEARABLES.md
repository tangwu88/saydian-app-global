# SAYDIAN Health 鸿蒙国际测试版实施与验证（2026-10-04）

当前版本为 **0.1.5（10）**，名称 **SAYDIAN Health**，包名 **cn.saydian.app.global.hm**，最低 HarmonyOS 5.0.5 / API 17。本轮交付未签名测试产物；没有鸿蒙手机，不提交应用市场。

## 范围与源码保护

基线 `8e053000aa0c238f0d05714d587cc1603f0eed02`，初始 fetch 后与原分支远端 0/0。隔离 worktree 为 `D:/Dev/SaydianHealthHarmony`，分支 `codex/harmony-health-20261004`。保留 F 盘原仓库及其未跟踪 `docs/QA-20261003-ANDROID-DEBUG-WINDOWS.md`，不隐式合并 main。天气继续暂缓。没有修改服务端接口、上传云服务器文件或拉取云端镜像；源码提交通过 Git 自动检查。

## 变更及预期行为

- 原生 Urion EB1 BLE：广播制造商数据/服务与协议握手识别，服务发现、通知订阅、有效电量握手全部完成才标记连接。每连接独立队列和 generation；分包合包、校验、重复包、超时退役、断连释放、旧回调隔离。名称只展示，不以 U19 名称冒充协议认证。
- W8/Yuc、W9/Vep、U19/Urion 独立路由；混合扫描 RSSI 降序、未知最后、同值保留稳定顺序。U19 能力按响应探测；不开放未经证实的 ECG，电量不能推定充电状态。
- U19 血压、心率、血氧、步数/睡眠日汇总、查找、校时、脉诊和动态血压设置已接入既有 EB1 命令。自主测量完成通知触发补读、本地保存和上传。BP 必须证明测量时间与有效窗口，无法验证的旧历史不会冒用读取时间；日汇总保存所属日期、读取时间和内容版本，不重复累加步数。脉诊保留设备原值；历史时间未确认时不伪装新测量。离开脉诊页取消本机轮询，手表结束操作仍在手表完成，不编造停止命令。
- W8 ECG 默认 60 秒，完整 SDK 样本不截断；250 Hz 依据所带 Yucheng 2.1.5 SDK 的 AITools 初始化证据，不推广至其他型号。SDK 过滤预览标记 suspect/rawVersion=1；完整原始数据和实际元数据保留，中断保存 invalid/interrupted。采样元数据不足或中断不标上传成功。ECG 历史可从本地及服务器分页读取，断开手表仍能查看。
- 私有 ECG gzip JSON 样本、SHA-256、样本数/采样率、文件凭据校验；先 CAS 持久化凭据，再提交批量记录，每条有效 ACK 才改 synced。文件回执不等于健康记录 ACK。元数据不足的旧记录不阻塞后面的可上传记录。离线、账号切换和迟到响应均保留正确归属与待上传状态。
- 第一方本轮健康、百科和关爱统一 `/global/api/saydian-app/v2`，不回退国内 V1。ECG 自身/关爱读取保持私有鉴权范围、SHA/数量/采样率验证；服务端每次校验成员关系及指标授权。
- 充电状态为未知/未充电/充电中/可靠已充满，低电量独立。W9 不可靠充满值保持未知，U19 仅电量所以充电未知。设备页可见且前台连接空闲时 10 秒刷新，请求合并，测量/升级及离开页面暂停。
- 百科使用当前语言的分类、列表、正文及既有安全图片解析。模拟器确实读取到中文三篇文章；“心率的原理”现有正文两字，标记待编辑，不补写。三篇内容未提供实际可验收图片；图片路径的既有解析/安全契约测试通过，含图片真实内容仍待验收。
- 关爱为成员概览→已授权指标→日/周/月、范围日期和详情，复用本人趋势及 ECG 组件；管理集中邀请、待处理、权限和停止共享。查询只读，不写本人记录；成员/账号切换清空旧值，后台返回前台及页面可见 30 秒校验权限，失败/撤销清理波形和旧记录。
- 精简新增页面/按钮和重复提示，新增八语言健康文案；组件显式接收 locale，解决冷启动恢复语言后子页面仍用英文的问题。心电历史标题补齐。

## 官方工具与可重复构建

官方 Windows DevEco Studio **26.0.0.851** 安装在 `D:/Dev/DevEcoStudio26`，SDK 编译版本 26.0.0.105，目标 API 26，兼容 API 17。官方下载 ZIP 3,295,837,057 bytes，SHA-256 `33ce2d302ecccdbc27287bd6523bd32c6f4da32c80d6c7f33057b83b1eefb9d9`，与下载页一致，安装程序 Authenticode 有效。Node/JBR/hvigor/ohpm 均使用该安装的工具。工具、模拟器镜像及任何凭据在仓库外。

从仓库根目录：

```powershell
./harmony-native/scripts/build-windows.ps1 -Flavor arm64 -OutputDirectory D:\Dev\HarmonyDeliverables
./harmony-native/scripts/build-windows.ps1 -Flavor simulator -SimulatorStage D:\Dev\SaydianHarmonySimulator\new-run -OutputDirectory D:\Dev\HarmonyDeliverables
python harmony-native/scripts/inspect-test-haps.py D:\Dev\HarmonyDeliverables
$env:TZ='Asia/Shanghai'; node --test harmony-native/tests/*.test.mjs
$env:TZ='Europe/Berlin'; node --test harmony-native/tests/*.test.mjs
node --test tool/test_native_log_privacy.mjs tool/global_auth_smoke.test.mjs tool/global_auth_account_qa.test.mjs
```

脚本依赖安装成功后，分别运行 `hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug|release assembleHap --no-daemon`。拒绝覆盖现有产物；模拟器副本去除 W8/W9 SDK 初始化、硬件适配器和 ARM64 第三方库，不生成健康记录。仅该副本有游客 UI 预览参数，未绕过鉴权。旧 Mac 国内包 `package-review.mjs` 不适用于本轮国际包。

## 检查结果与遇到的问题

- 双时区全量主机测试：**Asia/Shanghai 522/522、Europe/Berlin 522/522**。覆盖 EB1 校验/碎片/重复/多包、命令串行/超时/旧回调、时间证明、日汇总版本、RSSI/能力、批量 ACK/补传/账号切换、完整波形/未知元数据/中断及关爱鉴权隔离。并非实表测试。
- CI 附加的日志隐私、国际认证 smoke 边界和离线账号 QA：**87/87**。Git 工作流增加 Europe/Berlin，与 UTC、Asia/Shanghai 一起跑。
- 官方 ArkTS **ARM64 Debug/Release、x86_64 UI Debug/Release 全部构建成功**。仍有既有供应商 SDK 类型标注、重复资源及弃用 API 告警，不在本轮擅自升级 SDK。依赖工具最初 bootstrap 的上游 npm 高危传递依赖告警没有通过强制升级破坏官方工具链。
- 初次 x86 安装错误 `9568347 install parse native so failed`：ABI 过滤不足以排除支付宝依赖的 ARM64 `.so`，新增 nativeLib 过滤后修复。最终 UI 包没有任何 `.so`；ARM64 包保留完整 ECG 分析库。
- API 17 返回 200 但响应回调为空，导致百科加载失败：实际响应在 `response.body`。改为配置官方 onDataReceive 并对缓冲回退做端点大小限制。JSON 2 MiB、ECG gzip 25 MiB、解压 32 MiB；RCP 缓冲模式自身默认上限 50 MiB。补充 UTF-8/超限/二进制回归；正式修复的模拟器能显示三篇文章和正文，不依赖诊断日志。
- ArkTS 编译修复：显式返回类型与泛型设备命令，禁止对象展开，避免组件成员 `width`/`enabled` 与系统 API 同名。没有改动无关 Flutter 文件。
- DevEco IDE 启动未暴露可操作窗口，改用随附官方 CLI 完成构建、镜像安装及模拟器操作。官方 HarmonyOS 5.0.5(17) 手机模拟器 `SaydianHealthApi17`、hdc `127.0.0.1:5555`，可启动实际 UI。
- 签名配置为空。四个 HAP 经官方 `hap-sign-tool.jar verify-app` 均返回 **signature not found / No Hap Signing Block**，确认未签名。不得称 ARM64 真机可安装包；旧国内身份签名不能复用。本机模拟器成功安装不改变这个结论。

## 最终产物

本机目录 `D:/Dev/SaydianHarmonyValidation/final-0.1.5-10/`，清单 `manifest.json`。包身份、版本、API 编码 50005017、Debug/Release 标志、ABI、ZIP CRC 和签名凭据排除检查通过。

| 文件 | Bytes | MiB | SHA-256 |
| --- | ---: | ---: | --- |
| SAYDIAN-Health-0.1.5-10-arm64-debug-unsigned.hap | 23,286,795 | 22.21 | `d624a0fe65d7684e056441909a4af8692cb1d65f75fccd1994fb47584a82ce42` |
| SAYDIAN-Health-0.1.5-10-arm64-release-unsigned.hap | 16,668,291 | 15.90 | `a64de35e32b8c919d7e1c1fce079c5cfa8f21b4672342682e6a06c110c4d92a5` |
| SAYDIAN-Health-0.1.5-10-x86_64-ui-debug-unsigned.hap | 9,951,502 | 9.49 | `df5c91d809a2a58223dd32e2055b06f2ed24cf840d5d30f7e1468f58a35f3c23` |
| SAYDIAN-Health-0.1.5-10-x86_64-ui-release-unsigned.hap | 6,420,326 | 6.12 | `c25163480d2875c540fdd66e82d181c410a6ec77dde40c7e290ed5bd729514c9` |

## 模拟器证据与验收边界

最终 UI Release 安装并启动成功，登录语言选择/恢复简体中文、首页无健康记录、设备未连接页、全部数据空态、关爱未授权空态、心电历史标题及空态完成页面检查。健康百科中文分类/三篇列表及睡眠文章真实正文已显示，可滚动；原两字文章保留。截图和布局在 `D:/Dev/SaydianHarmonyValidation/ui-candidate/` 与最终 `ui-delivery/`，不含账号密码或伪造测量。

没有有权查看真实成员健康数据的鸿蒙 QA 登录会话：成员有数据的日/周/月趋势、真实 ECG 展示及图片内容仅有代码/契约证据，不能写成完整 UI 或服务端端到端验收。暂无鸿蒙手机，以下全部 **待真机**；Android 结果和模拟器结果均不替代：

| 型号 | 固件 | 待验收 |
| --- | --- | --- |
| U19 | 待读取 | 扫描身份、连接/断连/重连，手表自主 BP/HR/O2 自动保存与逐条 ACK，BP 时间证明，步数/睡眠日汇总版本，脉诊/动态 BP 设置回读 |
| U19S | 待读取 | 同上，独立记录能力与固件响应，不由 U19 推定 |
| W8 | 待读取 | 60 秒完整 ECG/中断/重连/离线补传，SDK 实際波形和采样率，服务器样本数及 SHA 一致；充电插拔/可靠充满在刷新周期内更新 |
| W9 | 待读取 | ECG 实际元数据、完整波形/上传/私有读取；充电插拔、未知与可靠充满，SDK 回调路由 |

还需独立国际调试签名、本人/成员同期间数据对照、真实权限撤销、双账号切换和 ECG 越权访问的在线验收。当前 Windows 没有执行 iOS 验证，本轮仅更改原生鸿蒙工程，不能声称 iOS 验收通过。服务器继续 Git 自动部署；本轮未增加服务器改动。
