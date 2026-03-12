---
name: cowork-healthcheck
description: >
  Session startup healthcheck for Cowork environment. Audits installed plugins,
  active skills, context budget usage, project state, and CLAUDE.md configuration.
  Use this skill at the start of every new Cowork session, or when the user says
  'healthcheck', 'session check', '环境检查', '检查插件', '启动检查', or '诊断'.
  Also use when the user asks about plugin status, skill conflicts, or context budget.
disable-model-invocation: true
---

# Cowork Session Healthcheck — PPR v2.1 Aligned

每次新 Cowork session 启动时执行环境诊断，覆盖 PPR 四域项目状态、工具链就绪度、context budget，输出可操作的建议清单。

---

## 执行流程

### Phase 1: PPR 四域 Repo 状态扫描

通过 Desktop Commander 扫描 PPR v2.1 四域结构：

```bash
PPR_DOMAINS=(
  "_governance|/Users/tongzhenghui/Workspace/01_Repos/_governance"
  "_infra|/Users/tongzhenghui/Workspace/01_Repos/_infra/guanghe"
  "_platform|/Users/tongzhenghui/Workspace/01_Repos/_platform/super-founder"
  "huanlong|/Users/tongzhenghui/Workspace/01_Repos/huanlong"
)
```

对每个域执行（跳过不存在的路径）：

1. `test -d {PATH}` — 目录是否存在
2. `git -C {PATH} log --oneline -1` — 最新 commit
3. `git -C {PATH} status --short | head -5` — 工作区干净度
4. 检测项目类型：`Package.swift` → Swift/iOS，`package.json` → Node/Web，`Cargo.toml` → Rust，`pyproject.toml` → Python

输出格式：
```
| 域 | 项目 | 最新 Commit | 状态 |
|----|------|-------------|------|
| _platform | super-founder | abc1234 feat: ... | ✅ 干净 |
| _infra | guanghe | def5678 fix: ... | ⚠️ 3 files changed |
```

### Phase 2: 工具链就绪度检查

通过 Desktop Commander 验证关键工具：

1. **Claude Code CLI**: `which claude && claude --version 2>/dev/null || echo "NOT_FOUND"`
2. **API Keys**（只检查存在性，不暴露值）:
   - `test -n "$GOOGLE_AI_KEY" && echo "✅ SET" || echo "❌ MISSING"` — GGP Round 1/3
   - `test -n "$OPENAI_API_KEY" && echo "✅ SET" || echo "❌ MISSING"` — GGP Round 2
3. **Desktop Commander**: 尝试 `mcp__Desktop_Commander__list_sessions` — 能响应即 ✅

缺失项标记为 🔴 并在建议操作中列出修复步骤。

### Phase 3: Plugin & Skill 审计

1. 从系统提示的 available_skills 中提取全部已加载 skills
2. 按来源分类统计：
   - `anthropic-skills:*` — Anthropic 核心 skills
   - Plugin skills — 按 plugin 名分组
   - 用户自定义 skills — `tzhos-toolkit:*` 等
3. 估算 context budget 压力：
   - 统计全部 skill description 的大致字符总量
   - 🟢 健康：< 8,000 chars
   - 🟡 中压：8,000–12,000 chars
   - 🔴 高压：> 12,000 chars（接近 16K fallback 上限）
4. 根据当前项目类型对每个 plugin 打相关性分（动态适配，非硬编码）

### Phase 4: PPR 角色映射检查

验证 PPR 5 System Roles 的工具覆盖：

| PPR 角色 | 工具/Skill | 检查项 |
|----------|-----------|--------|
| Judge (创始人) | — | 人类角色，无需检查 |
| Orchestrator | Cowork session | ✅ 当前环境即是 |
| Executor | Claude Code CLI | Phase 2 已检查 |
| Verifier | dual-build / p0-gate | codex-bridge skill 是否存在 |
| Auditor | GGP | ggp skill 是否存在 + API keys |

缺失角色覆盖标记为 ⚠️。

### Phase 5: CLAUDE.md 健康检查

通过 Desktop Commander 读取全局 CLAUDE.md：

```bash
cat ~/.claude/CLAUDE.md 2>/dev/null | wc -l
```

检查项：
- 文件是否存在
- 总行数（> 200 行标记 ⚠️ 膨胀风险）
- 是否包含过期的 iCloud 路径 `com~apple~CloudDocs`
- 是否有高频错误提醒区域
- 是否有残留的过期 session 信息

### Phase 6: 构建状态快照（可选，按需）

仅当用户选择执行或主动请求时触发。通过 Desktop Commander 在活跃项目上执行：

1. Swift 项目：`swift build 2>&1 | tail -5`
2. `git diff --stat HEAD`
3. `ls docs/*.md 2>/dev/null`

此阶段耗时较长（编译可能 30s+），默认跳过，在建议操作中列为可选项。

---

## 输出格式

```
## 🏥 Cowork Session Healthcheck — {YYYY-MM-DD}

### 📍 PPR 四域状态
| 域 | 项目 | Commit | 工作区 |
|----|------|--------|--------|
| _governance | — | — | ❌ 未发现 |
| _infra | guanghe | {hash} {msg} | ✅/⚠️ |
| _platform | super-founder | {hash} {msg} | ✅/⚠️ |
| huanlong | — | — | ❌ 未发现 |

### 🔧 工具链
- Claude Code: ✅ v{x.y.z} / ❌ 未安装
- GOOGLE_AI_KEY: ✅ / ❌（影响 GGP Round 1/3）
- OPENAI_API_KEY: ✅ / ❌（影响 GGP Round 2）
- Desktop Commander: ✅ / ❌

### 📊 Context Budget
- Anthropic Skills: {N} 个
- Plugin Skills: {N} 个（{plugin 名 × 数量}）
- 总计: {N} 个 — 🟢/🟡/🔴
- 预估字符占用: ~{N} chars / 16,000 上限

### 🎭 PPR 角色覆盖
| 角色 | 状态 | 工具 |
|------|------|------|
| Judge | ✅ | 人类 |
| Orchestrator | ✅ | Cowork |
| Executor | ✅/❌ | Claude Code CLI |
| Verifier | ✅/❌ | codex-bridge |
| Auditor | ✅/❌ | GGP + API keys |

### 📝 CLAUDE.md
- 全局: {行数} 行 — ✅/⚠️
- 路径配置: ✅ 最新 / ❌ 含过期路径
- 高频提醒: ✅ 存在 / ❌ 缺失

### 🎯 建议操作（按优先级）
1. [P0] {紧急} ...
2. [P1] {重要} ...
3. [P2] {优化} ...
N. [可选] 运行构建状态快照（Phase 6）

输入编号执行对应操作，或输入 "跳过" / "开始" 直接进入工作。
```

---

## 用户交互规则

- 输出诊断报告后，使用 AskUserQuestion 让用户选择操作
- 用户选择编号 → 执行对应操作
- 用户说"跳过"/"开始"/"没问题" → 结束 healthcheck，进入正常工作流
- 🔴 级别问题：强烈建议处理后再开始工作，但不强制

## 约束

- **只诊断，不自动执行变更**。所有操作必须经用户确认。
- 使用 Desktop Commander 执行宿主机命令（git/build），不在沙箱中执行。
- Phase 1-5 应在 60 秒内完成（Phase 6 除外）。
- 如果 Desktop Commander 不可用，跳过 Phase 1/2/5/6 的宿主机命令，仅执行 Phase 3-4。
- API key 检查只验证存在性（`test -n`），**绝不读取或输出 key 值**。
