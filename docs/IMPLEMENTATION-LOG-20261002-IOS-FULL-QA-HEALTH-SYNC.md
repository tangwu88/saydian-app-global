# 2026-10-02 全 App 真机逐页复测与手表同步闭环

## 目标与范围

- 用户要求继续对国际版 iOS App 逐页检查、完成真实手表测量到服务端的同步闭环，并增加一段连接设备操作视频供 App Review 使用。
- 基线：分支 `codex/global-device-admin-20261001`，复核前 HEAD `5d4de81f683337e9c6f6064f313d6412edddf23e`；执行 `git fetch --prune origin` 后工作树干净且与跟踪分支一致。
- 本轮未改产品源码。新增/刷新截图都位于忽略的 `build/ios/real-device-qa-20261002/` 下；以前一轮 36 张截图先复制到 `screenshots/final-expanded-before-continuation/`，原截图保留。

## 页面巡检

- 在 iPhone 15 Pro Max（iOS 26.6，UDID `00008130-001C098C2290001C`）执行：`TMPDIR=/private/tmp flutter drive --driver=test_driver/ios_full_page_qa_test.dart --target=integration_test/ios_full_page_qa_test.dart --device-id=00008130-001C098C2290001C --no-pub`。
- 结果：驱动退出码 0，Flutter integration test 显示 `All tests passed!`，用时约 1 分 16 秒；当前目录生成 36 张 PNG。页面包含首页、消息、远程关爱、百科/预警、AI 空态、健康指标详情与历史、设备/设备详情、健康监测/脉搏/显示/设置/连接帮助、资料编辑、账号/权限/反馈/客服/关于/协议/单位/语言。
- 重要边界：因本轮开始时原登录会话的上传返回 401，测试控制器无登录态并进入访客预览。当前轮抽查 `01-home.png`、`09-device.png`、`10-profile-edit.png`，确认布局正常；这些图显示 Guest/空资料/未连接提示，不作为真实账号、设备连接或健康数值证据。上一轮登录态扩展截图见 `IMPLEMENTATION-LOG-20261002-CLIENT-UX-FIXES.md`。
- 逐页产物：`build/ios/real-device-qa-20261002/screenshots/final-expanded/`；覆盖集保留在 `build/ios/real-device-qa-20261002/screenshots/final-expanded-before-continuation/`。本轮测试驱动没有手动测量、提交资料或保存设置。

## 手表与服务端同步观察

- 巡检前真机 Watch 页显示设备 `U19S_SD_2765` 已连接、电量 10%，页面明示有记录留在手机且未上传。用户此前已明确允许把真实健康记录发送到自己的 `https://app.saydian.cn/global` 服务端用于此同步复测。
- 在 Watch 页点击一次“Try again”。页面仍显示待上传提示；此前 Flutter Debug 日志里的 API POST 返回 HTTP 401（脱敏路由摘要 `835be0763c50`）。本轮没有取得服务器接受回执或按记录 ID 回读，因此同步闭环失败，不能宣称数据到达服务端；没有再次重复重试或测量。
- 随后退出失效账号并用访客态跑页面用例。控制器登出实现清除凭据但不删除加密健康记录表；待上传队列仍需同一账号重登后核实。退出后设备连接中止，当前账号未恢复。
- 登录页要求再次勾选“I have read and agree to Terms of Service and Privacy Policy”。已向用户请求确认是否已阅读并同意；收到确认前没有勾选、输入/提交账号密码或绕过该同意门槛。手表当前不能测量或上传。

## 录屏与 Debug 会话

- 用户新增“录制连接设备操作视频”。尚未录出可交付视频。QuickTime Player 的 UI 绑定连续超时；iPhone 镜像此后报告 Mac 锁屏，无法继续打开系统录屏界面。不能用截图或访客预览冒充连接视频。
- 真机 Debug 增量构建成功，但再次附加时 macOS 提示需授权 Flutter/Xcode 自动化控制；随后 60 秒未发现 Dart VM Service。Mac 当前锁屏，停止该次等待；因此本轮结束时没有有效 VM/DevTools 附加会话。
- 本轮遇到并按请求授予 App 的本地网络、蓝牙权限；蜂窝网络选择“仅限无线局域网”，未开放蜂窝数据。手表剩余电量 10%，只做了一次待上传重试，不为录屏或页面巡检反复耗电。

## 结论与待办

- 页面自动化：访客预览态 36 张图及真实 iPhone 驱动通过；它不等同于所有账号态、联网态和写入操作均通过。
- 未完成：用户确认协议后恢复登录、检查同一账号待传队列、重新连接 U19、完成一次真实设备测量，并以真实 HTTP 接受 IDs 和服务端读取结果证明同步及去重；录制并检查真实连接操作视频；解锁 Mac 并恢复 Xcode/Flutter VM 调试。
- 未发现足够证据判定 401 的最终根因，也未修改同步逻辑。应先取得重新登录后的真实接口响应，再区分账号授权失效、接口配置或服务端拒绝，不能通过伪造成功、降级校验或丢弃待上传记录来消除提示。
- 源码没有变化；既有基线在 `IMPLEMENTATION-LOG-20261002-WATCH-SYNC-HEADER.md` 记录了双时区 951/951 测试与 `flutter analyze --no-pub` 结果。本轮新增验证只运行上列真机逐页驱动，未重跑 Android 构建、iOS Profile 或完整双时区测试；不可据此宣称这些构建/测试在本轮通过。
