# U19 交接包生成与校验记录（2026-09-29）

## 修改原因与范围

- 用户要求将本任务整理打包并提交 Git，供下一位同事继续。仅新增交接说明、索引和本记录；没有修改 App/服务端运行时代码、配置或数据库。
- 开始前 App `feature/u19-eb1` 工作树干净，`git fetch origin --prune` 与 `git pull --ff-only` 后仍为 `19adbfcda6504631d7212137d59563bc17ca708f`；服务端 `fix/global-health-daily-summary-capabilities` 工作树干净，远端同名分支仍为 `ef51e665babdc3c9e5cd1b7a7dbb24e918c84695`。服务端 `main` 未修改。
- 影响文件：`docs/U19-HANDOFF-20260929.md`、`docs/CHANGE-TEST-LOG.md`、本文件；本地 ZIP 在仓库外，不提交编译产物、原始协议或健康日志。

## 包与内容

- 本地交付：`F:/xcodeplace/国内电商/交接产物/SAYDIAN-Health-U19-交接包-20260929.zip`，94,212,169 字节，SHA-256 `62C586138059DCB601B38869E4E4B07C6B0A1975441326287BBD69707DD2A644`。
- 外层 8 项：`START-HERE.md`、`SHA256SUMS.txt`、两份固定提交源码 ZIP、三份脱敏联调记录及一份内部 QA APK。App 源码快照固定 `19adbfc`，服务端源码快照固定 `ef51e66`；两者不含 `.git` 历史，接手后仍须先更新远端。
- 内部 APK SHA-256 `1A4551E49D76FAA850B38E986CFA3CDDDA0898746BBDD7D37B2779F173A8BE0E` 与已记录的 Android QA 构建一致。它不是正式商店签名，也不是新一轮真机验收。

## 校验、失败与结论

| 检查 | 结果 |
| --- | --- |
| `git archive` 两个固定提交 | 成功；App ZIP 1098 个文件、服务端 ZIP 631 个文件。 |
| 两份源码 ZIP 逐条解压到空流 | 1356/728 个 ZIP 条目可完整读取；路径穿越、绝对路径、真实 `.env`、密钥文件和构建缓存命名命中数均为 0。 |
| 包内 `SHA256SUMS.txt` | 7/7 个实际负载文件与列出的哈希一致；外层 ZIP 每一项重新读取并计算哈希，8 个条目、7 个清单行，缺失/多余/不匹配/不安全路径均为 0。 |
| 交接说明与脱敏记录 | 未命中私钥/GitHub Token/AWS Key 样式、MAC 地址或邮箱地址的快速检查。文本模式检查不是对二进制 APK 的密钥审计。 |
| 代码文本快速扫描 | App 无上述密钥样式命中；服务端仅 `apps/admin-web/src/integration-settings.test.ts` 的 PEM 格式**合成测试夹具**命中，已按上下文人工核对，非私钥文件。首次 `git grep` 因模式以 `-` 开头被当作选项失败，补 `-e` 后完成；失败过程保留。 |
| `git count-objects -vH` | 本地两仓曾提示若干无对应 pack 的孤立 `.idx` 文件；`fetch`、`git archive` 和 ZIP 逐条读取均成功。本次没有为整理包运行 Git 清理或重写对象。 |

本轮是文档与打包任务，未重新执行 Flutter 测试或真机测量；当前 929×2 测试与跨平台 CI 结论来自 `19adbfc`，详见[联合复核记录](U19-JOINT-LIVE-QA-20260929.md)。服务端隔离环境尚无可核验写入地址，生产能力路由先前为 404；交接包不应被用作发布许可。
