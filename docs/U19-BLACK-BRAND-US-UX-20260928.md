# SAYDIAN Health 黑色品牌、美国默认体验与 U19 提示（2026-09-28）

## 范围、基线和预期

- 工作区 `F:/xcodeplace/saydian-app-u19`，分支 `feature/u19-eb1`，`origin` 为 `tangwu88/saydian-app-global`；开始时工作树干净，fetch 后与远端 `10d8eb55f384c350a5ef05655057dae588728605` 一致。只改国际版，不合并或发布国内版、服务端。
- 用户提供 `E:/产品图片/saidian_logo新/logo图形.png` 作为黑色标志。原文件只读；它实际为 JPEG 内容，仓库内保存原样副本并提供可重现的导出脚本。预期 Android、iOS、HarmonyOS 应用名与图标一致。
- 暂时隐藏商城可见入口，保留路由、订单与支付实现及回归测试；不删除历史数据，也不把未上线的 U19 功能伪装成可用。
- 美国用户默认英文、电话国家码 `+1`、距离英里、温度华氏度；本次不更改原有的单位设置写入行为。手表数据与写入仍按既有协议单位，不修改健康算法。
- U19 的血压测量提示区分手腕佩戴与其他设备的袖带提示，且继续要求用户主动开始、在手表上结束；只改说明，不增加测量指令。依据 [CDC 的家庭血压测量说明](https://cdc.gov/high-blood-pressure/measure/index.html) 与 [AHA 的家庭血压监测说明](https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings/monitoring-your-blood-pressure-at-home) 保持坐稳、手腕与心脏同高、测量仅作健康参考的表达，不声称手腕设备等同经验证上臂血压计。

## 修改

1. `scripts/generate_black_brand_assets.ps1` 从已批准图形导出白底黑标主图、锁定比例的品牌组合图、Android 普通／自适应／单色图标、iOS AppIcon 和 Harmony 图标；原始图形未被修改。图标保留白色安全区，避免系统圆角裁切黑标。
2. Flutter、Android、iOS、Harmony 的显示名改为 `SAYDIAN Health`；最终 Android 版本推进至 `0.1.23+1007`。主按钮、导航、卡片与登录品牌视觉改为黑灰，危险／异常提示继续使用独立语义色。HarmonyOS 商城展示入口同步隐藏。
3. `showSaydianMall=false` 隐藏首页快捷入口、设备扫描页商城入口和“我的”订单入口；商城模块仍可通过测试中的隐藏路由验证。恢复商城时需重新评估后台市场、支付和订单入口。
4. 国际版默认 US 区号、英里和华氏度；每日距离目标输入与显示按英里换算，但底层仍存公里。U19 的基础设置和查找手表关键提示在英文界面使用普通英文，首次时间同步仍让用户确认手表当前语言，不擅自改手表语言。
5. 八语资源补 `SAYDIAN Health` 名称与 U19 手腕测量提示；生成的本地化代码随源码提交。
6. 应用户追加要求，使用内置图像生成工具，以旧卡片人物为编辑参照，换成虚构的美国诊所成年女医生插画（白色外套、浅蓝内搭、亲和且更成熟的面部）；Flutter 与 HarmonyOS 使用同一 PNG。没有使用真实医生肖像，也不把 AI 助手伪装成持证问诊服务。图像提示保留原卡片的竖构图、柔和背景和裁切空间，禁止文字、机构标志与证件。

## 修改与测试记录

| 检查 | 命令／方法 | 结果与处理 |
| --- | --- | --- |
| 图标 | `powershell -File scripts/generate_black_brand_assets.ps1`，人工查看主图、组合图及 Android 单色图 | 导出成功，黑标主体和留白正确；原文件未写入。 |
| 页眉标志 | 真机冷启动截图、透明标志像素检查 | 初版白色方块与浅灰背景不协调；第一次连续色去背景误删图形内部白色，未交付；改用仅圆形外区域透明的遮罩，角像素透明、内部白形不变，重新构建。 |
| AI 医生素材 | 内置图像生成编辑、人工检查人物比例与卡片裁切；Harmony／Flutter PNG 字节一致性测试 | 第二次人物更成熟可信；替换两个平台同一资源。未生成真实姓名、医院或资质；新增 Harmony 主机测试随之从 481 增至 **482/482 通过**。 |
| 多语言 | `flutter gen-l10n` | 首轮新提示在 6 种语言缺译；补译后无未翻译项。 |
| 静态检查 | `flutter analyze --no-pub` | 首轮 2 个格式建议；仅修正本轮代码，复跑无问题。 |
| 定向 Flutter | 品牌、登录、设备壳层、商城隐藏与 U19 测量相关用例 | 102/102 通过。 |
| 全量 Flutter | `flutter test --no-pub --reporter compact` | 首轮 898 通过、3 失败：旧查找测试仍断言中文，而英文默认界面已改为英文；更新预期后复跑 **901/901 通过**，再经末轮视觉色彩修正复跑仍 **901/901 通过**。未删用例。忽略的日志在 `build/u19-black-brand-flutter-tests*.log`。 |
| Harmony 主机测试 | `node --test harmony-native/tests/*.test.mjs` | 首轮 1 个旧红色色值断言失败，随新规范调整；增加双端头像资源一致性后最终 **482/482 通过**。源码契约测试不等于 HAP 构建或 U19 真机能力。 |
| 格式检查 | `dart format --output=none --set-exit-if-changed` | 本轮涉及的 13 个 Dart 文件 0 变化。对整个 `lib test` 的检查提示 6 个范围外旧文件格式差异；此命令不写文件，`git diff` 核对无范围外修改，未趁机格式化。 |
| 补充检查 | `git diff --check` | 通过，无空白错误。 |

## AI 素材生成记录

- 方式：内置 `image_gen` 编辑现有项目图片，不使用外部真实医生肖像。第一轮以旧 `assets/branding/ai-health-manager-doctor.png` 为编辑目标，要求“fictional adult female physician in a contemporary U.S. clinic; white coat, pale blue top; keep the same waist-up composition, off-white backdrop and card crop; no text, logos, badges or medical devices”。
- 最终选中第二轮，输入为第一轮图像，关键完整修改指令：“make the fictional female U.S. physician appear credibly adult and experienced, around age 42, with natural facial proportions, normal-sized eyes, subtle skin texture and a warm reassuring expression; change only facial maturity and realistic detail; retain the exact vertical composition, pose, white coat, pale blue shirt, off-white background, soft lighting and negative space above the head; no text, badges, logos, stethoscope, certificates, other people or watermark”。
- 最终项目资产：`assets/branding/ai-health-manager-doctor.png` 与 `harmony-native/entry/src/main/resources/base/media/health_doctor.png`，两者逐字节一致。生成源位于本机 Codex 图像目录，项目引用只指向已提交资产。

## Android 构建、安装与视觉验收

- 最终 `flutter analyze --no-pub` 无问题；`flutter test --no-pub --reporter compact` **901/901 通过**；`node --test harmony-native/tests/*.test.mjs` **482/482 通过**；本轮涉及 Dart 文件格式检查 0 变化，`git diff --check` 通过。
- `flutter build apk --debug --target-platform=android-arm64 --no-pub`、显式 `SAIDIAN_ALLOW_QA_RELEASE=true` 的 `flutter build apk --release --target-platform=android-arm64 --no-pub` 均成功。两个第三方插件的未来 Kotlin 兼容警告保留，未趁机修改无关依赖。
- 最终内部 QA 包用 `aapt` 核验为 `cn.saydian.app.global`、`SAYDIAN Health`、`0.1.23+1007`；`apksigner verify --print-certs` 通过，测试证书 SHA-256 为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`，与原 1005 测试包一致。该包为内部 QA 签名，不是商店签名。
- 内部 QA APK SHA-256：`B47665CCF1BC83BDA9A2AA9050EA970C64EB8F1836C482B654909BC626070881`；Debug APK SHA-256：`C46251C905C690A38098A5D5F41380310E676CD74360E04F76DC24715AB3BAEB`。可交付副本位于忽略的 `build/qa-u19-black-brand-20260928/`，不入 Git。
- 首版 1006 在用户确认系统风险提示后覆盖安装成功，真机截图发现页眉标志白方块；修复后把追加的 AI 医生图一同打进 1007。1007 再次由用户确认系统安装提示，`adb install -r` 返回 `Success`；包管理器确认 `versionCode=1007`、`versionName=0.1.23`。未卸载、清库或覆盖健康历史。
- 1007 冷启动真机截图在忽略的 `build/u19-black-brand-1007-home.png`：黑白圆形标志与页面融合，AI 医生头部与肩部完整，黑色主按钮、三项健康快捷入口与健康数据首屏布局可读，商城入口不可见。当前进程仍在，按进程筛选日志的崩溃／ANR／RenderFlex overflow 命中数为 0。已登录测试账号保留此前中文语言选择，故该截图不是全新用户英文默认的真机验收。

## 验收边界与后续

- 本任务不触发生产部署，构建产物、原始日志、设备标识和健康原始数据不入 Git。
- Windows 无 Xcode/DevEco Studio，iOS 与 HarmonyOS **未完成平台构建或真机外观验收**。HarmonyOS 现有原生 U19 接入状态不因换品牌而变化，不能将 host 端测试视作 U19 可用。
- 旧 `scripts/generate_launcher_icons.swift --check` 使用 macOS AppKit 逐字节比较 PNG，与本轮 ImageMagick 导出器不同；本机无法运行，故不将其标记为已通过。以本轮 PowerShell 脚本和已提交的资源为当前可复现来源，macOS 接手时须重新核对两套导出器，不可未经检查覆盖资源。
- 美国体验本轮为核心默认设置和 U19 关键流程优化，并非全量页面的八语人工校对或 FDA/临床认证。原有单位设置只在当前运行会话内生效，重启后恢复新默认值；跨启动保存单位偏好未在本轮实现。尚未实测所有设备型号和字体缩放组合。
- 手表→本机→服务端 U19 日汇总仍受线上能力接口 404 与服务端未发布约束；本轮不修改服务端、不声称云端同步通过。
