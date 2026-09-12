# 2026-09-13 国际商城账号、推广与 App 支付隔离

## 修改前基线

- 分支：`feature/global-commerce-parity`
- 基线提交：`9530387680d71a0e1f3452093fd68e206f09939f`
- 远端：`https://github.com/tangwu88/saydian-app-global.git`
- 本轮延续尚未发布的国际商城本地改动，不推送、不部署。

## App 实施结果

- 商城能力只接受服务端已启用且当前平台匹配的 `wechat_app` / `alipay_app`；H5 微信、H5 支付宝及未知通道不会在 App 付款区展示。
- 新增国际商城付款创建和状态查询契约。付款创建固定调用 `/global/api/saydian-app/v2/commerce/payments`，携带订单 UUID、原生通道、Android/iOS 平台和独立幂等键；状态查询调用本人鉴权的账单接口。
- 付款响应必须与当前订单、业务类型及请求通道一致，异常响应不会调起第三方客户端。
- 微信和支付宝复用已有双端原生桥接。支付宝客户端返回和微信调起结果只用于交互提示，不会直接把订单标记为付款成功；页面保留“检查付款结果”，以服务端回读状态为准。
- 服务端没有明确开放原生支付能力时不显示支付按钮，也不读取或回退 H5 支付配置。
- 所有第一方 API、媒体和私有凭证继续由生产边界限制到 `https://app.saydian.cn` 及国际允许路径；共享国内客户端中保留的旧域名兼容代码不会被国际 API 客户端采用。

## 自动验证结果

- 商城支付 API、控制器和页面专项：18/18 通过。
- 第一方域名、重定向和商城媒体边界：37/37 通过；旧域名、HTTP、异常端口、带凭据 URL、越权路径及旧域重定向均在传输前拒绝。
- `flutter analyze --no-pub`：通过，无问题。
- `TZ=UTC flutter test --no-pub`：841/841 通过。
- `TZ=America/New_York flutter test --no-pub`：841/841 通过。
- Android 原生 `:app:testDebugUnitTest --rerun-tasks`：4 个测试类、16/16 通过。
- Android Debug 构建：通过，`app-debug.apk`，185,591,542 bytes，SHA-256 `AFA1FDA03802C575C35E360B5C72DD595228344DE763FE0B31A0E40791AFFF75`。
- 显式允许 QA 的 Android Release 构建：通过，`app-release.apk`，68,879,500 bytes，SHA-256 `A100FB2005884587E1A768ADD84B7AF4858672B01EEB6C6E488B2742EF8EEA7C`。
- 两个 APK 均通过 APK Signature Scheme v2 验签，签名证书 SHA-256 为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`。该证书为内部 QA Debug 证书，不代表正式商店签名。

## 过程失败及修复

- 系统 PATH 中没有 Dart/Flutter；后续统一使用 `D:\Dev\Flutter\3.44.9\bin` 下的明确工具路径。
- 新增本地化键时曾与既有 ARB 键重名，生成阶段失败；删除重复声明并重新生成八语代码后，全量测试通过。
- 页面测试最初因同一付款提示在窄屏中出现两处文本而使用了过宽匹配；改为稳定控件键和状态断言，避免测试掩盖真实 UI 行为。
- 单元测试环境的平台识别曾与预期不一致；测试显式恢复目标平台，生产逻辑仍只允许 Android/iOS。
- 安卓测试结果最初按 `android/app/build` 查找为空；实际报告位于根 `build/app/test-results/testDebugUnitTest`，重新汇总确认 16/16。

## 尚未验收

- 本轮没有可用的隔离数据库或已授权 App 微信／支付宝沙箱凭据，因此未执行真实下单、付款、回调、退款、奖金结算、提现、发货或 ERP 写入。
- 新 APK 尚未在本轮覆盖安装并做冷启动支付返回测试；没有卸载、清数据或改变手机上的既有账号和手表状态。
- Windows 本机不能完成 iOS 无签名编译或 iPhone 真机付款回跳；现有 iOS MethodChannel 契约已被 Flutter 测试覆盖，但不等同于 iOS 真机验收。
- 构建产物和原始日志不提交 Git。所有源码仍为本地功能分支改动，待隔离服务、支付配置及联合验收完成后统一更新线上。
