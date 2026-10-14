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
