---
name: ggp
description: >
  Guanghe Gate Protocol (GGP) — 三轮交叉审计引擎。通过 Gemini + GPT 竞争模型交叉检查
  Claude 盲区，基于 IEEE/ISO 25010 + Google Code Review Guide。PPR Auditor 角色。
  触发词：'审计', 'audit', 'GGP', '三审', '交叉审计', 'gate check', '跑审计',
  'run ggp', '代码审查', 'code review', '提交前检查', 'pre-commit check'。
  凡有代码编写的提交，必须先走 GGP 审计。
argument-hint: "[repo-path] [commit-range|auto]"
---

# GGP — Guanghe Gate Protocol

PPR 系统角色：**Auditor（交叉审计）**

使用外部竞争模型（Gemini + GPT）交叉检查 Claude Code 的盲区。三轮审计覆盖安全/质量/测试三个维度。

---

## 三轮分工

| Round | 模型 | 角色 | 触发条件 |
|-------|------|------|----------|
| 1 | Gemini 3.1 Pro | 结构正确性（架构/并发/类型安全/错误处理） | 始终 |
| 2 | GPT-5.4 | 工程质量（性能/命名/复杂度/可测试性） | 始终 |
| 3 | Gemini 3.1 Pro | 测试充分性（覆盖/边界值/失败路径） | Tests/ 有变更时 |

## 执行流程

### Step 1: 确定审计目标

从用户输入或上下文推断：

1. **目标仓库路径**（必须）：
   - guanghe: `/Users/tongzhenghui/Workspace/01_Repos/_infra/guanghe`
   - super-founder: `/Users/tongzhenghui/Workspace/01_Repos/_platform/super-founder`
   - 其他：用户指定
2. **审计范围**（默认 `auto` = `HEAD~1..HEAD`）：
   - commit range: `HEAD~3..HEAD`
   - 单 commit: `{sha}~1..{sha}`

### Step 2: 预检（通过 Desktop Commander）

```bash
# 验证项目路径
ls {REPO_PATH}/Package.swift 2>/dev/null || ls {REPO_PATH}/package.json 2>/dev/null

# 验证 API keys
source ~/.zshrc && echo "GOOGLE_AI_KEY=${GOOGLE_AI_KEY:+SET}" && echo "OPENAI_API_KEY=${OPENAI_API_KEY:+SET}"

# diff 预览
cd {REPO_PATH} && git diff --stat {RANGE} -- '*.swift' '*.ts' '*.py'
```

API keys 缺失则停止并报告。diff 为空则报告 SKIP。

### Step 3: 执行审计

将 `scripts/ggp-universal.sh` 的内容写入宿主机 `/tmp/ggp-universal.sh`（通过 Desktop Commander `write_file`），然后执行：

```bash
cd {REPO_PATH} && source ~/.zshrc && bash /tmp/ggp-universal.sh {RANGE} {REPO_PATH}
```

**超时**：`timeout_ms: 300000`（5 分钟）。脚本按顺序调用两次 Gemini API + 一次 OpenAI API。

### Step 4: 回收结果

读取 JSON 报告：
```bash
cat /tmp/ggp-report.json
```

### Step 5: 呈现判定

```
## GGP 审计结果：{PASS|FAIL}

| Round | 模型 | 维度 | 结果 |
|-------|------|------|------|
| 1 | Gemini 3.1 Pro | 安全与逻辑 | ✅/❌ |
| 2 | GPT-5.4 | 工程质量 | ✅/❌ |
| 3 | Gemini 3.1 Pro | 测试完整性 | ✅/⏭️ 跳过 |

{如有 Critical/High 问题，逐条列出}
```

---

## 前置条件

- 宿主机环境变量：`GOOGLE_AI_KEY` + `OPENAI_API_KEY`
- Desktop Commander 可用
- 目标仓库为 Git 仓库

## 与 codex-dispatch 的关系

GGP **直接**通过 Desktop Commander 在宿主机执行，不需要经过 codex-dispatch。
codex-dispatch 用于需要 Claude Code CLI 的场景（dual-build, slice-execute 等）。

## 语言支持

脚本自动检测项目语言并适配审计 prompt：
- Swift/SwiftUI（Sendable, @MainActor, SPM）
- TypeScript（类型安全, async/await, React hooks）
- Python（类型注解, 异常处理）
- Dart / Kotlin / Generic

## 约束

- **只审计，不自动修复**。发现问题后报告，由用户决定是否修复。
- 审计结果不自动阻断 commit/push，仅报告 PASS/FAIL。流程门控由用户执行。
- 每次审计消耗 Gemini/GPT API quota（约 2-3 个请求）。
