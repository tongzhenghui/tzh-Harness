# AI Playbook — 方法论沉淀

> 版本：v0.1
> 治理归属：Harness Engineering P3「从实践中提炼」
> 消费者：session-retrospective skill（`_sandbox/session-retrospective/`）

从每次实践中提取学习，让方法论有机生长。

---

## Case Notes（按时间倒序）

> 新 Case Note 从这里开始追加。编号格式：CN-NNN。

### CN-003 — Node-C Bot v3.3→v3.4 全流程：编码-审计-修复流水线首次实践

> 日期：2026-04-07 | 节点：NODE-M (Cowork) + NODE-A (CLI) + NODE-C (部署) | 场景：tech-cofounder-bot 两版升级

**背景：** Node-C 飞书 Bot 从 v3.3.0（群聊+可观测性）升级到 v3.4.0（富媒体+ACL+Webhook+历史），首次完整执行「Cowork 规划 → CLI 编码 → Cowork Codex 审计 → CLI 修复 → 部署」流水线。

**闭环路径：** Cowork 写 task spec → push GitHub → CLI pull + 编码 → push → Cowork 拉 diff 审计（4P0/7P1/7P2）→ 写修复 task → CLI 修复 → push → Node-C git pull + launchctl restart

**踩坑记录：**

| 序号 | 问题 | 解决 | 可复用 |
|------|------|------|--------|
| 1 | GitHub push_files 对 37KB 文件溢出 | 大文件用 create_or_update_file（需 SHA） | 是 |
| 2 | Node-C 无 .git，git pull 失败 | git clone 替换旧目录，保留 .env | 是（已一次性解决） |
| 3 | Private repo HTTPS clone 403 | 改用 SSH git@ 方式 | 是（Node-C SSH key） |
| 4 | Cowork 沙箱无 gh CLI | 通过 osascript 在 NODE-M 执行 | 是（沙箱限制通用） |
| 5 | isAdmin() 空配置=全员通过 | Codex 审计发现，改为 default-deny | 是（权限设计原则） |

**关键观察：**

1. **Codex 审计价值验证**：CLI 编码 +511 行，审计发现 4 个 P0 安全问题（env 泄露、DoS、权限绕过、竞态），人工 review 很难全部覆盖
2. **Task 文件体系有效**：`.claude/tasks/NNN-spec.md` + `NNN-result.md` 实现了 Cowork↔CLI 异步闭环，无需粘贴代码
3. **Git 化远程节点 ROI 高**：Node-C 从 SCP 改为 git clone 后，部署从 ~5min 降至 30s（git pull + launchctl）
4. **大文件 GitHub 推送策略**：小文件 push_files 批量，大文件（>20KB）单独 create_or_update_file

**Pattern 候选：**
- 「编码-审计-修复」三阶段流水线（待第二个案例确认）
- 「Git 化远程节点」一次性成本换长期效率（待第二个节点确认）

**已抽象：** 否（两个候选均为首次实践）

---

### CN-002 — Cowork Skills 安装机制：从猜测到发现正确路径

> 日期：2026-03-30 | 节点：NODE-A (Cowork) | 场景：将 Harness Skills 安装到 Cowork 桌面端

**背景：** 需要将 tzh-Harness 仓库中的 9 个 Skills 安装到 Cowork 桌面端。Cowork 内置 6 个 Skills（docx/pdf/pptx/xlsx/schedule/skill-creator），Harness 有 6 个正式版（dist/）+ 3 个实验版（_sandbox/）。

**踩坑过程：**

| 尝试 | 方法 | 结果 | 原因 |
|------|------|------|------|
| #1 | `cp -r` 到 `mnt/.claude/skills/` | ❌ Read-only file system | Cowork Skills 目录是只读挂载 |
| #2 | `osascript` 执行 `install.sh` 安装到 `~/.claude/skills/` | ⚠️ 只对 Claude Code 生效 | Cowork 与 Claude Code 的 Skills 加载机制完全独立 |
| #3 | 读 `present_files` 工具描述，发现 `.skill` 文件渲染「Save skill」按钮 | ✅ 正确路径 | Cowork 原生支持的安装方式 |

**附带发现：**

1. `planning-with-files.skill` 打包缺顶层目录前缀，解压后文件散落到 `~/.claude/skills/` 根目录 → 手动归位后修复
2. Cowork 禁止 Skill 名称含 `claude` 保留词 → `claude-md-audit` 改名为 `workspace-doc-audit`
3. 双通道 Skills 架构确认：Claude Code 用 `~/.claude/skills/`，Cowork 用 `present_files` + `.skill` ZIP 包

**关键教训：** 花了多轮猜测安装路径，最终答案就在 `present_files` 工具描述的一句话里。与 CN-001 相同模式——先读平台能力说明，再行动。

**已抽象：** PAT-001

---

### CN-001 — Global Instructions 写入管控：从失败到生效的三次迭代

> 日期：2026-03-26 | 节点：NODE-M (Cowork) | 场景：Write-Owner 硬约束在新会话中未生效

**背景：** NODE-M 的 Cowork Global Instructions 中配置了 Write-Owner 声明，禁止对 hl-* 仓库执行写操作。测试指令“修改 hl-platform/CLAUDE.md”预期被拒绝，实际 AI 直接读取文件并进入编辑工作流。

**迭代过程：**

| 版本 | 策略 | 结果 | 失败原因 |
|------|------|------|----------|
| v1.0 | 描述性声明 + `<HARD-GATE>` XML 标签 + ~1200 字 | ❌ 失败 | 自定义 XML 无语义、规则位置靠后被淉没、篇幅过长稀释信号 |
| v1.1 | 规则前置（第一行 IMPORTANT）+ 祈使句 + 显式触发词枚举 + Good/Bad 正反示例 + ~550 字 | ✅ 生效 | — |
| v1.2 | 主规则改为意图/结果导向 + 关键词降级为“包括但不限于”示例 + 判断标准二值化 + 3 个正确示例 + ~630 字 | ✅ 生效（增强鲁棒性） | — |

**关键发现：**

1. **位置 > 篇幅 > 装饰**：规则在文件中的位置（primacy effect）比任何 XML 标签或格式装饰都有效
2. **正反示例是最强锚定**：Good/Bad 示例直接告诉模型“收到 X 时做 Y，不做 Z”，比抽象规则的遵循率显著更高
3. **意图导向 > 关键词枚举**：关键词枚举是脆弱的（漏网词无法拦截），结果导向判断（“操作后文件是否变更”）更鲁棒
4. **自定义 XML 标签对 LLM 无硬阻断能力**：`<HARD-GATE>` 等标签只是纯文本，模型不会赋予其特殊语义
5. **精简 = 有效**：从 1200 字砍到 550 字后生效，信噪比比绝对篇幅更重要
6. **产出文件必须遵守 DIRECTORY-SPEC**：Cowork 模式下 AI 默认将产出文件写入 Workspace 根目录，违反目录规范。应在创建文件前先判断归属（本例中 `global-instructions-NODE-M.md` 属 Agent 配置，应归入 `tzh-agent-configs/prompts/system/`）。这是第三次纠正同类问题，需建立前置检查习惯

**候选 Pattern：** LLM 指令遵循有效性 ≈ 位置(primacy) × 显式度(Good/Bad 示例) × 信噪比(精简)。待第二个独立案例确认后提炼。

**已抽象：** PAT-001（“读平台文档再行动”维度）

---

## Patterns（需 ≥2 个独立案例）

> 编号格式：PAT-NNN。每个 Pattern 必须引用 ≥2 个 CN-NNN 来源。
> 未满 2 个案例的标「候选」。

### PAT-001 · 平台能力发现优先于猜测

**场景：** 需要实现某个操作（安装、约束、集成），但不确定平台是否原生支持或支持方式是什么。

**做法：**
1. 先读工具描述、API 文档、平台文档，确认平台原生能力边界
2. 再设计方案，优先使用平台原生路径
3. 避免基于经验猜测绕道——每次绕道都引入脆弱性

**注意事项：** “文档在哪里”本身需要一次搜索。Cowork 场景下，工具描述就是文档（如 `present_files` 的描述直接说明了 `.skill` 安装机制）。

**来源：** CN-001（Global Instructions 的 `<HARD-GATE>` XML 标签无效，读 prompting 文档后用 Good/Bad 示例解决）、CN-002（猜测 Skills 安装路径多次失败，读 `present_files` 工具描述后一次解决）

---

## 编号规则

- **CN-NNN**：Case Note，单次实践记录。从 CN-001 开始递增。
- **PAT-NNN**：Pattern，从 ≥2 个 Case Notes 中提炼的可复用模式。从 PAT-001 开始递增。
- 已抽象为 Pattern 的 Case Note 标注 `已抽象: PAT-NNN`。
