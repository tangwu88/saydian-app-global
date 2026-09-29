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
- 真机脱敏网络样本中上述失败请求仅到 `app.saydian.cn:443`；这只是本轮采样，非全 App 全链路域名审计。无服务端 `acceptedIds` 或重新读取证据，日汇总继续留本机待同步，不得记为上传成功。
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
