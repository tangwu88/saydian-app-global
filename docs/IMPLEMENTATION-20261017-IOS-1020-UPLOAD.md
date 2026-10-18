# 2026-10-17 苹果 1020 构建与上传

## 授权、基线及边界

用户要求完成后构建苹果新版本并上传。起始clean 17a3778，fetch成功，当前分支无tracking导致ff-only pull拒绝；没有合并其他分支、覆盖数据或修改国内仓库。已阅读AGENTS、国际交接、当前XR记录、变更日志、复盘及回归清单。

本轮仅将pubspec版本从1.0.1+1019递增为1.0.1+1020，正常lib/main.dart正式Release构建，.com API、禁用远程推送及Urion本机范围不变。不将QA入口作为发行包，不解除真实设备门禁。先完整保留默认目录原1018归档至build/store-upload-20261017-1020/preserved-1018-Runner.xcarchive；磁盘134.6GiB可用。构建号1020若Apple实际报告占用再递增，不通过改号覆盖旧构建。

用户已报告读数可见，但XR当前账号本机持久化查询0条、美国活动/睡眠历史82条，具体值/手机归属仍待澄清；当天步数增长未验证，当前构建不能称为全面硬件验收通过。上传候选构建不替换1018的审核关联、不撤回或重新提交审核，不发布或启用新的法律文本。1019新增本机功能对应的正式描述、截图、政策及适用材料仍需在后续公开送审前准确对应；以前仅活动/睡眠的审核资料不能当作已更新。

## 执行记录

实际静态检查、回归、归档、分发签名、上传及Apple处理状态随后逐项追加；失败保留。日志与凭据相关返回仅保存在受保护的本地目录，不读取或记录密码、Keychain秘密或健康记录。

- 修改后flutter analyze零问题（3.3s），Python发布门禁25/25（6.046s），UTC/Shanghai各1110通过。仅版本元数据变化，复用同日1019产品Android Debug/QA Release及iOS Debug/Profile已记录结果；1020正式Release另行实际归档，未重写这些旧结果为1020矩阵。
- 归档使用SAIDIAN_PRODUCTION_RELEASE=true/SAIDIAN_ALLOW_QA_RELEASE=false/SAIDIAN_DISABLE_REMOTE_PUSH=true、空JPush，独立archive-1020.xcconfig沿用已验证美国配置和Xcode27最低15.0。命令为 `flutter --no-version-check build ipa --release --no-pub --target=lib/main.dart --build-name=1.0.1 --build-number=1020 --export-options-plist=build/store-upload-20261017-1020/ExportOptions-Local.plist --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.com --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.com/global/api/saydian-app/v2/support/app-update --dart-define=JPUSH_APP_KEY=`，私有日志archive-export.log。iOS构建串行，无其他xcodebuild。原1018归档及导出均另存，未撤回旧审核。

- Flutter build ipa返回0、已生成256.9MB的1020归档，但日志明确Encountered error while creating the IPA：exportArchive No Accounts / No signing certificate iOS Distribution found。进程返回0不等于IPA导出成功。首次候选IPA验证严格核对CFBundleVersion时失败，发现复制的是默认导出目录残留1018；该旧副本已单独移至rejected-stale-1018-export，失败验证目录保留，未上传。不能只看退出码或旧IPA文件存在。
- 现有codesigning身份元数据只读核对：1个有效Development、0个有效Distribution；未读取私钥、密码或Keychain凭据。已打开当前1020归档与Xcode设置，并请用户在Accounts登录开发者账号/二次验证。后续将优先使用已有团队自动分发签名，不擅自撤销其他证书。
- 1020归档内Info版本/包名/SayDian名称/iPhone-only核对通过，deep/strict签名完整性通过（仍是开发签名归档，不是分发IPA）；实际AOT包含批准.com origin、不包含IOS_WELLNESS_QA_，打包框架无requestAlwaysAuthorization，后台仅bluetooth-central。结构证据archive-verification.json明确distributionIpaReady=false/uploaded=false。此静态包检查不解除XR读数、设备增长、硬件准确性或全部网络路径动态验收边界。
- 待账号就绪后按顺序执行：`xcodebuild -exportArchive -archivePath build/store-upload-20261017-1020/Runner.xcarchive -exportPath build/store-upload-20261017-1020/export -exportOptionsPlist build/store-upload-20261017-1020/ExportOptions-Local.plist -allowProvisioningUpdates`；再次核对IPA1020/分发Authority、entitlements/get-task-allow=false和SHA256，通过后才用专用ExportOptions-Upload.plist上传同一归档。若Apple报告构建号冲突则顺延并重建，不能改签后的包冒充新归档。
- 当前交付边界：新归档准备完成，IPA正式导出及上传未完成，Apple处理状态无回执；旧1018审核和两台iPhone的1019安装均未修改。仅版本元数据与记录本地提交，不宣称远端推送或CI新成功。

## 接续重试与Xcode账号登录

用户要求继续，起始clean a9f6093，fetch成功，当前分支无tracking的ff-only pull仍拒绝。先确认归档仍为cn.saydian.app.global/1.0.1(1020)，没有并行xcodebuild，身份元数据仍Development1/Distribution0。使用allowProvisioningUpdates实际重试导出，退出70/EXPORT FAILED，仍为No Accounts/No signing certificate，私有export-retry-continue.log保留。未上传、未把网页登录视作Xcode授权。已用系统设置导航实际切到Xcode Apple Accounts页面；用户随后明确回复“已在Xcode完成登录”。正在仅重试相同归档导出；签名及版本验证通过后才上传，不重建源代码、不重复无变化的回归、不改现有审核构建。

- 用户在实际Apple Accounts页确认登录后，同一1020归档自动导出退出0/EXPORT SUCCEEDED，私有export-after-xcode-login.log保留。新正式IPA为build/store-upload-20261017-1020/export/SayDian.ipa，37,930,560bytes，SHA256 9bd7d474a7a5518d0e0ebfe8e54f9fa347605d9a0fd1e635f0279d8301800700。实际包名cn.saydian.app.global、版本1.0.1(1020)、SayDian、iPhone-only/minimum15.0，deep/strict签名与Apple Distribution Authority、team/application identifier、get-task-allow=false及App Store profile核验通过。实际AOT批准.com origin存在、QA标识不存在；无Always location请求。签名来源按导出包实证，不以本机身份数量推断云签名不可用。
- 上传前增加归档与导出一致性校验，初版按签名后二进制全文件SHA比较而失败，尚未执行上传；完整文件含重签变更的签名区域，不能据差异认定程序代码不同。首个修正版仅支持thin Mach-O，又因实际单arm64的fat封装失败。最终正确解析fat arm64切片，LC_UUID一致、全部3个有文件数据的section逐字节hash一致；archive-export-code-proof.json保留，分发完整签名仍严格验证。只修私有验证脚本，没有改产品或放宽代码内容一致性门禁。
- 通过后才实际运行 `xcodebuild -exportArchive -archivePath build/store-upload-20261017-1020/Runner.xcarchive -exportPath build/store-upload-20261017-1020/upload-1020 -exportOptionsPlist build/store-upload-20261017-1020/ExportOptions-Upload.plist -allowProvisioningUpdates`；该模式由Xcode对同一未修改归档导出并上传，不能把本地IPA压缩文件hash称作Apple实际重导出上传文件hash。上传进程正在执行，回执待追加；不替换1018审核关联、不发送新测试邀请。

## 上传最终结果

- Xcode上传最终退出0，原始日志明确upload succeeded及EXPORT SUCCEEDED，ContentDelivery包含UPLOAD_COMPLETE。来源归档仍1.0.1(1020)，上传配置manageAppVersionAndBuildNumber=false；已写build/store-upload-20261017-1020/upload-receipt.json，uploaded=true。首次私有回执解析按大写字面量查找而失败，实际日志成功文本有大小写差异；改为不区分大小写后通过，并保留退出0/ContentDelivery独立完成标记，不重传已接受构建。
- 15个厂商预编译framework存在missing-dSYM上传警告，未阻止交付：ABParTool、BluetoothLibrary、GRDFUSDK、JLAV2Lib、JLAudioUnitKit、JLBmpConvertKit、JLDialUnit、JLLogHelper、JLPackageResKit、JL_AdvParse、JL_BLEKit、JL_HashPair、JL_OTALib、RTKLEFoundation、RTKOTASDK。仍有限制厂商栈崩溃符号化的风险；未伪造符号或重编译闭源SDK。
- 本轮已完成正常1020归档、正式IPA验证及Apple上传；Apple后续processing/可选构建状态未单独在App Store Connect读取，不能写处理完成/审核通过/已公开发布。没有替换1018审核构建、撤回审核、提交新审核或增加测试邀请。若现有TestFlight分组自动接收新构建，不等于新测试验收或安装完成。
- XR既有读数持久化差异、真实新样本首ACK/回读/当天增长和新增本机功能的正式描述/截图/政策材料边界继续保留；上传不能解除这些条件。产品源码未再修改，没有重复重建/全量回归；先前静态检查、发布25及双时区各1110的证据仍限本轮同一产品代码。记录保留在本地Git，不宣称新远端CI已完成。
