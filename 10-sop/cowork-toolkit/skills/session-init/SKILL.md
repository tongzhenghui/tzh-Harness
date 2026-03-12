---
name: session-init
description: >
  PPR session initialization protocol. Sets up Cowork session working context
  by detecting active projects, loading project-level CLAUDE.md, and writing
  session state to /tmp/cowork-session.json. Use at session start after
  healthcheck, or when the user says 'init', 'session init', '初始化',
  '开始工作', 'start session', 'set context', or '设置上下文'.
  Also use when switching between PPR domains mid-session.
disable-model-invocation: true
---

# Session Init — PPR v2.1 Session 初始化协议

在 healthcheck 完成后，根据用户选择的工作域初始化 session 上下文。写入 session 状态文件，加载项目级配置，建立本次 session 的工作焦点。

**与 healthcheck 的分工**：healthcheck 只读诊断 → session-init 有写入权限的初始化动作。

---

## 执行流程

### Step 1: 确定焦点域

如果 healthcheck 已运行，从其报告中提取可用域。否则通过 Desktop Commander 快速探测：

```bash
for d in _governance _infra/guanghe _platform/super-founder huanlong; do
  test -d "/Users/tongzhenghui/Workspace/01_Repos/$d" && echo "✅ $d" || echo "❌ $d"
done
```

使用 AskUserQuestion 让用户选择本次 session 焦点：

```
本次 session 聚焦哪个域？
- _infra/guanghe（Swift 基础设施）
- _platform/super-founder（Swift 主产品）
- 多域并行（不设焦点）
- [仅当存在] _governance / huanlong
```

### Step 2: 加载项目级 CLAUDE.md

通过 Desktop Commander 读取焦点项目的 CLAUDE.md：

```bash
cat /Users/tongzhenghui/Workspace/01_Repos/{DOMAIN}/.claude/CLAUDE.md 2>/dev/null
```

提取关键信息注入当前 session 上下文：
- 架构约束（层级隔离、SPM 规则等）
- 当前 sprint/milestone 状态
- 高频错误提醒
- 活跃的 DP/Spec 编号

**不全量注入**（避免 context 膨胀），只提取：
1. 前 50 行（通常是核心规则）
2. 含 `## 当前` / `## Current` / `## Active` 的段落
3. 含 `⚠️` / `FIXME` / `TODO` 的行

### Step 3: Git 焦点摘要

通过 Desktop Commander 获取焦点项目的工作状态：

```bash
cd /Users/tongzhenghui/Workspace/01_Repos/{DOMAIN}

# 最近 5 commits
git log --oneline -5

# 活跃分支
git branch --list | head -10

# 当前分支
git branch --show-current

# 未提交变更
git status --short
```

### Step 4: 写入 Session 状态

通过 Desktop Commander 写入 `/tmp/cowork-session.json`：

```json
{
  "session_id": "{ISO_TIMESTAMP}",
  "focus_domain": "_platform/super-founder",
  "project_path": "/Users/tongzhenghui/Workspace/01_Repos/_platform/super-founder",
  "project_type": "swift",
  "current_branch": "main",
  "latest_commit": "abc1234 feat: ...",
  "dirty_files": 0,
  "ppr_roles": {
    "orchestrator": "cowork",
    "executor": "claude-code",
    "verifier": "codex-bridge",
    "auditor": "ggp"
  },
  "active_specs": ["DP-006", "DP-007"],
  "init_time": "{ISO_TIMESTAMP}"
}
```

其他 skill（GGP、codex-bridge）可读取此文件获取当前焦点项目路径，避免每次手动指定。

### Step 5: 输出 Session 摘要

```
## 🚀 Session Initialized — {YYYY-MM-DD HH:MM}

**焦点**: {域名} / {项目名}
**分支**: {branch} @ {commit_hash}
**工作区**: ✅ 干净 / ⚠️ {N} files changed
**活跃 Spec**: {DP-xxx, ...}

**已加载配置**:
- 项目 CLAUDE.md: ✅ {N} 条规则提取
- Session 状态: ✅ /tmp/cowork-session.json

准备就绪。输入任务开始工作。
```

---

## 域切换（Mid-Session）

用户说"切换到 guanghe"/"switch to infra"时：
1. 重新执行 Step 2-4，替换焦点域
2. 更新 `/tmp/cowork-session.json`
3. 输出新的 Session 摘要
4. 不重新运行 healthcheck（工具链状态不会变）

---

## 与其他 Skill 的集成

| Skill | 如何读取 session-init 状态 |
|-------|--------------------------|
| GGP | 从 `cowork-session.json` 读 `project_path`，无需手动指定审计目标 |
| codex-bridge | 从 `cowork-session.json` 读 `project_path`，自动定位项目 |
| healthcheck | session-init 消费 healthcheck 输出，不反向依赖 |

---

## 约束

- **焦点选择必须经用户确认**，不自动猜测。
- CLAUDE.md 提取采用摘要模式，**不全量注入**（防 context 膨胀）。
- `/tmp/cowork-session.json` 是 session 级临时文件，**不持久化**。
- 如果 Desktop Commander 不可用，跳过 Step 2/3/4，仅输出可用域列表供用户参考。
- 写入 session 状态前确认 `/tmp/` 可写（`test -w /tmp/`）。
