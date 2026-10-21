# Security Center v1.0.5

金银湖安全发行版板载安全中心应用。

基于 [munos1233/securitycenter](https://github.com/munos1233/securitycenter) `main@f943f5b` (2026-10-20) 构建。

## 板卡适配修改（3 处）

| 文件 | 修改 | 原因 |
|---|---|---|
| `probe/UpdateReject.ets` | `isSignatureReject()` 加入错误码 `17700073` | 本板 BMS 拒绝更新时返回 17700073，上游无此码 |
| `probe/SandboxIsolationProbe.ets` | `callKind()` 将 stat 成功但 open 被拒判为 `denial`（隔离有效） | 32 位板跨包 URI 允许 stat 但拒绝 open，上游将 stat 成功判为异常 |
| `AppScope/app.json5` | 版本号 `1000000` → `1000005` | 部署递增 |

## 构建方式

```bash
# 需要 OpenHarmony SDK 26 + hvigor 6.26.8 + JDK 17
hvigor --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap --no-daemon
```

## 功能

- **P1 安装完整性检测**（含更新拒绝识别 + 拒绝事件联动）
- **P2 应用隔离检测**（五条路径沙箱探针 + URI 深度检测）
- **P3 安全控件检测**
- 更新拒绝事件联动（笔记 app → `startAbility` → 安全中心显示"系统拒绝了更新"）
