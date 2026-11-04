# 2026-11-04 美国数据存储提示

用户要求在连接帮助、隐私政策、数据同步等位置增加美国本地存储提示。基线4bb0be63fcc7c10eef2345166923a44659a7348f，origin fetch/ff-only通过、工作树干净；独立分支codex/us-storage-notices-20261104。

本轮是已有已审核美国存储事实的界面提示，不改r4法律正文、协议版本、账号/采集/上传/ACK/关爱权限。说明SayDian云端数据位于美国；待上传数据在手机保留，直到服务器确认。美国声明只指第一方云端，不笼统保证手机或第三方服务都位于美国，不承诺绝对安全。首页不新增提示横幅，沿用用户此前的页面安排。

实施范围：共享短提示、连接帮助页、设备同步区域及已加载的隐私政策页；现有完整Data privacy说明保留。英文默认，其他现有语言同步。现有iPhone15pm/1022调试正常，采用热重载验证本轮UI，保留安装数据、登录态和另一XR的独立调试。

验证结果与失败记录随后按实补充。尚未将界面文案改动当作新的真实测量上云或商店发布。

## 过程修正

初次analyzer发现原私有_InfoPage因连接帮助改用可滚动的ConnectionHelpPage而不再使用，已移除未引用类；离线截图夹具误给只读deviceState赋值，已移除无效赋值。没有修改设备状态机。初轮自动测试日志保留，最终检查另记。

初次真机热重载后出现Flutter SDK ListenableBuilder构造器NoSuchMethodError，随后进程退出（status0）。没有据此声称新文案已在手机通过。保留堆栈；不改SDK或健康业务，改为完整iOS签名构建并对齐调试编译选项后重新启动正常入口。新一轮安装前再次独立备份当前手机数据，6文件，受限保留于用户私有备份目录。恢复与附加的实际结果后续追加。

新界面提示不触发同步、不标记ACK、不记录协议同意。r4已发布正文保持不变，无需创建新法律版本。

小屏截图额外复现320宽/1.8倍文字时设备同步区域右侧溢出29px。保留失败截图与日志；同步/断开按钮在窄屏或大字体下改为纵向排列，待上传说明与重试按钮使用可换行布局，操作回调及同步状态来源不变。美国提示本身保持自动换行，不压缩用户字体。随后重新运行截图和回归。

## 最终自动回归和布局

最终源码analyzer零问题（5.1秒）；UTC全量1151/1151（50秒）、Asia/Shanghai全量1151/1151（40秒），退出0。未新增为简单文案镜像实现的测试；复用现有全量及opt-in离线截图入口，扩展两个空数据页面用于视觉核对。

连接帮助411宽正常字体截图通过；设备同步320宽/1.8倍文字截图在自适应修正后通过，无RenderFlex溢出。两张截图已实际打开检查，文字均英文，图标与段落可读。图片来自离线空数据夹具，不是真实采集或云端成功证明。预览位于忽略目录build/us-storage-notices-20261104/help与sync-r2。

Android Play Debug13.3秒和内部QA Release30.1秒通过；推送仍关闭、ARM双ABI不变。串行iOS Profile及开发签名Debug正在运行，实际结果随后追加。dart format/diff检查通过。r4法律内容没有变更，不产生新的法律版本或发布动作。

## 最终构建、安装与调试结果

串行iOS Profile无签名50.4秒、开发签名Debug23.9秒通过；最初手动安装的已验证候选Runner SHA256 d1039ab558448d370ea07608d9e0fc7216851a286e24442cec14b4e7825b948c，实际cn.saydian.app.global/1.0.2(1022)，strict codesign/手机描述文件通过。手动覆盖后、启动前与最新私有备份逐字节核对，5个Documents/Application Support文件/10,127,599bytes（3数据库）一致；未出现空容器，未恢复或覆盖原记录。Preferences另有备份。

手动LLDB恢复时先遇到异步attach后过早continue的“Process must be launched”，再出现EXC_BAD_ACCESS；保留日志并停止本任务的旧进程/手动LLDB，不停止XR或其他产品会话。没有把这次手动附加当成功。随后改用标准Flutter run正常lib/main.dart、--no-uninstall-first、--track-widget-creation及相同美国defines，SDK自行管理编译/安装/LLDB。标准流程Xcode18.9秒、安装启动82.7秒、源码同步139ms；实际VM/main isolate及国际版进程PID1971匹配。

标准流程后SIGUSR1热重载真实回执 `Reloaded 8 of 2224 libraries in 675ms (compile:112ms,reload:128ms,reassemble:70ms)`，后续无NoSuchMethod/EXCEPTION/断连；调试器保持附加。新DevTools已替换旧会话。运行中设备文件元数据确认3个数据库仍在（9,650,176bytes）；这不是运行后的逐字节不变断言。临时运行时UI导航evaluate返回113未执行页面跳转；页面位置与小屏视觉证据使用已注明的离线真实组件截图，不冒充真机逐页点击验收。

当前活动会话指针在私有 `/private/tmp/saydian-us-notices-20261104/debug-session.json`，不要使用旧iphone15-debug目录里的会话URI。原始运行日志/截图/会话URI/备份不入Git；其余证据保留受限目录。手机可继续使用当前更新后的1022调试包，独立重启仍遵守Debug需附加工具的既有规则。本轮没有上传新商店包或改变在线法律文档。

## Git与CI

本机源码ff4007b5bb1a8f1805b4135a995ba884c38e80b5通过已授权GitHub连接发布为748aaaaed9884ade0e2ea84e66e59fbf0f2c0ef8，完整tree a6e3b6beb2eae49208e2cc0108139600a5c0a4bf一致。已fetch/diff核对并跟踪规范远端；原本机历史保留codex/us-storage-notices-local-20261104，没有main合并或force push。源码CI41774487076已触发，送交记录时仍在运行；最终状态另验，不将本机通过当云端已通过。本次追加仅文档，跳过重复CI。

手机前台切回本国际版同一PID1971后，实际设备页已显示已连接U19S、美国数据存储提示及独立的云同步状态。该页实拍已打开检查，当前手机使用中文设置；英文版连接帮助另有已标注离线组件预览。此单页实拍补充真实UI证据，不代表隐私/帮助全部真机逐页验收，也不证明三项新测量的逐条ACK。
