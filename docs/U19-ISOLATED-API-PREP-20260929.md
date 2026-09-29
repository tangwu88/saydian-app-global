# U19 隔离 API 真机联调准备（2026-09-29）

## 范围与现场

- 原因：服务端任务“导入 saydianserver 项目”通知本机独立 PostgreSQL 与隔离 API 已就绪，要求用真实 U19 非零日汇总完成 App→服务端→回读。仅准备隔离 Debug 包和本机路由，不改运行时代码，不碰生产账号/健康数据，也不启动测量或修改手表设置。
- 修改前 App `feature/u19-eb1` 为 `2e1e590f0b76439badaa2f7b72301e5faa2149d2`；`git status` 干净，`git fetch origin --prune` 后相对远端 `0/0`。先读 `AGENTS.md`、最近 U19 联调记录与跨端防复发清单。
- 本轮 `adb devices -l` 始终无设备；Windows PresentOnly Android/Huawei/ADB/MTP 检索也无匹配。已请求用户重新连接、解锁并允许 USB 调试。没有执行 `adb reverse`、安装、登录、手表读取、上传或服务端回读；此阻断不能记成真机失败或云端通过。

## 隔离路径与只读探测

| 检查 | 结果 |
| --- | --- |
| 隔离 API `http://127.0.0.1:58082/health/ready` | HTTP 200，`database=ok`，实际进程 revision `a3e4e5ee3ec254b229bfe7879163e2a5a7b5dd68`。 |
| 直接 `GET /api/saydian-app/v2/auth/capabilities` | HTTP 200；本地合成测试域允许免验证码注册，具体账号仍未创建。 |
| 直接 `GET /api/saydian-app/v2/health/capabilities` | 未登录 HTTP 401，符合鉴权门禁。 |
| App 固定路径 `GET /global/api/saydian-app/v2/health/capabilities` 到 58082 | HTTP 404；App 的 `GlobalEnvironment.deployedPath()` 不因 Debug 本地 origin 改写路径。直接把 `adb reverse` 指向 58082 会失败，不能误归因于健康 API。 |
| 仅监听 `127.0.0.1:58083` 的临时 Node 代理 | 只接受 `/global/api/saydian-app/v2/*`，去掉 `/global` 后转发至 `127.0.0.1:58082`，不记录 token/请求体。代理公开能力 200、未授权健康能力 401、非白名单路径 404。正式版网络白名单未改。 |

代理是本轮终端进程，非持久服务；下一位同事应先确认监听者和转发规则，不能假定端口仍可用。手机恢复后使用 `adb reverse tcp:58083 tcp:58083`，Debug `SAYDIAN_API_BASE_URL=http://127.0.0.1:58083` 与 `SAYDIAN_ALLOW_LOCAL_DEBUG_API=true`。本地 origin 会创建独立存储命名空间，不自动认领线上账号会话或待同步记录。

## Debug 构建与边界

使用 Flutter `D:/Dev/Flutter/3.44.9/bin/flutter.bat`、JDK 17、Android SDK 与 Gradle 缓存执行：

```powershell
flutter build apk --debug --target-platform=android-arm64 `
  --dart-define=SAYDIAN_API_BASE_URL=http://127.0.0.1:58083 `
  --dart-define=SAYDIAN_ALLOW_LOCAL_DEBUG_API=true `
  --dart-define=QWEATHER_API_KEY=
```

- 结果：`assembleDebug` 198.9 秒后成功；忽略的 `build/app/outputs/flutter-apk/app-debug.apk` 152,615,559 字节，SHA-256 `9E735E5498E4A128DC51C1F9A773DA341BA537845AF42BD778E86553F6BD3C24`。`aapt` 核对包名 `cn.saydian.app.global`、版本 `0.1.23+1007`、标签 `SAYDIAN Health`。
- 构建时的旧 Kotlin 插件兼容和 SDK XML 版本警告未阻塞；未改无关插件。第一次查找 `build-tools/36.0.0/aapt.exe` 不存在，随后改用本机 `36.1.0` 成功。
- `GlobalAppUpdateService` 目前仍固定指向线上国际版更新清单。此次尚未安装/启动该 Debug 包，所以**不能声称所有请求都只到本地**；若要求零线上请求，应先单独处理或隔离手机外网，再进行真机联调。尤其不要把线上更新检查、登录或旧会话作为隔离服务的验收。
- 需获得真实非零 U19 步数/睡眠样本并核对所属日期后，才可用隔离测试账号上传。血压充气、自动测量、设置写入及恢复出厂均不在本轮授权内。

服务端任务报告的合成数据版本折叠已通过，但本 App 尚无 `acceptedIds` 或隔离库重新读取结果。本文件仅是联调准备，不替代真机闭环。
