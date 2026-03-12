---
name: codex-bridge
description: >
  Synchronous bridge from Cowork to Claude Code CLI. Dispatches skill commands
  on the host machine and returns results directly into the Cowork session.
  Replaces the old async codex-dispatch with result capture.
  Use when the user mentions 'build', 'compile', 'test', 'verify', '编译',
  '构建', '测试', '跑一下', 'run dual-build', 'run slice-execute', '跑双构建',
  'dispatch codex', 'codex bridge', or when code needs to be compiled, tested,
  or verified on the host machine. Always confirm with the user before dispatching.
argument-hint: "<skill-command> [args]"
---

# Codex Bridge — Cowork ↔ Claude Code 同步桥接

从 Cowork 向宿主机 Claude Code CLI 派发 skill，**同步等待完成并回收结果**。

---

## 与旧 codex-dispatch 的区别

| 维度 | codex-dispatch | codex-bridge |
|------|----------------|--------------|
| 执行 | osascript 异步 | Desktop Commander 同步 |
| 结果 | 手动查看 Terminal | 自动回收到 Cowork |
| 项目 | 硬编码 super-founder | 多项目自动检测 |
| 长任务 | 唯一模式 | 可 fallback 到异步 |

## 可调度的 Skills

| Skill | 命令 | 预估耗时 | 模式 | allowedTools |
|-------|------|----------|------|--------------|
| dual-build | `/dual-build [--fix-preview]` | ~60s | 同步 | Bash Read Grep Glob Write Edit |
| slice-execute | `/slice-execute <spec.md>` | ~5min | 异步 | Bash Read Grep Glob Write Edit |
| compliance-audit | `/compliance-audit [incremental\|full]` | ~30s | 同步 | Bash Read Grep Glob |
| p0-gate | `/p0-gate` | ~45s | 同步 | Bash Read Grep Glob |

**注意**：`dual-audit` 已由 `tzhos-toolkit:ggp` 接管，不再通过 codex-bridge 派发。

## 执行流程

### Step 1: 确定项目路径

按 PPR v2.1 四域结构检测：

```bash
# 已知项目路径
PROJECTS=(
  "/Users/tongzhenghui/Workspace/01_Repos/_platform/super-founder"
  "/Users/tongzhenghui/Workspace/01_Repos/_infra/guanghe"
)
```

推断逻辑：
1. 用户指定路径 → 直接使用
2. 上下文提到项目名 → 匹配已知路径
3. 都没有 → 询问用户

验证：通过 Desktop Commander 检查 `Package.swift` 或 `package.json` 存在。

### Step 2: 确认执行

向用户展示确认信息：

```
⚠️ 需确认执行：
$ cd {PROJECT_PATH} && claude -p '{SKILL_COMMAND}' --allowedTools '{TOOLS}'
影响：{一句话说明}
预估耗时：{时间}
```

用户回复「执行」「y」后继续。

### Step 3: 启动执行

统一使用 osascript + 日志捕获模式（实测 Desktop Commander `start_process` 有 60s 硬限，`claude -p` 启动即超时）。

通过 `mcp__Control_your_Mac__osascript` 启动：

```applescript
tell application "Terminal"
    activate
    do script "source ~/.zshrc && cd '{PROJECT_PATH}' && claude -p '{SKILL_COMMAND}' --allowedTools '{TOOLS}' 2>&1 | tee /tmp/codex-bridge-output.log; echo '===CODEX_BRIDGE_DONE===' >> /tmp/codex-bridge-output.log"
end tell
```

关键设计：
- `tee` 同时写 stdout（Terminal 可视）和 log 文件（Cowork 可回收）
- sentinel `===CODEX_BRIDGE_DONE===` 标记完成
- 长任务（slice-execute）和短任务（p0-gate）使用同一机制

### Step 4: 轮询回收结果

启动后根据预估耗时设置首次轮询等待时间：

| Skill | 首次轮询等待 | 最大轮询次数 |
|-------|-------------|-------------|
| dual-build | 45s | 4 |
| compliance-audit | 20s | 3 |
| p0-gate | 30s | 3 |
| slice-execute | 120s | 6 |

通过 Desktop Commander 轮询：

```bash
# 首次等待后检查 sentinel
sleep {WAIT_SECONDS} && grep -c 'CODEX_BRIDGE_DONE' /tmp/codex-bridge-output.log 2>/dev/null
```

- sentinel 存在 → 读取 log 全文
- sentinel 不存在 → 继续等待或通知用户"仍在执行，可稍后问我结果"

读取结果：
```bash
cat /tmp/codex-bridge-output.log
```

### Step 5: 呈现结果

解析 log 内容，向用户呈现：

```
## codex-bridge 执行结果

**Skill**: {name}
**项目**: {project} @ {commit}
**状态**: ✅ 成功 / ❌ 失败

{关键输出摘要}
```

### Step 5: 后续动作建议

根据结果自动建议下一步：

| 结果 | 建议 |
|------|------|
| dual-build 成功 | "可以 commit。需要先跑 GGP 审计吗？" |
| dual-build 失败 | 列出错误，建议修复方向 |
| p0-gate 通过 | "P0 gate 通过，可以继续下一个 slice" |
| p0-gate 失败 | 列出未通过项 |
| compliance-audit 通过 | "合规检查通过" |

---

## 约束

- **同步模式受 Desktop Commander 超时限制**。超过设定时间自动降级为异步。
- **不自动执行**。所有派发必须经用户确认。
- **不替代 GGP**。代码审计走 `tzhos-toolkit:ggp`，编译/测试走 codex-bridge。
- **Claude Code CLI 必须已安装**。验证：`which claude`。
