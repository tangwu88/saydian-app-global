# 2026-10-18 国际版 iPhone 戒指同步接续

## 范围、现场与保护

用户要求开启 iOS 真机调试，分别验证 LuckRing / QRing 的设备读取、本地待传、美国服务器 ACK、回读及重复同步去重，发现问题立即修复。
用户随后选择先测试 QRing，并提供 U19S 资质文件；资质与两戒指验收分别记录，不扩大 iOS 活动/睡眠产品范围。

起始 HEAD `7aa515c4f5fc76bd89a70f1e212a3eabae0dfd2a`，本地分支 `codex/global-update-20261018`，跟踪 `origin/codex/ios-debug-restart-20261017`。
起始工作树干净，fetch / ff-only pull 成功，Already up to date；运行输入相对 `69e1ecf` 无差异，保留原分支及所有发布材料。
指定设备仍为 iPhone 15 Pro Max，UDID `00008130-001C098C2290001C`，实时 USB wired / iOS 26.6 / DDI available / Developer Mode enabled。

同一手机已有另一个 Say Ring Debug 会话，本轮没有中断其 Flutter/LLDB 或卸载其他 App。
Health 未运行时，通过 devicectl 将本 App 的 Application Support 复制到新私有目录：两个加密库共 540672 bytes，无 sidecar。
不解密数据库、不导出 Keychain、不回写旧副本，不清空账号、设备绑定或健康记录；没有覆盖安装。

## 现装 1019 的原生附加

devicectl apps 查询本轮多次成功但返回空列表（包括 include-all / 指定 Bundle），不能据此判断 App 不存在。
该 Bundle 的数据容器可读；按 Bundle 启动并核对 NSBundle，而非根据另一个 Runner 进程猜产品。

`devicectl device process launch --start-stopped cn.saydian.app.global --enable-dart-profiling --enable-checked-mode --verify-entry-points` 成功。
LLDB `device select` 指定 UDID、`device process attach -p 44228` 成功；临时 main 断点下读取实际 `cn.saydian.app.global / 1.0.1 / 1019`。
本机同步源码仍为 1018，因此不降级安装、不将旧源码注入 1019。临时断点已禁用并继续运行，安装路径与本轮启动结果匹配。

原计划复用的 `build/ios-debug-20261016-us/Runner.app` 和旧私有临时目录已经不存在，没有将其他历史包冒充当前包。
一次 Flutter attach 只到等待 VM 阶段，随即停止：本机工具源码确认 Debug attach 会初始化 DevFS / 同步 kernel，未对不匹配源码继续该路径。
没有发生该次 attach 的连接、文件同步、热重载或重启，不能报告 Flutter 热重载通过。

使用本 App 明确命名的 mDNS 服务，结合官方 iproxy 和现有 LLDB 接通 VM，不修改系统权限或安全配置。
直接运行 iproxy 的两次失败分别是缺少 loader library 路径、随后缺少 glue library；按 Flutter 自身做法设置三个 SDK library 目录后成功。
VM getVM HTTP 200 / main isolate 存在；实际 AppController 唯一、已初始化、已登录且不是预览，实际 API 实例为 `https://app.saydian.com`。
通过既有实例字段核对当前资料不是审核专用账号，不输出用户名、会话令牌或真实健康值。

独立 DevTools 本地服务 HTTP 200。面板打开请求未返回而主动终止等待，不声称已目视核对面板。
普通 Dart evaluate 因缺少当前 1019 的表达式编译服务失败；随后只读取 VM 对象字段、调用现有编译方法，不注入 1018 kernel。
原生 LLDB、专属 VM USB 转发及 DevTools 服务保持运行；本轮无 Flutter 热重载验收，不能当独立发布形态冷启动验证。

## 已发现并修复：QA 回读使用历史域名

P1 / 测试链路隔离问题：`ios_wellness_sync_qa_test.dart` 的 `_cloudIds` 写死旧 `.cn` 服务器。
美国 App/API 上传后，测试会将当前会话用于旧域名回读，既不能验收美国服务器又存在跨环境发送会话的风险；本轮没有运行这条旧请求。
这不是已证明的产品上传故障，也不是修改生产 API 的理由。

新增 `integration_test/support/health_sync_readback.dart`，统一使用 `GlobalEnvironment.configuredOrigin` 和已校验的 API resolve。
原测试改用该 helper，保持 metric、200 条分页、原始 opaque cursor、完整 ACK / 原内容回读 / 去重断言不变。
新增三个回归测试：美国隔离路径及查询、游标原值和编码、真实 QA 不可退回旧硬编码域名。产品源码和接口契约未改。

## 验证、失败与缓存清理

- 起始磁盘约 555 MiB。首次定向测试因 OS Error 28 / No space left on device 在编译文件复制阶段失败，退出 1；未计通过。
  首次 analyzer 只有 helper 的 null-aware lint，改用 Dart 空值感知 map 元素后消除，没有忽略规则。
- 确认当前仓库 `.dart_tool/flutter_build` 为可重建缓存、约 1.4 GB、lsof 无使用者。
  强制删除命令被工具拒绝而未执行；改用非强制、显式目录删除成功，仅删除该缓存。可通过构建重新生成，原始材料/签名/归档/安装包未删除。
  后续空间约 5.4 GiB；该读数包括失败测试收尾和其他系统变化，不把全部增加量归因于这一个缓存。
- `dart format` 本轮三文件 / 0 改动，`git diff --check` 通过。
  定向 3/3；最终 analyzer 零问题 / 2.9 秒。
- `TZ=UTC flutter test --no-pub --reporter expanded` 1108/1108 / 87 秒。
  `TZ=Asia/Shanghai` 同命令 1108/1108 / 64 秒。
  `python3 -m unittest discover -s scripts/release -p 'test_*.py'` 25/25 / 26.229 秒，均为夹具，不是真实发布或回滚。
- 本轮改动仅验收脚本/helper/测试与记录，没有修改产品二进制输入。
  未新构建 Android/iOS、执行原生 XCTest 或恢复鸿蒙构建；既有产品 CI 不冒充本轮真机业务结果。

## 实机业务边界

现装 App 注册了 veepoo / yucheng / urion / coolwear / qring 五个桥接通道，QRing 并非未注册。
通过现有 AppController 两次扫描均为空、未连接、无权限错误或控制器异常；不能因此确定是固件、路由或服务器问题。
已请用户先在其他配套 App 断开 QRing（不解绑/清库），返回国际版搜索页，再核对真实广播；不得假造设备或默认能力。
另行调用现有 QRing 桥接的扫描，Future 正常完成、原生返回空 List（0 设备），没有错误对象。
至少该次空结果并非“原生有结果、被上层路由丢掉”的证据；仍需排除其他配套 App 占用、戒指未广播和手机当前前台状态。
通过现装 API 的 `supportsDailySummaries()` 只读调用正常完成、结果 true，VM 最终复核仍 HTTP 200 / main 在线。
此能力证明不等于设备上传 ACK、记录存在或待传已清空；没有为了该检查发送任何健康记录。

尚无本轮 QRing / LuckRing 新样本，未得到本轮真实设备 ACK、美国服务端原内容回读或同 ID 去重闭环。
没有为验证而上传旧域名缓存、将审核账号用于戒指测试、生成虚假记录或改变原时间/数值/ID；待设备连接后继续。
App Store 现有审核、服务器部署、医疗功能边界本轮均未改动。提供的 U19S 资质核对另见设备资质记录。

私有设备 JSON、日志、原生调试输出、VM 地址与加密库留本机 0700 目录 / 0600 文件，不进 Git 或普通交接包。
