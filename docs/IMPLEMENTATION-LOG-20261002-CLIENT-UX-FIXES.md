# 2026-10-02 国际版客户端连接、资料与页面问题修复

## 范围与原因

用户反馈国际版客户端存在五项问题：设备超距断开后靠近不能自动恢复、个人资料保存失败或结果不可靠、客服入口不可用、英文界面 AI 标题仍为中文、远程关爱重复标题。

修改前检查：工作区干净，当前分支 `codex/global-device-admin-20261001`；`git fetch --prune origin` 成功，HEAD 与跟踪分支均为 `add0a4078659d0efb2af43cc5185fbf31a08109b`。

第一次 `git fetch --prune origin` 曾遇到 GitHub TLS 连接中断，重试成功后才继续。第一次运行 `flutter test --no-pub test/global_localized_pages_test.dart test/login_page_test.dart test/app_controller_account_wearable_test.dart test/app_controller_wearable_restore_race_test.dart` 时，机器上的 `.pub-cache` 缺少多个包而无法编译；执行 `flutter pub get` 后依赖恢复，`pubspec.lock` 没有产生差异。之后一次测试运行发现测试替身缺少 `aiStatus` 并有一条“标题只出现一次”的错误断言；补齐 Fake 字段并改成多处出现也通过后重跑通过。

## 修改内容

- `lib/services/app_controller.dart`：物理断线后仅在此前确有连接、隐私同意有效且未显式断开时启动恢复；前台首次延迟 1 秒，失败后间隔按 5/10/20/30 秒递增并封顶；应用后台时停止重试，恢复前台后继续；手动断开、选择重连设备、账号切换和控制器释放时取消重试。个人资料写入后直接回读并逐字段比对，失败不再误报成功；头像上传期间增加登录代次/账号归属检查。
- `lib/ui/pages.dart`：身高范围与服务端约束统一为 50–250 cm；健康助手与对话空态使用本地化资源；国际客服路由传入控制器。
- `lib/ui/prototype_pages.dart`：国际客服页面按现有反馈接口提供“帮助与反馈”入口，不展示国内电话/微信；隐私安全提示保留。
- `lib/ui/global_care_page.dart`：移除内层标题栏，沿用外层页面标题。
- 测试新增断线重试、英文 AI 文案和远程关爱标题检查，并更新资料 API 测试替身以验证回读。

## 验证记录

- `dart format`：通过。
- 定向 Flutter 测试：通过（53 项，包含 AI/客服/远程关爱/资料保存/自动重连）。
- `flutter analyze --no-pub`：通过，零问题。
- `flutter test --no-pub`：通过，937 项。
- `TZ=UTC flutter test --no-pub --reporter compact`：通过，937 项。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：通过，937 项。
- 首次定向测试中测试替身缺少 AI 状态、页面断言误认为首页两张卡只有一个标题；补齐测试替身并改为检查英文文案后，定向测试通过。
- 全量双时区测试后增加客服入口跳转验证和不支持恢复桥接时的重试保护；再次 `flutter analyze --no-pub` 零问题，定向测试命令 `flutter test --no-pub --reporter compact test/global_localized_pages_test.dart test/app_controller_wearable_restore_race_test.dart test/login_page_test.dart` 通过（44 项）。
- 随后将重试间隔调整为 5/10/20/30 秒上限；最后 `dart format lib/services/app_controller.dart` 无格式差异，`flutter analyze --no-pub` 零问题；`flutter test --no-pub --reporter compact test/app_controller_wearable_restore_race_test.dart test/app_controller_account_wearable_test.dart` 通过（12 项）。
- `flutter build apk --debug --target-platform=android-arm,android-arm64`：首轮因访问 Google Maven 下载 `com.android.tools:sdklib:32.0.1` 时 TLS 握手中断失败；Flutter 自动重试时可用磁盘空间降至 592 MiB，为防止写满磁盘而中止。未生成可验收 APK。
- Android QA Release、iOS Debug/Profile：未执行。停止重试后系统只余约 672 MiB 可用空间，不满足这些原生构建的安全空间余量；未清理用户缓存或构建目录。
- iPhone / 手表现场超距断开与重新靠近：本轮未操作实机，须在可穿戴设备在场时复验；模拟桥接测试不等于 BLE 真机验收。
- App Store 上传或审核状态未改变。

## 后续边界

自动恢复依赖设备厂商桥接仍保存已绑定设备标识；用户主动断开会清除恢复许可，不会擅自重新连接。此轮只验证客户端不再隐瞒资料写入后的读取/字段校验失败，不代表服务端存储异常已经被证明或线上配置已更改。

## 2026-10-02 iPhone 15 Pro Max 安装与 Debug 复测

- 设备检查：已识别 iPhone 15 Pro Max（iPhone16,2，iOS 26.6），有线配对、开发者模式开启，设备 UDID `00008130-001C098C2290001C`；Xcode 可见团队 `W7SXQ4A226` 的有效 Apple Development 证书及该设备 Ad Hoc 配置。
- 旧构建检查：现有 IPA/归档时间为 2026-10-01，晚于当前本地 UI/连接修改前；其中 App Store 签名 `get-task-allow=false`，不具备 Flutter VM 调试能力，因此未将旧包冒充当前源码 Debug 包安装。
- 构建：首次以 Xcode CoreDevice 标识传给 Flutter 时未匹配设备；改用 Flutter 列出的设备 UDID 后启动 `flutter run --debug --no-pub --device-id 00008130-001C098C2290001C`。Xcode 自动签名已开始，Objective-C/Swift 插件编译至后段，但机器同时运行另一仓库的 iOS Release 归档，系统盘可用空间跌至不足 200 MiB；当前 Debug 构建因无法写入 `Runner-primary.priors` 与 xcresult 以“volume out of space”失败。
- 安装/运行/调试：未生成完整可执行 Debug App，故本轮未安装、启动或连接 Dart VM/DevTools；不得视为真机 Debug 通过。iPhone 原有安装状态未由本次命令更改。
- 安全与后续：未终止其他仓库构建，未清理缓存或构建目录。需先由正常流程释放足够磁盘空间（建议至少 3 GiB 可用），再运行同一 Flutter Debug 命令完成增量构建、安装、启动及 VM 服务验证。

### 同日增量重试结果

- 磁盘空间随后自行回升至 3 GiB 以上；未执行清理或中断其他仓库任务。第二次运行 `flutter run --debug --no-pub --device-id 00008130-001C098C2290001C`，Xcode 真机 Debug 构建成功（75.5 秒），已自动签名并安装/启动 `cn.saydian.app.global`（`get-task-allow=true`，Apple Development 证书，版本 1.0.0 / build 1012）。
- Flutter 调试确认：终端成功输出 Dart VM Service `http://127.0.0.1:56306/BmvS-QyJ82E=/` 与 DevTools 地址，并显示 hot reload/restart 控制；`flutter run` 持续附加，应用进程在 iPhone 上运行。Xcode 的设备共享缓存警告已出现但未阻止调试服务建立。
- 运行烟测：应用启动并访问国际域 `app.saydian.cn`；更新清单接口返回 404（非启动阻断，版本清单线上能力待处理），多数启动业务 API 请求收到 200/201；另有两个 POST 请求返回 503（日志仅含脱敏 route hash，路径未暴露，需后续按 request ID 查服务端日志）。未主动执行健康数据上传。系统键盘输出一条 UIKit keyplane 约束恢复警告，未阻止页面启动。
- 结论：当前源码的 iPhone Debug 安装、启动和 Dart VM/DevTools 附加通过；先前满盘失败保留为失败记录。超距重新靠近及手表硬件行为仍需现场复验，不能由本次应用启动代替。

### 2026-10-02 真机调试会话重连

- 用户再次要求启动 iOS 真机调试。此前 Flutter 会话已报告 `Lost connection to device` 并正常退出；iPhone 15 Pro Max 仍有线在线、解锁、开发者模式开启。
- 两次普通 `flutter run` 重连，以及一次 `--no-dds` 尝试均出现 Xcode `libobjc` 共享缓存警告；部分尝试在等待 VM 服务期间由设备端以 SIGKILL 终止。单独用 `devicectl --console` 启动 Debug 包也失败，设备日志说明 Debug FlutterEngine 需要 Flutter tooling 或 Xcode，此路径不用于验收。
- 查到 Xcode `iOS DeviceSupport/iPhone16,2 26.6 (23G71)` 仅含 0 字节处理标记、简短 plist，无实际支持文件；未删除该目录，而是可恢复地改名保存在 `/Users/saydian/Library/Developer/Xcode/iOS DeviceSupport/.quarantine-iPhone16,2-26.6-23G71-incomplete-20261002`。改名后没有确认 Xcode 重建该目录，不能断言它是唯一根因。
- 之后以 `flutter run --debug --no-pub --device-connection attached --device-id 00008130-001C098C2290001C` 启动成功；等待约 111 秒后 Flutter 输出 Dart VM Service `http://127.0.0.1:57801/C76BYaqu8NA=/` 及 DevTools。通过终端发送 `r` 验证热重载，输出 `Reloaded 0 libraries in 379ms`。此 Flutter 会话保持附加。
- 启动期间更新清单仍返回 404，业务 API 多数返回 200；没有执行手表超距测试或健康记录上传。此次只确认真机调试连接恢复，不扩大为逐页/硬件验收。

### 2026-10-02 英文界面真机逐页回归及修复

- 真机：iPhone 15 Pro Max，iOS 26.6；读取设备渲染树生成 1290 × 2796 PNG（不包含 iOS 系统栏）。完整基础回归通过，23 张页面截图保存在 `build/ios/real-device-qa-20261002/screenshots/final-qa/`。
- 截图失败记录：Flutter integration test 原生截图通道在前两轮只产出纯白图，故拒绝作为视觉验收；改为从实际 App 根渲染边界抓取后，真机画面尺寸正确、内容可见并用于下述复核。
- 通过页面：首页、消息、远程关爱、健康百科、健康预警、AI 助手空态、心率趋势（日/周/月）、全部健康数据、设备页/设备详情、资料页/资料编辑、单位、账号、权限、反馈、客服、关于、隐私政策、服务条款、语言选择。
- 真机发现并修复：消息空态及权限名称/状态混入中文；健康百科把中文文章展示在英语界面；手表连接恢复期间首页先误报“连接手表”；未知充电状态展示了不自然的开发式字符串。现在分别本地化、对非匹配语言内容安全降级、连接恢复中展示明确状态、未知充电状态使用本地化“不可用”。英文夹中文和条款页面回归后截图已复核。
- 扩展回归首次运行进入血压/血氧/睡眠趋势及历史、手表监测/脉搏分析/显示/手表设置/连接帮助；个人资料编辑网络加载阶段驱动长时间无响应，手动停止该次运行，作为失败/中断尝试保留。随后为资料页导航加入有限等待和步骤日志，并改用独立截图目录重跑；完整运行 2 分 24 秒通过，资料读取 API 返回 HTTP 200，编辑器正常打开/关闭，未复现卡住。此前中断记录不等同于本次重跑结果。
- `flutter analyze --no-pub`：通过，无问题。`flutter test --no-pub --reporter compact`：940 项通过；新增英文百科混合语言测试后定向测试 27 项通过。
- 最新普通真机 Debug 已重新构建、安装和启动，Flutter 输出 Dart VM Service `http://127.0.0.1:62883/Qu-ziunKDBQ=/` 与 DevTools 地址，`flutter run` 当前保持附加。Xcode 仍报告设备共享缓存缺失警告，但本次 VM/DevTools 已成功；没有用这条警告代替连接结果。
- 页面只读运行期间应用启动/恢复流程自行执行了一次手表日常同步 POST，服务端返回 201；不是 QA 人员点按“同步”。启动业务 GET 多数返回 200；应用更新清单 GET 返回 404，暂不影响启动但需后台补齐。客服页面仍如实显示“功能暂时不可用”，其客服目标/服务端能力未配置，未编造电话、邮箱或社交账号。
- 不适用或未执行：手表测量、断开、查找、写入配置/表盘、提交反馈、添加关爱成员、下单/付款、账户删除。U19 设备当时电量 10%；零健康读数页面按真实空数据检查，不以合成数据伪造正常读数。
- 扩展真机逐页复测：完整测试驱动通过，36 张截图保存在 `build/ios/real-device-qa-20261002/screenshots/final-expanded/`。36 张均已视觉检查；血压/血氧/睡眠趋势及健康历史、设备监测/脉搏分析/显示/设置/连接帮助、资料编辑等页面正常渲染。单位、语言选择、账号、权限、反馈、隐私/条款、关于等页文案与布局可见。截图审查发现权限页按钮一律标为“Settings”，但未永久拒绝时实际调用的是权限请求；已修复为按状态显示“Allow”或“Settings”，对永久拒绝/受限/通知权限与已授权项才打开系统设置。新增英文权限页动作文案断言后，`flutter test --no-pub --reporter compact test/global_localized_pages_test.dart` 通过（27 项），`flutter analyze --no-pub` 零问题，`git diff --check` 通过。真机没有点按授权按钮，避免改动手机隐私设置；修改已通过 Flutter 热重载同步到当前 iPhone Debug 会话。截图中的健康读数仍为空；不把空数据当成设备数据验证通过。
- 本轮覆盖的是首页、消息、关爱、健康/趋势/历史、手表、个人资料与帮助/设置/协议等可安全只读页面；商城购买/支付、预警/监测配置保存、反馈提交、关爱成员写入、账号退出/删除、手表测量/查找/断开/写设置等变更型交互未执行，因此不宣称所有写入状态或业务分支均验收通过。U19 手表当时电量 10%，避免进一步耗电控制测试。
- 扩展轮后再次启动普通 `flutter run --debug --no-pub --device-connection attached --device-id 00008130-001C098C2290001C`：真机增量构建/安装启动成功；等待 125.2 秒后发现 Dart VM Service `http://127.0.0.1:49992/Kv-oKDuP0UY=/` 与 DevTools。热重载实测 `Reloaded 0 libraries in 284ms`，会话随后保持附加。`flutter analyze --no-pub` 与 `git diff --check` 均通过。Xcode 仍提示该设备的 LLDB 共享缓存不在磁盘，但不妨碍本次 VM/DevTools 附加。
- 该次普通 Debug 冷启动及随后恢复流程由应用自身触发每日汇总同步 POST，线上均返回 201（冷启动 request ID `51410a1b-8c6b-4bff-add1-4837d981022a`；后续 request ID `30a655e7-0fa1-42ae-bd62-9f72ac0cfa74`）；没有人工触发同步或重试。更新清单 GET 再次为 404；客服可用性未解决，需服务端配置/修复。

### 2026-10-02 用户提交截图跟进：资料保存提示与客服页面

- 收到并逐张检查两张用户截图，原图只读保存在 `build/ios/real-device-qa-20261002/screenshots/user-reported/`。第一张包含个人资料，未在报告中公开其资料字段。
- 个人资料截图证据：头像被选中待保存，点击保存后出现英文通用错误。客户端国际 API 会有意把后端错误脱敏成英文通用句；中文页 `_safeUiError` 原先只在非中文页面过滤中文，没有过滤反方向的英文，因此泄漏英文提示。现改为按中/英文 UI 匹配回退文案，并新增中文保存失败回归（在中文界面模拟英文通用 API 错误，最终只显示中文“保存失败”）。截图不含接口、HTTP 状态或 request ID，故无法确定该次实际失败是在头像上传、资料 PUT 还是回读；未重试/写入该真实账号资料。
- 客服截图证据：国际版客服页硬编码通用“暂不可用”卡片，与同页可用的“帮助与反馈”入口相矛盾。只读检查生产公开 `/global/api/saydian-app/v2/support/config` 在本次请求返回 `configured: true`；其发布值是国内电话/微信渠道，国际版现有安全测试要求不向全球用户展示国内客服号码/账号。未修改后台联系渠道，也未虚构国际渠道；改为本地化引导从页面上方“帮助与反馈”提交问题，保留不向非官方账号发送隐私资料的提示。
- `flutter test --no-pub --reporter compact test/login_page_test.dart test/global_localized_pages_test.dart`：45 项通过；`flutter analyze --no-pub` 无问题；`git diff --check` 通过。当前 iPhone 上的 `flutter run` 会话仍在，但本次发出热重载后停留在 `Performing hot reload...`，VM 地址检查也超时；设备上 Runner 进程仍在，不能据此声称两张截图对应的最新文案已在真机上视觉复验或本次热重载成功。源码/组件测试通过，真机热重载结果待调试通道恢复后确认。该会话后台还观察到一次应用自动发出的 POST 并获 201（request ID `bd2b1828-7046-46a6-89b5-841f0ac096d2`），没有人工点击上传/同步。
