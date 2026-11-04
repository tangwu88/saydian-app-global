# 2026-11-04 国际版 1022 iPhone 15 Pro Max 真机调试

用户明确要求安装到 iPhone 15 Pro Max 并开启调试。基线 8346d47a7578f5aa9d9c4981c9bfa742d4c860e3，origin fetch/ff-only 检查通过、工作区干净。本轮只签名、保留数据覆盖安装和启动正常 lib/main.dart；不修改产品源码或商店版本。此前 1022 的双时区各1151/两端构建与美国三项合成数据服务器验收按原记录保留，不作为新手机实测。

设备当前 USB wired、paired、booted、Developer Mode enabled、已解锁；原安装 1.0.1(1020)。指定手机为 iPhone15pm / iPhone 15 Pro Max，另一 XR 的独立 SayRing 调试进程不操作。同仓库没有并行 Xcode 构建。

私有本轮日志位于 /private/tmp/saydian-iphone15-debug-20261104/；应用 Documents、Application Support 和 Preferences 在安装前做受限目录备份，不导出 Keychain 或解密健康库、不入 Git。执行签名构建使用既有 Apple Development 身份、团队 W7SXQ4A226、Xcode27/iOS15 私有覆盖，明确 .com API/update 与关闭推送。

## 实际结果

待逐项补充：备份/严格签名/手动覆盖前后数据库比对/正式安装列表/正常 Flutter run/VM 和热重载。当前不声称安装或采集已成功。

## 签名、安装与数据恢复

签名 Debug 正常构建20.9秒，严格 codesign 验证、get-task-allow=true、团队 W7SXQ4A226、描述文件含指定手机通过。实际 cn.saydian.app.global /1.0.2/1022，Runner SHA256 f93af760651827fed03ac8c900ec31cf08f73b7a27479d05df905fd1390cf015。

首次签名检查使用 codesign `--entitlements -`，Xcode27输出字典文本而非 plist，解析失败。脚本未启用 errexit，后续安装尝试对未生成的候选目录报文件不存在；未将此失败当安装成功。改用已知的 `--entitlements :-` XML方式并强制前置校验成功后执行，后续真实 devicectl 安装回执 success，官方安装列表实际为1022。

随后发现应用数据容器为空：Documents 复制无文件、Application Support 不存在，实际目录枚举予以确认。未把这一状态声称“覆盖即保留”，也未把根因臆断为某条安装命令；原始受限备份仍完整。第一次复制到未存在目标路径报本机目录不存在，后续显式创建读取目录。为保护数据，在启动前只向同一国际版容器恢复安装前备份的 Documents、Application Support、Preferences，不导入其他账号/国内域数据，不解密或改写记录。

恢复后的全量回读比对通过：6文件/10,123,002bytes全部逐字节一致，其中3数据库/9,646,080bytes；备份原件保持只读。此证据是**恢复后、启动前**，不是自动覆盖保留成功，也不是正常运行后的数据库不变承诺。

为避免再次安装造成不确定性，采用系统原生 start-stopped 启动已验证1022、LLDB附加后continue，再 Flutter attach到正常main源码。未再次安装、卸载或清库。Flutter attach不支持--no-pub，初次解析失败；移除仅该无效选项重试。Flutter SDK既有JIT helper用于原生调试器。当前手机已渲染已登录英文首页，但系统本地网络权限弹窗阻止Flutter服务发现，已请用户在手机点允许；不能声称VM/热重载通过，待实际回执追加。

## 当前交付边界

实际已安装、签名通过、原数据恢复并验证、正常英文首页已渲染且原登录状态可见。原生 LLDB 保持附加；Flutter attach 正等待系统本地网络权限允许后的服务发现。未将仅有原生进程或画面当作 Dart VM/热重载成功。无需用户发送账号或密码。

顺便实读同一1022源码CI41766547984：quality、android、ios及双时区Harmony contracts共五个job均 completed/success。此为实际远端CI终态，不等同当前手机测量/上云验收。此次没有产品源码改动，不重复先前已通过的1151双时区全量/Android等构建；仅本次新的设备签名构建/安装/恢复/附加另记。
