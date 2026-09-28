# U19 原生连接排空修复（2026-09-28）

## 范围和基线

- 基线 `41fe3e5677c69821c9a544a9437bdb6ab67317e2`，`feature/u19-eb1`；主任务已核对远端一致，本子任务开始时工作树干净。阅读 `AGENTS.md`、最新功能审计、跨模块复盘及回归清单后实施。
- 原问题：Android/iOS 的 `disconnect` 在提交断开请求后立即返回，旧原生连接仍在取消；紧接的 `connect` 可与旧连接清理重叠。预期必须在旧连接关闭/取消回调确认后才开始下一连接。此为 P1 生命周期边界修复，尚不能据此确认此前“覆盖安装后首次服务发现超时”的根因。
- 本轮只修改 U19 原生传输层、相关测试和本文。没有修改 Dart 健康解析、设备设置、账号、服务端或用户数据；没有控制手机或触发测量。

## 修改

- Android 增加可独立测试的 `UrionGattDrain`。断开应答、下一次连接均等待旧 GATT 实际调用 `close()` 完成；原有 2 秒期限仅触发兜底关闭，不提前成功返回。
- 原生断开回调到达时立即关闭旧客户端；重复/迟到回调不关闭两次，也不能释放新连接的等待。已收到 `STATE_DISCONNECTED` 的活动连接立即完成排空。
- 等待期间保留连接请求身份和代次；并发连接拒绝，用户取消会使等待中的连接请求失效。`close()` 自身异常时返回失败并禁止复用该传输实例开启下一连接。
- iOS 等待 `didDisconnectPeripheral` 或 `didFailToConnect`。CoreBluetooth 没有等价 `close()`，5 秒等待过期返回仍在关闭错误并保留旧连接隔离；不把超时当作取消完成。取消期间迟到的 `didConnect` 再次请求取消，不能推进服务发现。

## 验证记录

1. `node --test tool/test_urion_native_lifecycle.mjs`：Android 接线门禁首轮 2/2；增加 iOS 修复后 3/3，通过。此项只证明代码入口按要求连接排空门禁，不替代真机。
2. 使用本机既有 JDK 17、缓存 Kotlin compiler 2.2.20 / stdlib、JUnit 4.12 / Hamcrest 1.3，在独立 `build/` 产物路径直接执行：

   ```text
   java -cp <缓存编译器及其依赖> org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -jvm-target 17 -classpath <stdlib;junit;hamcrest> -d build/u19-native-drain-test.jar android/app/src/main/kotlin/cc/saidian/saydian_app/UrionGattDrain.kt android/app/src/test/kotlin/cc/saidian/saydian_app/UrionGattDrainTest.kt
   java -cp <build/u19-native-drain-test.jar;stdlib;junit;hamcrest> org.junit.runner.JUnitCore cc.saidian.saydian_app.UrionGattDrainTest
   ```

   结果 6/6，通过：实际关闭后完成、超时先关闭后放行、重复迟到回调、新旧多个客户端/多个等待者、disconnect 异常后关闭、close 异常拒绝后续连接。没有下载依赖、没有启动 Flutter/Gradle 构建。相同测试已放在 Android 标准测试目录，主任务可通过 `android/gradlew.bat :app:testDebugUnitTest` 复验。
3. 另以本机 Android API 36 `android.jar`、现有 Flutter embedding debug JAR、stdlib 为 classpath，执行同一 `K2JVMCompiler` 编译 `UrionGattDrain.kt` 与 `UrionGattTransport.kt` 至 `build/u19-native-transport-check.jar`：通过。保留原有两个旧 API override 弃用提示，未抑制告警。此独立编译不等于 APK 构建。
4. 搜索早期假定的 Flutter engine `android-arm64/flutter.jar` 未找到；改用已有 Gradle 缓存 `flutter_embedding_debug` JAR 完成独立编译。未创建替代 SDK 或改工程依赖。
5. 本 Windows 主机没有 Swift/CoreBluetooth 编译器；iOS 仅完成代码复核和源码门禁，未执行 iOS 编译或真机验收。Harmony 目录未找到 U19 原生实现，本轮没有新建其架构或宣称三端完成。
6. `git diff --check` 通过，仅现有 CRLF 转换提示。完整 Flutter/Android 构建、安装和真机回归由主任务统一执行；本子任务未提交、推送或部署。

## 待验收

- 当前华为手机连续断开—重连、取消连接后立即重试，以及覆盖安装后的首次服务发现。
- iOS 无签名编译及实际断开/取消/蓝牙关闭恢复，确认排空失败提示与重试路径。
- 不能以本次原生生命周期测试通过，替代测量有效样本、日汇总保存/云端回读或查找手表实体振动证据。
