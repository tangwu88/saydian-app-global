# 2026-10-02 SAYDIAN Health 个人资料保存故障

## 原因与范围

- 用户要求参考已修正的赛电戒指 App，修复个人资料保存失败。工作树基线 `add0a4078659d0efb2af43cc5185fbf31a08109b`；已 fetch origin，当前分支远端一致。其他现有修改保持原样；修改前补丁与未跟踪文件备份位于忽略目录 `build/ios/real-device-qa-20261002/checkpoints/`。
- 只读比对 Say Ring 上传实现与服务端：资料 PUT 契约相同；国际 Health 仍使用依赖对象存储的旧共享上传入口。专用头像入口属于相同国际 realm 和账号，服务端按当前会员归属，不按 App 包名限制。
- 用用户提供的审核演示账号和本项目官方 App 图标验证：旧 `POST /global/api/saydian-app/v2/files?purpose=avatar` 返回 503（requestId `f64a5a84-60e0-40c1-8391-070d4692a999`）；戒指专用入口返回 201（requestId `6adf6f56-17e6-4a37-9e72-51f4bbdfec4d`）。该上传未改变账号头像或资料。
- 第一次探针发现服务器返回 URL 是同源 `/api/saydian-app/v2/files/<UUID>`，因缺 `/global` 被边界检查拒绝，探针退出 1。第二次确认相同现象并仅请求映射后的 `/global` 文件地址，返回 200/image/png。保留失败记录；没有请求国内文件地址。

## 预期改动

- `lib/services/global_api_client.dart`：头像上传与戒指使用同一可写入口；仅对同源、精确 UUID 的头像文件 URL 映射国际路径。头像上传和个人资料头像回读共同使用此处理，其他媒体/API 边界保持原样。
- `test/global_api_test.dart`：以旧接口 503、专用入口 201 和实际 canonical 文件 URL 复现问题；校验 multipart、鉴权及非法地址拒绝。按 TDD 先复现失败再实施。
- 保留控制器既有账号代次、数值范围和保存后回读校验；不把服务端回读失败伪装成保存成功。

## 验证记录

- RED：单跑上传故障用例，在旧共享入口模拟 503，按预期失败；单跑头像回读用例，旧客户端把 canonical 地址变成空串，按预期失败。两项都先于运行时代码修改。
- `dart format lib/services/global_api_client.dart test/global_api_test.dart`：仅格式化这两个修改文件。`TMPDIR=/private/tmp flutter test --no-pub test/global_api_test.dart test/global_network_boundary_test.dart test/login_page_test.dart test/ui_shell_test.dart --reporter expanded`：128 项通过；日志 `build/ios/real-device-qa-20261002/profile-targeted-tests.log`。
- `TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub --reporter expanded` 与 UTC 同命令：各 944 项通过，日志分别为 `profile-full-tests.log`、`profile-full-tests-utc.log`。`flutter analyze --no-pub` 和 `git diff --check` 通过。
- 演示账号以官方品牌图标测试真实上传 → 头像资料 PUT → GET 一致 → 图片 GET 200；其他原资料逐项一致。随后将头像恢复为测试前状态，再 GET 确认完整资料对象与初始对象严格相同。上传 201 requestId `8286bc10-c186-40ce-9915-6e544d1ff639`；保存 200 `c426d030-8ccf-4b0f-afd7-bb2cba4b253f`；回读 200 `9c4a0554-0197-413a-bbf0-40c931339c61`；恢复 200 `3a8fefc1-ba36-4b72-b483-4693cb24554e`。未上传私人照片，诊断生成的品牌图标文件保留在受控国际头像存储中。
- 新增聚焦真机驱动 `integration_test/ios_profile_avatar_qa_test.dart` 与 `test_driver/ios_profile_avatar_qa_test.dart`，复用手机原有会话且不启动手表同步。初次 analyzer 提示一个未使用 import，删除后零问题。驱动只在已有真实字段完整时测试原值保存并恢复头像；缺字段则只验证上传/读取，不填假值。
- `TMPDIR=/private/tmp flutter drive --no-pub --driver=test_driver/ios_profile_avatar_qa_test.dart --target=integration_test/ios_profile_avatar_qa_test.dart --device-id <当前 iPhone>`：Xcode Debug 构建、覆盖安装、VM attach 和真实用例执行均成功，驱动退出 0。iPhone 15 Pro Max/iOS 26.6 的当前账号缺少生日、身高、体重，故完整表单写入分支未执行；真实生产客户端头像上传 201（requestId `9e4135c3-ef45-46b8-a51f-23a633ec4666`）、图片 GET 200，资料 GET 200。没有修改该真机账号资料。
- 本轮个人资料实机截图 `build/ios/real-device-qa-20261002/screenshots/profile-avatar-fix/profile-after-avatar-fix.png` 已视觉检查：中文表单、头像入口、读取后的空值和保存按钮正常；截图私有留存，不上传 Git。驱动日志 `profile-device-test.log` 保留明确 skipped 保存边界，不将其写为完整表单真机验收。
- Android 本轮按用户此前“先苹果、Android 放后面”的要求不构建；没有修改服务端、戒指 App 源码或 App Store 审核中的安装包。
- `TMPDIR=/private/tmp flutter build ios --profile --no-codesign --no-pub`：97.8 秒 Xcode 构建，退出 0，生成 61.8 MB `.app`。这是无签名 Profile 编译回归，未当作独立安装或 App Store 归档。
- 随后 `flutter run --debug --no-pub --device-connection attached --device-id <当前 iPhone>`：正常 `lib/main.dart` 构建 51.4 秒、安装/启动 22.4 秒；已覆盖聚焦测试包。实际设备应用回读 `SAYDIAN Health / cn.saydian.app.global / 1.0.0 (1012)`；VM `/getVM` 返回 JSON，热重载 312ms，普通 Debug 会话保持运行。现有插件 SwiftPM/模拟器架构警告保留，本轮真机 Debug 不受其影响。
- 正常启动日志包含首次关爱读取 `NETWORK_UNAVAILABLE` 和既有更新清单 404；随后主要 GET 返回 200，自动 POST 返回 201（requestId `c742db88-9afd-46fb-8497-cfe574b8b39f`）。未点击手表上传重试，不将普通启动当作全业务复验。
- 本轮仅提交头像运行时代码、其回归测试/聚焦真机驱动和本记录；其他上轮连接、国际化、客服和远程关爱等未提交修改继续保留，避免混入此次修复提交。
