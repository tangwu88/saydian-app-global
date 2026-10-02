# 2026-10-02 手表血压同步、30 分钟补传与 Health 顶栏头像

## 范围与根因

- 用户反馈：手表端自行点击的血压结果未同步到服务端；希望连接期间每 30 分钟自动同步设备，并重试未上传记录且不重复；随后补充更正 Health 顶栏布局：个人头像应替换左侧品牌 Logo，昵称应留在原有右侧文字槽，整体排版不变。
- 分支 `codex/global-device-admin-20261001`，修改前 HEAD `20f024ecb77b8477c4911df2825bd01704e7c699`；已 `git fetch --prune origin`，HEAD 与 origin 跟踪分支一致。工作树原有个人资料/国际化/真机 QA 等未提交改动均保留；修改前二进制差异快照 `build/ios/real-device-qa-20261002/checkpoints/before-source-watch-sync-20261002.patch`，SHA-256 `a994625b7a36b8fb1610ab0318dc6484f08d04e0001e0c39672c373f38776d88`。
- U19 根因：手表通知触发通用 `healthDataReady`，但桥接层仅在已通过 App 发起测量取得血压时间编码后才读血压历史；手表端自发测量没有 `_measurement`，原测量读取函数立即返回，历史记录因此未进入设备同步批次。

## 修改

- `lib/services/urion_wearable_bridge.dart`：支持血压能力的同步会读取血压历史；按当前连接缓存样本指纹，首次同步建立基线。手表端通知后的新样本只有在时间戳可无歧义证明位于通知前 5 分钟且唯一时才进入历史，沿用按设备及样本内容派生的稳定记录 ID。重复通知不会再次返回同一样本；歧义或旧记录不猜时区、不生成上传记录。App 发起测量的既有校验路径保留。
- `lib/services/app_controller.dart`：连接就绪后开始前台 30 分钟周期；回到前台立即尝试同步并重启周期。每轮先读设备（正在测量或设备读取失败时不并发抢占），随后仍调用云同步以重试本地待传队列；断连、换号/同步失效、后台和 dispose 停止计时器。服务端仅确认接受的稳定 ID 才标记完成，未确认记录继续待传。
- `lib/ui/pages.dart`：Health 左侧 50 px 品牌标记槽显示资料头像；头像缺失或加载失败显示原品牌 Logo；“Health”标题、右侧昵称位置和通知入口维持原有布局。头像更新会随 `memberProfile` 更新重绘。
- 回归测试：U19 通知样本唯一时间/重复同步；控制器周期、ACK 去重、历史读取失败仍上传、前后台和断连暂停；Health 顶栏头像相对标题和昵称的左右位置及空头像 Logo 回退。假手表 Widget 测试在检查计时器前显式暂停控制器。

## 验证记录

- RED：Health 顶栏位置断言先失败，实际头像左坐标 `524.5`、Health 标题左坐标 `77.0`；修复后同一断言通过。
- 首轮周期用 `testWidgets` 推进 30 分钟虚拟时间时用例未完成（测试框架内的 recurring care timers 使时钟推进不收敛）；改用普通异步测试和 50 ms 注入周期。首轮普通测试等待本地读表计数后立即断言云端 ID，曾因云请求尚未完成而失败；改为等待真实 ACK ID 后重跑通过。
- 一次组合定向运行中 UI 测试因缺少 `SaydianBrandMark` 测试导入而编译失败；补导入后独立测试通过。第一轮 UTC 全量记录 941 项通过、10 项失败，均为 `prototype_coverage_test.dart` 在 Widget binding 检查前遗留了新增周期 Timer；各连接测试显式切后台清理后该文件通过。
- `flutter test --no-pub --reporter compact test/urion_wearable_bridge_session_test.dart`：17/17 通过。
- `flutter test --no-pub --reporter compact test/app_controller_stale_callback_test.dart`：15/15 通过。
- `flutter test --no-pub --reporter compact test/ui_shell_test.dart`：58/58 通过。
- `flutter test --no-pub --reporter compact test/prototype_coverage_test.dart`：25/25 通过。
- `TZ=UTC flutter test --no-pub --reporter compact`：951/951 通过；日志 `build/ios/real-device-qa-20261002/watch-sync-utc-fixed.log`。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：951/951 通过；日志 `build/ios/real-device-qa-20261002/watch-sync-shanghai.log`。
- `dart format` 本轮 7 个 Dart 文件：0 格式变更；`flutter analyze --no-pub`：No issues found；`git diff --check`：通过。
- 本轮提交前复核：重新运行 `flutter analyze --no-pub`、`git diff --check` 及双时区全量测试，UTC 与 Asia/Shanghai 均为 951/951 通过。

## 真机与未验收边界

- 自动化仅使用合成样本/内存 Store 和 Fake API，没有触发当前账号实测，也没有向线上发送真实健康记录。
- iPhone 15 Pro Max UDID `00008130-001C098C2290001C` 当前连接。为避免两个 Flutter 会话争抢同一设备，已只停止旧国际版会话，保留独立 SayRing 会话；随后由本源码目录的 `flutter run --debug --no-pub --device-connection attached` 成功构建、安装并启动 bundle `cn.saydian.app.global`。Flutter 输出显示文件同步耗时 183 ms，并公布 Dart VM Service `http://127.0.0.1:51280/6jcfvDOOp1o=/`；本机随后单独 HTTP 探测超时，故只记录 Flutter 启动时公布的 VM 地址及仍存活的调试进程，不宣称独立 VM 探针通过。`flutter run` 会话保持运行。
- 本轮镜像已可用并检查了 Health 与“我的”页：Health 左侧显示品牌 Logo、标题，右侧显示昵称 `lili3` 和通知入口；“我的”页头像仍是默认人像占位，没有已保存的自定义头像，因此当前品牌 Logo 回退符合“仅上传个人头像时替换”的预期。头像存在时的替换分支由 `test/ui_shell_test.dart` 覆盖。本轮只核对了这两页顶栏，不代表全 App 逐页验收。
- 真机血压传感器产生的记录、写入本机待传队列、线上 ACK 回读、自动重连以及不重复上传，均尚未端到端复测；本轮没有手动触发测量。此前用户已允许真实记录上传，但仍需实际新测量记录才能完成硬件闭环。
- 30 分钟任务是 App 前台且连接有效时的应用内周期；进入后台后不承诺精确每 30 分钟运行，依赖 iOS 蓝牙事件唤醒与回前台补同步。`BGTaskRequest.earliestBeginDate` 也不保证在所设时间执行。
