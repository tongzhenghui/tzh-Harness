# AI Playbook — 方法论沉淀

> 版本：v0.1
> 治理归属：Harness Engineering P3「从实践中提炼」
> 消费者：session-retrospective skill（`_sandbox/session-retrospective/`）

从每次实践中提取学习，让方法论有机生长。

---

## Case Notes（按时间倒序）

> 新 Case Note 从这里开始追加。编号格式：CN-NNN。

### CN-001 — Global Instructions 写入管控：从失败到生效的三次迭代

> 日期：2026-03-26 | 节点：NODE-M (Cowork) | 场景：Write-Owner 硬约束在新会话中未生效

**背景：** NODE-M 的 Cowork Global Instructions 中配置了 Write-Owner 声明，禁止对 hl-* 仓库执行写操作。测试指令"修改 hl-platform/CLAUDE.md"预期被拒绝，实际 AI 直接读取文件并进入编辑工作流。

**迭代过程：**

| 版本 | 策略 | 结果 | 失败原因 |
|------|------|------|----------|
| v1.0 | 描述性声明 + `<HARD-GATE>` XML 标签 + ~1200 字 | ❌ 失败 | 自定义 XML 无语义、规则位置靠后被淹没、篇幅过长稀释信号 |
| v1.1 | 规则前置（第一行 IMPORTANT）+ 祈使句 + 显式触发词枚举 + Good/Bad 正反示例 + ~550 字 | ✅ 生效 | — |
| v1.2 | 主规则改为意图/结果导向 + 关键词降级为"包括但不限于"示例 + 判断标准二值化 + 3 个正确示例 + ~630 字 | ✅ 生效（增强鲁棒性） | — |

**关键发现：**

1. **位置 > 篇幅 > 装饰**：规则在文件中的位置（primacy effect）比任何 XML 标签或格式装饰都有效
2. **正反示例是最强锚定**：Good/Bad 示例直接告诉模型"收到 X 时做 Y，不做 Z"，比抽象规则的遵循率显著更高
3. **意图导向 > 关键词枚举**：关键词枚举是脆弱的（漏网词无法拦截），结果导向判断（"操作后文件是否变更"）更鲁棒
4. **自定义 XML 标签对 LLM 无硬阻断能力**：`<HARD-GATE>` 等标签只是纯文本，模型不会赋予其特殊语义
5. **精简 = 有效**：从 1200 字砍到 550 字后生效，信噪比比绝对篇幅更重要
6. **产出文件必须遵守 DIRECTORY-SPEC**：Cowork 模式下 AI 默认将产出文件写入 Workspace 根目录，违反目录规范。应在创建文件前先判断归属（本例中 `global-instructions-NODE-M.md` 属 Agent 配置，应归入 `tzh-agent-configs/prompts/system/`）。这是第三次纠正同类问题，需建立前置检查习惯

**候选 Pattern：** LLM 指令遵循有效性 ≈ 位置(primacy) × 显式度(Good/Bad 示例) × 信噪比(精简)。待第二个独立案例确认后提炼为 PAT-001。

---

## Patterns（需 ≥2 个独立案例）

> 编号格式：PAT-NNN。每个 Pattern 必须引用 ≥2 个 CN-NNN 来源。
> 未满 2 个案例的标「候选」。

_（暂无条目）_

---

## 编号规则

- **CN-NNN**：Case Note，单次实践记录。从 CN-001 开始递增。
- **PAT-NNN**：Pattern，从 ≥2 个 Case Notes 中提炼的可复用模式。从 PAT-001 开始递增。
- 已抽象为 Pattern 的 Case Note 标注 `已抽象: PAT-NNN`。
