# SayDian 国际版戒指与隐私审核补充

本文件是本次客户端变更的交付说明和待提交草稿，不代表已上传、已审核或在线隐私政策已发布。构建版本仍为 1.0.1 (1014)，正式上传前需选择 App Store Connect 可用的新构建号。

## 本次客户端行为

- 应用显示名为 **SayDian**，国际版 Bundle ID 仍为 `cn.saydian.app.global`。
- LuckRing/CoolWear、QRing 原生 SDK 已加入 Android 和 iOS 启动、发现、连接、能力读取、同步、设备页和首页戒指卡片。
- 名称仅用于选择 SDK：R7/K80/HR01/HR05 优先走 LuckRing；R8/R21/R22 或 Q_/O_/R2 前缀走 QRing。以原始设备名展示，必须完成供应商握手；名称匹配不证明型号能力。
- 所有 iOS 用户及构建模式统一仅开放活动/睡眠数据。不能通过账号、地区、审核设备或服务端开关恢复生理测量、医疗提醒、风险分析和 AI 健康分析。旧数据保留，显示和上传采用范围过滤。
- 新增戒指继续执行 Dart 与原生范围限制；未知电量/设置显示未知，读取或写入未确认时不得当作成功。
- 关于页面说明用途并建议在作出医疗决定前咨询专业人员。沿用账号注销、已发布协议版本校验和国际 `/global` 网络隔离。
- 登录页、隐私政策页、账号页及关于页提供本地“数据隐私”说明，离线/协议服务不可用时仍可阅读。补充说明不会记录同意，也不会替代服务端协议。

## 审核说明英文草稿

SayDian is an activity and sleep companion for compatible wearables. The iOS edition uses the same activity/sleep scope for every user and build mode. It does not provide medical measurements, diagnosis or treatment. Please consult a qualified healthcare professional before making medical decisions.

This update adds LuckRing and QRing integration. In the Device tab, start a scan, select the actual nearby device, and complete the vendor connection handshake. Available features and data depend on the connected device. Missing values are not generated. Without a wearable, account, support and privacy features remain accessible.

Data privacy information is available from the sign-in screen, the Privacy Policy screen, Account and About. SayDian cloud account, device and synchronized wearable data is stored on servers physically located in the United States. The app also keeps an encrypted local history on the phone for offline use and pending synchronization. Optional third-party services process information under their own policies. Opening this notice does not grant consent or replace the published Privacy Policy.

## 正式提审仍需补充的真实材料

1. 对国际版本实际安装包录制登录、扫描、LuckRing 与 QRing 连接、活动/睡眠同步、查看隐私、注销账号的视频。当前主机测试不能代替这些证据。国内 R7Pro/R21 的历史测试不能作为本次国际构建验收。
2. 使用 Apple 受保护审核账号字段中的有效国际账号验证登录；本记录不包含密码，不伪造免验证码账号或视频链接。
3. 在 App Store Connect 更新名称、对应截图、审核说明、隐私政策链接及实际 App Privacy 数据类型/用途。不要把“美国存储”误填为“不收集数据”。本轮未更改或提交这些在线内容。
4. 将下述存储条款经运营审核后合并到在线国际隐私政策，由服务端发布真实版本。确认数据库、对象存储、备份、日志及相关处理商地域与声明一致；本轮地域事实来自运营方指示，未远程审计。
5. 新增 `PrivacyInfo.xcprivacy` 声明自有代码使用的 UserDefaults、启动计时与容器文件元数据原因；这不替代第三方 SDK 审查或 App Store 的数据收集标签。

## 待合并的在线隐私政策条款

**中文：** SayDian 云端保存的账号、设备及同步的穿戴设备数据，均存储在美国境内的服务器。如果您在其他国家或地区使用 SayDian，您选择同步的数据将传输至美国。SayDian 也会在手机上保留加密的本地历史数据，用于离线查看及等待同步。尚未获得服务器确认的数据仍标记为待同步。天气、通知等可选服务可能根据各自的隐私政策处理实现该功能所需的信息；美国存储声明适用于 SayDian 云端存储，不包括您的手机及第三方独立处理。您可以在应用内管理共享，并通过“账号 → 注销账号”申请删除账号及关联数据。保留期限与其他权利以已发布的隐私政策为准。

**English:** Your account, device and synchronized wearable data stored in SayDian’s cloud is kept on servers physically located in the United States. If you use SayDian from another country, the data you choose to synchronize is transferred to the United States. SayDian also keeps an encrypted local history on your phone for offline use and pending synchronization. Data that has not been confirmed by the server remains pending. Weather, notifications and other optional services may process the information needed for the feature under their own policies. The United States storage statement applies to SayDian’s cloud storage, not to your phone or a third party’s independent processing. You can manage sharing in the app and request deletion of your account and associated data from Account → Delete account. See the published Privacy Policy for retention and other rights.

参考：[Apple 审核指南](https://developer.apple.com/app-store/review/guidelines/)、[Required Reason API 原因](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)。国内版参考文件为 `IMPLEMENTATION-20261013-APP-REVIEW-1022.md`；不把国内重提审记录表述为已获批准。
