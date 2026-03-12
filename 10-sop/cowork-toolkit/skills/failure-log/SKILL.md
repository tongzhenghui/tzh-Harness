---
name: failure-log
description: >
  Structured failure archival for PPR workflow. Records GGP audit failures,
  build errors, and verify-loop Re-Plans into project repo as persistent,
  git-trackable assets. Use when GGP returns FAIL, build/test fails, or
  verify enters 3-strike Re-Plan. Triggers: 'failure log', 'record failure',
  '记录失败', '归档失败', 'archive failure', 'log error', '失败日志'.
  Also auto-suggested by GGP and codex-bridge on failure events.
disable-model-invocation: true
---

# Failure Log — 结构化失败归档

CLAUDE.md 第 27 条："犯错留痕，转化为资产。" 本 skill 将失败事件写入项目 `.claude/failure-log/`，Git 版本化追踪。

---

## 失败事件类型

| 类型 | 来源 | 触发条件 |
|------|------|----------|
| `ggp-fail` | GGP skill | 审计 verdict = FAIL（含 critical findings） |
| `build-fail` | codex-bridge / 手动 | `swift build` / `npm run build` 返回非零 |
| `verify-replan` | 工作流 | 连续 3 次 Verify 未通过，触发 Re-Plan |
| `regression` | 手动记录 | 修一个 bug 引入新问题 |
| `custom` | 手动记录 | 用户主动归档的其他失败 |

---

## 执行流程

### Step 1: 确定项目路径

优先从 `/tmp/cowork-session.json` 读取焦点项目（session-init 产出）：

```bash
cat /tmp/cowork-session.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['project_path'])"
```

如果 session 状态不存在，使用 AskUserQuestion 让用户选择目标项目。

### Step 2: 构造失败记录

根据事件类型收集信息：

**GGP FAIL**：
```bash
# 从 GGP 报告提取
cat /tmp/ggp-report.json
```

**Build FAIL**：
```bash
# 从 codex-bridge 日志提取
cat /tmp/codex-bridge-output.log
```

**Verify Re-Plan / Regression / Custom**：
通过对话上下文收集——失败描述、复现步骤、根因分析。

### Step 3: 生成失败记录文件

文件路径：`{PROJECT}/.claude/failure-log/{YYYY-MM-DD}_{TYPE}_{SHORT_ID}.json`

示例：`.claude/failure-log/2026-03-12_ggp-fail_a1b2.json`

```json
{
  "id": "2026-03-12_ggp-fail_a1b2",
  "type": "ggp-fail",
  "timestamp": "2026-03-12T14:30:00+08:00",
  "project": "super-founder",
  "domain": "_platform",
  "branch": "feat/dp-006",
  "commit": "abc1234",
  "summary": "GGP Round 2 发现未处理的并发竞态",
  "details": {
    "source": "ggp",
    "rounds_failed": [2],
    "critical_findings": [
      "async task 未使用 @MainActor 但访问 UI state"
    ],
    "full_report_ref": "/tmp/ggp-report.json"
  },
  "resolution": null,
  "resolved_at": null,
  "lessons_learned": null
}
```

### Step 4: 写入项目 repo

⚠️ **高风险操作**——写入宿主机项目文件。按 CLAUDE.md 第 14/15 条走确认：

```
⚠️ 需确认执行：
$ mkdir -p {PROJECT}/.claude/failure-log && cat > {PROJECT}/.claude/failure-log/{FILENAME}.json << 'FLOG_EOF'
{JSON_CONTENT}
FLOG_EOF
影响：在项目 .claude/failure-log/ 下新增一条失败记录文件
```

用户确认后通过 Desktop Commander 执行。

### Step 5: 输出确认

```
## 📋 Failure Logged

- **ID**: 2026-03-12_ggp-fail_a1b2
- **类型**: GGP 审计失败
- **位置**: {PROJECT}/.claude/failure-log/2026-03-12_ggp-fail_a1b2.json
- **摘要**: {一句话}

💡 修复后运行 `resolve` 命令关闭此记录。
```

---

## 辅助命令

### 查询历史失败

用户说"查看失败记录"/"failure history"/"失败日志"时：

```bash
ls -la {PROJECT}/.claude/failure-log/*.json 2>/dev/null | tail -20
```

按时间倒序展示，支持按类型过滤：

```bash
ls {PROJECT}/.claude/failure-log/*_{TYPE}_*.json 2>/dev/null
```

### 标记已解决

用户说"resolve {ID}"/"关闭 {ID}"时：

1. 读取对应 JSON 文件
2. 填入 `resolution`、`resolved_at`、`lessons_learned`
3. 写回文件（走高风险确认）

```json
{
  "resolution": "添加 @MainActor 标注，GGP 复审通过",
  "resolved_at": "2026-03-12T16:00:00+08:00",
  "lessons_learned": "所有访问 UI state 的 async 方法必须标注 @MainActor"
}
```

### 提炼 Checklist

当同类失败出现 2 次以上时，主动建议：

> "此类失败已出现 {N} 次。建议提炼为 Checklist 规则并更新项目 CLAUDE.md。是否执行？"

提炼逻辑：
1. 聚合同 `type` 的失败记录
2. 提取共性 `critical_findings`
3. 生成 Checklist 条目
4. 追加到项目 `.claude/CLAUDE.md` 的高频错误提醒区域（走高风险确认）

---

## 与其他 Skill 的集成

| Skill | 集成方式 |
|-------|----------|
| GGP | FAIL 时建议调用 failure-log 归档 |
| codex-bridge | build/test 失败时建议调用 failure-log |
| session-init | 初始化时可展示未 resolve 的失败记录数 |
| healthcheck | 诊断时可统计各域未关闭的失败记录 |

---

## 约束

- **每次写入宿主机都走高风险确认**，无例外。
- 失败记录文件为 JSON 格式，便于程序化读取。
- `SHORT_ID` 取 commit hash 前 4 位，如无 commit 则用随机 4 字符。
- `.claude/failure-log/` 目录应加入 `.gitignore` 还是 Git 追踪，由用户首次使用时裁决。
- `full_report_ref` 指向 `/tmp/` 临时文件，仅在同 session 内有效，归档后应将关键内容内联到 `details`。
- 不自动删除失败记录。已 resolve 的记录保留作为历史参考。
