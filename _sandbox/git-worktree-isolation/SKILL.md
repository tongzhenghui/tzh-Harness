# Skill｜Git Worktree 隔离实践（Git Worktree Isolation）

- Name: git-worktree-isolation
- Type: skill（工程方法论）
- Status: DRAFT
- Version: 0.1.0
- Owner: TZH
- Date: 2026-03-22
- Related:
  - tzh-Harness/00-principles/README.md（P3 可组合, P5 可验证）
  - tzhOS/40-PPR/MULTI-NODE-COWORK-SPEC.md（多节点隔离）
  - 来源：obra/superpowers `skills/using-git-worktrees/SKILL.md` 改造

---

## 1. Purpose（目的）

在需要隔离工作空间时（feature 开发、实验性重构、并行 Agent 派发），使用 Git Worktree 创建独立工作区，避免污染主分支或干扰其他工作流。

**Non-goals**：
- 不替代 Git Branch 的日常分支管理
- 不适用于治理文档修订（直接在 main 上工作）

## 2. Trigger（触发条件）

**使用本 Skill**：
- 需要同时在多个分支上工作
- 并行 Agent 派发时，每个 Agent 需要独立工作区（参见 parallel-agent-dispatch Skill）
- 实验性改动需要隔离（怕污染主工作区）
- harness-7step Step 0 Brainstorming 设计完成后，进入实现阶段

**不使用**：
- 简单的单文件修改
- 治理文档修订（在 main 上直接操作）
- 没有代码仓库的纯文档项目

## 3. Workflow

### Step 1｜确定 Worktree 目录

按优先级检查：

1. **已有 `.worktrees/` 或 `worktrees/`** → 直接使用（`.worktrees/` 优先）
2. **CLAUDE.md 中有偏好声明** → 按声明使用
3. **都没有** → 创建 `.worktrees/`（项目本地，隐藏）

### Step 2｜安全验证

<HARD-GATE>
在项目本地目录创建 Worktree 前，必须确认该目录已被 .gitignore 忽略。
未忽略 = 禁止创建。先修复 .gitignore，commit 后再继续。
</HARD-GATE>

```bash
# 验证目录是否被忽略
git check-ignore -q .worktrees 2>/dev/null
# 如果返回非零 → 添加到 .gitignore 并 commit
```

### Step 3｜创建 Worktree

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
git worktree add .worktrees/<branch-name> -b <branch-name>
cd .worktrees/<branch-name>
```

### Step 4｜项目初始化

自动检测并运行：

| 检测文件 | 运行命令 |
|---------|---------|
| `package.json` | `npm install` |
| `Package.swift` | `swift build` |
| `Cargo.toml` | `cargo build` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `go.mod` | `go mod download` |

### Step 5｜基线验证

```bash
# 运行项目对应的测试套件
# 确保 Worktree 初始状态是通过的
```

- 测试通过 → 报告就绪，开始工作
- 测试失败 → 报告失败，**不要继续**，升级给创始人

### Step 6｜工作完成后清理

```bash
cd <主工作区>
git worktree remove .worktrees/<branch-name>
# 或保留 worktree 供后续使用
```

## 4. tzhOS 多节点特化

在 tzhOS 多节点场景下的特殊约束：

- **治理仓库不使用 Worktree**：tzhOS / tzh-Harness 直接在 main 上工作，通过 Git push/pull 同步
- **代码仓库使用 Worktree**：tzhOS-App / super-founder / guanghe 等可使用 Worktree 隔离 feature 开发
- **Cowork sandbox 限制**：Worktree 创建需在宿主机执行（sandbox 内 Git 操作受限），Agent 在 Worktree 内工作

## 5. Anti-Rationalization（反合理化）

| 借口 | 现实 |
|------|------|
| 「太简单不需要隔离」 | 简单改动隔离成本几乎为零 |
| 「我直接在 main 上改更快」 | 污染 main 后清理的时间远超创建 Worktree |
| 「先不管 .gitignore」 | 忘记 → Worktree 内容被 commit → 仓库污染 |
| 「测试先不跑了」 | 没有基线 → 无法区分新 Bug 和旧 Bug |

## 6. Verification（验证）

**DoD 条目**：
- [ ] Worktree 目录已被 .gitignore 忽略
- [ ] 基线测试通过
- [ ] 工作完成后 Worktree 已清理或有保留理由

## 7. Change Policy

- Patch：示例增补、命令修正
- Minor：新增项目类型检测、新增多节点规则
- Major：改变安全验证流程（需 ADR）
