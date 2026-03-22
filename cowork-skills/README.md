# tzhOS Harness — Cowork Skills

> 基于 [obra/superpowers](https://github.com/obra/superpowers) 原版 Skills，叠加 tzhOS Harness 治理层。
> 保留原版经过验证的内容，追加 HARD-GATE / 反合理化 / 四状态报告 / 创始人升级链等 Harness 增量。

## 架构

```
superpowers 原版 SKILL.md（经过 TDD 验证的基础层）
        +
tzhOS Harness Governance Layer（末尾追加节）
        =
cowork-skills/（可执行发行版）
```

每个 SKILL.md 的结构：原版内容保持不变 → 末尾 `---` 分隔线 → `## tzhOS Harness Governance Layer` 追加 Harness 特有增量。

## 安装方式

### 方式 A：一键全量安装（推荐）

```bash
cd <tzh-Harness 仓库根目录>
bash cowork-skills/install.sh
```

脚本会将 `dist/*.skill` 中的所有 Skill 安装到 `~/.claude/skills/` 目录。

### 方式 B：单个安装

在 Cowork 对话中，点击 `.skill` 文件的「Copy to your skills」按钮即可安装。

`.skill` 文件位于 `dist/` 目录。

### 方式 C：项目级引用（Claude Code）

```bash
# 在 CLAUDE.md 中添加
@~/Workspace/01_Repos/_governance/tzh-Harness/cowork-skills/systematic-debugging/SKILL.md
```

## Skill 清单

| Skill | 来源 | Harness 增量 |
|-------|------|-------------|
| `systematic-debugging` | superpowers systematic-debugging + 5 个辅助文件 | 四状态报告 + 中文反合理化表 + Red Flags |
| `parallel-agent-dispatch` | superpowers dispatching-parallel-agents | 四要素指令 HARD-GATE + 四状态报告 + 集成测试 HARD-GATE |
| `git-worktree-isolation` | superpowers using-git-worktrees | tzhOS 多节点特化 + .gitignore HARD-GATE |
| `code-review-reception` | superpowers receiving-code-review | 来源分级表（创始人/外部/AI）+ 反谄媚 HARD-GATE |
| `skill-writing-tdd` | superpowers writing-skills + 6 个辅助文件 | Harness P7 结构规范 + 说服力写作原则 |

## 更新机制

### 跟踪上游

1. `git pull` superpowers 仓库获取原版更新
2. 将更新 merge 到 `cowork-skills/` 各目录（Harness 层在末尾，不会冲突）
3. 运行 `bash package-all.sh` 重新打包

### 跨节点分发

1. `git pull` 拉取最新 tzh-Harness
2. 运行 `bash cowork-skills/install.sh`

## 与 _sandbox 的关系

- `_sandbox/` = Harness 内部格式的治理文档原件（独立于 superpowers）
- `cowork-skills/` = superpowers 原版 + Harness 治理层叠加的**可执行发行版**

`_sandbox/` 仍然是 Harness 治理内容的 source of truth。`cowork-skills/` 的 Harness 层应从 `_sandbox/` 同步。

## 版本

- v0.2.0 (2026-03-22) — 重构：以 superpowers 原版为基础层，Harness 增量作为叠加层
- v0.1.0 (2026-03-22) — 首次发布（已废弃：从 _sandbox 重写而非基于原版）
