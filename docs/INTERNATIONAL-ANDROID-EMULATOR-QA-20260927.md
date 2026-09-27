# 2026-09-27 国际版 Android 模拟器调试

## 基线与范围

- `git fetch --prune origin` 后，本地 `HEAD` 与 `origin/main` 均为 `e7bda6e6fc45f889d89c3bd1f0da6fa7e35bf5b5`，ahead/behind `0/0`；工作区原有未跟踪的 `saydian国际版.txt` 未改动。
- 使用 `Saydian_API_36`（Android API 36，`emulator-5554`）和 Flutter 3.44.9；仅覆盖安装并启动 `cn.saydian.app.global` Debug 包，未卸载或清除模拟器已有数据。包版本 `0.1.21+1004`。
- 目标是验证模拟器启动、匿名登录/注册页面、语言、基础表单和第一方网络；模拟器不代表手表蓝牙、支付或真机验收。

## 执行与结果

- 设置 `JAVA_HOME=F:\Codex\home\tools\jdk17`、`ANDROID_HOME=D:\Dev\Android\Sdk`、`ANDROID_SDK_ROOT=D:\Dev\Android\Sdk`、`GRADLE_USER_HOME=D:\Dev\Gradle`、`SAIDIAN_EMULATOR_DEBUG=true` 后执行 `D:\Dev\Flutter\3.44.9\bin\flutter.bat run -d emulator-5554 --debug --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update --dart-define=QWEATHER_API_KEY=`：Android Debug 构建约 168 秒并安装成功；登录页启动，进程保持运行，未见本应用崩溃或 Flutter 异常。启动有一次明显跳帧，未进行性能定量验收。
- 模拟器原有数据保留了简体中文偏好；手动切换 English 后，登录与注册页面切换为英文，独立返回桌面再启动仍保持 English。未清数据，不能据此声称全新安装默认语言已验证。
- 匿名 UI：邮箱/手机号切换、注册入口、国际区号搜索并选择 `CN +86`、空表单校验、英文用户协议页面均可操作。未使用真实账号提交注册或登录。测试前已有数据的一次页面显示 `AD +376`，但再次冷启动进入手机号登录时显示的是“Select country or region”；原因和首次安装默认值尚未验证。
- `D:\Dev\Flutter\3.44.9\bin\flutter.bat test --no-pub test/global_auth_page_test.dart test/global_auth_consent_test.dart test/global_update_test.dart`：21/21 通过。
- `D:\Dev\Flutter\3.44.9\bin\flutter.bat analyze --no-pub`：通过，`No issues found`，用时 68.4 秒。
- 当时只有模拟器在线，执行 `adb logcat -d -t 800 AndroidRuntime:E Flutter:E '*:S'`：最近窗口无匹配错误；这是有限日志窗口，不等于完整崩溃监控。之后实体手机接入，后续命令必须显式使用 `-s emulator-5554`，避免误操作手机。
- 调试日志可见的第一方请求均发往 `app.saydian.cn`，公开能力与协议请求返回 200；没有对登录后所有路径做域名覆盖审计。

## 已知问题与未验收

- **P2：国际更新清单未发布。** 复现：启动 App 或执行 `curl.exe --silent --show-error --location --max-redirs 0 --output NUL --write-out 'HTTP=%{http_code} REDIRECT=%{redirect_url}\n' 'https://app.saydian.cn/global/api/saydian-app/v2/support/app-update'`。预期：返回符合国际包契约的清单，或正式定义的不可用状态；实际：HTTP 404，Flutter 日志有对应 404。此项与 2026-09-11/12 记录相符，需服务端发布后复验；不能将 404 判定为“已是最新版”。本轮未修改客户端或服务端。
- **P3：手机号入口与 H5 默认区号要求不一致。** 复现：冷启动登录页切换“Phone number”。H5 已确认交互是默认中国大陆 `+86` 且可选其他国家；当前 App 显示“Select country or region”，要求用户多选一步。是否统一 App 与 H5 的默认区号需要确认；本轮先记录现象，不直接修改源码。
- 未执行有效账号登录/注册、健康/商城/支付、真机 BLE、iOS、全量 Flutter 测试及 Android Release 构建；本记录仅是模拟器专项。用户后来接入的实体手机未被本轮 `flutter run` 选为目标。

## 交接

- 本轮无源码改动；模拟器截图留在忽略的 `build/emulator-qa-20260927/`，原始运行日志未归档，两者均不纳入 Git。
- 继续时先更新 `origin/main`，核对更新清单上线状态，再用账号/真机补全登录后和设备流程；修复区号默认值前先补 Widget 测试，避免混同 H5 地址页的配送国家与登录区号。
