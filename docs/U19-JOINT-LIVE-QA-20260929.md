# U19 Android 与国际服务联合复核（2026-09-29）

## 基线与边界

- 工作区 `F:/xcodeplace/saydian-app-u19`，`feature/u19-eb1`；修改前 `HEAD=2bee33e273afa0c57e136e209b21e4d5b3612f7c`，`git fetch --prune origin` 后工作树干净且与远端 `0/0`。国际仓库为 `tangwu88/saydian-app-global`。
- 华为 Android 手机通过 USB 在线，已安装国际 Debug `0.1.23+1007`，现有登录与本机记录均保留；不清库、不重置手表、不启动血压或其他测量、不改手表设置。本次生成的截图、原始日志、APK 留在忽略的 `build/`，不入 Git。
- 先前[真机记录](U19-ANDROID-LIVE-QA-20260929.md)中的 GATT 服务发现无回调、约 25 秒超时是真实失败，不能因本轮成功而删去或宣称根治。服务端任务“导入 saydianserver 项目”负责服务端契约、隔离环境与部署；App 任务没有修改服务端工作树或触发生产发布。

## 真机复验

手机当地时间为 EDT；只记录操作与状态，不记录设备地址、账号、健康原始值。

| 时间 | 操作与证据 | 结论 |
| --- | --- | --- |
| 01:23 | 现有 App 画面为 U19 已连接、电量 43%。 | 最终 Debug 包后来自动恢复连接；上一份记录截止时的超时状态不是永久状态。 |
| 01:24 | 点击 `Sync watch`；通知与写入回调正常，`[U19Sync] daily: index=0 dayOffset=0`。随后国际域名上的日汇总能力查询返回 404。 | 手表当天数据可读；云端仍未接受日汇总，不计为上传/回读通过。自动同步前校时代码已在最终包执行路径，但未取得本轮手表时钟实体回读，不能单凭 `dayOffset=0` 宣称时钟值验收。 |
| 01:26 | App 内断开、重新扫描并精确选择同一 U19；`state=0/2`、服务发现 `status=0`、CCCD 订阅 `status=0`、`ready`，随后当天汇总 `dayOffset=0`。 | 第 1 次受控断开—扫描—重连—只读同步通过。 |
| 01:28 | 重复上一步；服务发现与通知订阅成功，`ready`，当天汇总 `dayOffset=0`。 | 第 2 次通过。 |
| 01:30 | 第三次断开后初次触点未选中设备；以新截图核对列表位置后再次精确选择 U19。服务发现与通知订阅成功，`ready`，当天汇总 `dayOffset=0`。 | 第 3 次通过；未误连其他型号。结束时 App 保持 U19 已连接。 |

三轮证明当前现场可以完成连接及读取，但先前同一包的多次 GATT 无回调失败仍未定位。`UrionGattTransport.kt` 在第一次服务发现尚无回调的 7 秒时再调用 `discoverServices()`，这可能存在重入风险，但本轮没有充分证据证明它就是根因；因此未作猜测性 BLE 修改或延长超时。

## 国际服务契约

- App 实际调用 `GET https://app.saydian.cn/global/api/saydian-app/v2/health/capabilities`，需返回 `data.dailySummaryVersions=true` 才上传 U19 每日汇总。2026-09-29 实测该路由 **404**；同域 `auth/capabilities` 为 200，`/health/ready` 为 200 且 `revision=7d355a4ee65146c16f2e056cafe4cf1813cefc92`。开始曾试探无 `/health` 的错误路径 `/global/api/saydian-app/v2/capabilities`，也为 404；已以源码核对并改用正确路由复验。
- 真机脱敏网络样本中上述失败请求仅到 `app.saydian.cn:443`；这只是本轮采样，非全 App 全链路域名审计。无服务端 `acceptedIds` 或重新读取证据；如果本机已有非零日汇总，应按客户端能力门禁留待同步。本轮手表恢复出厂设置后 App 未显示可核实的非零步数/睡眠记录，不能臆测待上传条数，更不能记为上传成功。
- 已向独立的“导入 saydianserver 项目”任务发送精确路由、期待字段和线上 revision，请其给出隔离测试地址、契约/数据库折叠测试和部署版本；不能以设备表 `capabilities` 或普通登录能力接口替代日汇总能力声明。

## CI 格式门禁收口与回归

- 上一提交 `2bee33e` 的 [mobile-ci #36525411897](https://github.com/tangwu88/saydian-app-global/actions/runs/36525411897) 仍失败；前一次 #36525165239 已证实 `quality` 因 6 个历史文件格式不符退出，Android/iOS jobs 被跳过。`dart format --output=none --set-exit-if-changed lib test` 在本轮再次列出同 6 个文件，退出 1，工作树未改变。
- 仅对门禁点名的 `lib/services/local_health_store.dart` 和 5 个测试文件执行 `dart format`，意图只修复机器格式而不改数据语义。随后全仓同一格式命令显示 `Formatted 156 files (0 changed)`，退出 0；`git diff --check` 通过。测试复验结果如下。
- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub --reporter compact`：本地时区 **927/927**；`TZ=UTC` 同命令 **927/927**。
- Android `:app:testDebugUnitTest --offline --no-daemon`：BUILD SUCCESSFUL；Harmony `node --test --test-reporter=dot harmony-native/tests/*.test.mjs`：通过。均不代替 iOS/Harmony 真机。
- Android Debug 与内部 QA Release 的双 ARM APK 构建均通过，包名 `cn.saydian.app.global`、显示名 `SAYDIAN Health`、版本 `0.1.23+1007`。Debug SHA-256 `3D4D462834A11041CC37B9864F54DF11CD15B84824E39A63705568497CFEE171`；QA Release SHA-256 `FB3E516BE9102C67C5688515161B8D53F509356EAA26AF9CE58ABE22C1B5B0D9`。QA Release 不是正式商店签名。本轮没有因纯格式变更重新覆盖安装手机；真机证据来自已安装的同功能 Debug 包。
- Windows 无法执行 iOS Debug/Profile 构建；需以新 CI 的 macOS job 结果单独复核。Flutter/Gradle 的未来 Kotlin 兼容及 SDK XML 警告未阻塞当前构建，也未在本轮改动无关插件。

## 保留问题与下一轮

1. U19 GATT 服务发现间歇超时仍为 P1。需要在可复现的失败现场增加状态取证、验证是否有未完成的旧发现操作；不能只增加等待时间或绕过服务/通知校验。
2. 国际服务日汇总能力与版本折叠未部署/未验收，当前准确路由 404。待服务端任务给出隔离环境及契约后，用已登录授权测试账号核对“手表→本机待同步→服务器接受→重新读取”，不上传未经确认的健康原始数据。
3. 格式门禁修复提交后核对新 CI，只有 Android/iOS 作业确实完成才能标记平台云构建通过。iOS 和 Harmony 实机仍未验收。

## 追加：步数入口与服务发现恢复（手机当地时间 02:04–02:25）

### 问题、范围与修改

- 复现：U19 能力含步数，但“全部健康数据”没有步数行；英文界面的历史原始单位 `步` 也可能直出。新增 Widget 测试先失败于找不到 `Steps`。仅在能力或已有记录允许时增加步数行，并把该单位按现有八语的步数名称显示；未恢复 U19 不支持的运动模式。
- 复现：覆盖安装后的冷启动能扫描到目标 U19；02:06:24 GATT 连接状态为成功，02:06:24.671 `discoverServices()` 返回 `true`，随后 7 秒在同一 GATT 上重发仍无 `onServicesDiscovered`，02:06:48 达到原 25 秒总超时。用户在 App 内再次选择同一目标，建立**新** GATT 客户端后 02:08:54 服务发现、通知订阅和读取均成功。Android 官方 `discoverServices()` 是异步操作，成功返回表示已启动，完成仍须等 `onServicesDiscovered`：[BluetoothGatt 文档](https://developer.android.com/reference/android/bluetooth/BluetoothGatt)。
- 据此将无回调时的同连接重发改为：仅一次关闭旧 GATT、等待排空，再建立新客户端；保留同一 25 秒总超时、会话代数检查和服务/特征/通知全部校验。旧回调不能完成新会话。不改 Veepoo/玉成连接、不延长无界等待。该恢复分支尚未在新包真机故障现场触发，不能标为根治。
- 服务端任务“导入 saydianserver 项目”已收到精确路由、客户端 `aggregation` 契约和“无非零样本”边界。追加复核时 `/health/ready` 已变为 `3dab610c447ad2ce92e63b73ed65c3781580b46b`，但线上日汇总能力路由仍为 404；已把新版本号和阻塞反馈服务端任务。服务端会话/工作树由独立任务处理，App 任务没有发布服务端。

### 逐项验证与边界

| 步骤 | 结果 |
| --- | --- |
| 定向 Widget 回归 | 新测试先失败 `Steps` 不存在，修改后通过；连接 U19 仅支持 BP/心率时，历史旧手表步数不显示为当前功能。英文步数行与历史详情不显示中文单位。 |
| `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze --no-pub` | 156 个文件检查 0 变更；静态检查无问题。首个 `flutter` 命令因当前 PowerShell `PATH` 未包含 Flutter 而未启动，改用已核实的 `D:/Dev/Flutter/3.44.9/bin/flutter.bat` 后执行，不把命令未启动记为测试失败。 |
| `flutter test --no-pub --reporter compact` | 补充“不支持步数时隐藏”的断言后，定向测试通过；本地时区 928/928、`TZ=UTC` 928/928 再次通过。 |
| Android `:app:testDebugUnitTest --offline --no-daemon` | BUILD SUCCESSFUL。Flutter/Gradle 与旧插件兼容警告未阻塞，不在本次范围修改插件。 |
| Android Debug、内部 QA Release 双 ARM 构建 | 均通过；Debug SHA-256 `BCFB7AA6FD8D77BBB1D0A32DE725FFB4B2E8655F254A511C4AD5C1E1E6054B17`，QA Release `1A4551E49D76FAA850B38E986CFA3CDDDA0898746BBDD7D37B2779F173A8BE0E`，产物不入 Git。QA Release 不是商店签名。 |
| Android 覆盖安装与页面 | 两次 `adb install -r -t` 返回 Success，手机安装器的两级“继续安装”按既有用户授权确认，未卸载、未清数据。第一次安装的修正版可见 `Steps`/`steps` 和详情入口，因当前无可核实非零记录显示 `No data yet`，不伪造数值。第二次安装含 GATT 改动。 |
| 新包 U19 真机 | 02:21 与 02:24 两次建立连接、服务发现 `status=0`、CCCD `status=0`、`ready`、当天汇总 `dayOffset=0`；两次均未触发新恢复分支。扫描列表位置会变化，曾有一次坐标点错但未启动其他设备连接，重新核对目标后成功。结束保持 U19 连接。 |
| 服务端能力 | `GET https://app.saydian.cn/global/api/saydian-app/v2/health/capabilities` 仍 404；未取得 `acceptedIds`、GET/统计折叠及真实非零样本回读，联合数据闭环未通过。 |

App 源码提交 `06b9337` 的 [mobile-ci #36532199650](https://github.com/tangwu88/saydian-app-global/actions/runs/36532199650) 最终 quality/Android/iOS/Harmony 作业全部通过。Windows 未做 iOS 本地构建；iOS/Harmony 实机、GATT 故障分支的成功恢复以及云端日汇总继续列为未验收。

## 追加：服务端隔离分支交接（2026-09-29）

- “导入 saydianserver 项目”任务已在独立分支 `fix/global-health-daily-summary-capabilities` 提交 [`ef51e66`](https://github.com/tangwu88/saydianserver/commit/ef51e665babdc3c9e5cd1b7a7dbb24e918c84695)，[草稿 PR #1](https://github.com/tangwu88/saydianserver/pull/1) 供审阅。[服务端 CI #36534031343](https://github.com/tangwu88/saydianserver/actions/runs/36534031343) 的 `verify` 成功，`auto-deploy` 为 skipped；这不是生产部署。
- 服务端新增受国际会员鉴权的 `GET /global/api/saydian-app/v2/health/capabilities`，预期标准 V2 响应的 `data.dailySummaryVersions` 为 `true`。服务端专项、API、数据库迁移与容器验证由其任务记录；本 App 任务未冒用其测试为真机云端通过。
- 服务端已按反馈将关爱历史的日汇总日期窗口改用 `foldedHealthRecordPeriodWhere(from,to)`，避免只按补读时间筛选旧日汇总。App 侧发送的 `aggregation: {kind: daily_summary, localDate}` 和 `source.deviceId` 契约已与服务端当前源码对照。
- 再次实测生产 `/health/ready` revision 为 `3dab610c447ad2ce92e63b73ed65c3781580b46b`，上述能力路由仍 HTTP 404。未获得可用的隔离远程测试 URL、服务端部署和真实非零 U19 数据前，不上传、不虚构 `acceptedIds` 或重新读取结果。下一步先取得明确部署/隔离环境授权，再按真实设备数据完成端到端联验。
