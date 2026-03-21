# Harness Engineering 核心原则

> 来源：SUPERFACTORY.md + SAAC-001 公理体系 + 实践沉淀
> 治理归属：tzhOS CHARTER
> 版本：1.0.0

## P1 — Plan-Then-Execute（先规划后执行）

AI Agent 不得在无 Spec 状态下开始编码。执行前必须存在明确的任务规格（Slice Spec / TaskSpec / harness.yaml），其中包含输入契约、输出契约和验收标准。

**判定标准**：如果 Agent 无法回答"我要做什么、做完的标志是什么"，则不具备执行条件。

## P2 — Spec-Driven（规格驱动）

所有生成行为的上下文来自 SSOT 契约链（decisions → rules → APIs → events → reason_codes），不来自 Agent 的参数知识。上下文装配路径必须在 harness.yaml 的 `context_sources` 中声明。

**判定标准**：生成代码中的每个业务概念（reason_code、API path、事件名）必须可追溯到 hl-contracts 中的具体文件。

## P3 — 从实践中提炼

方法论和 Pattern 只从至少 2 个独立实践案例中提炼，不从理论推演。未满 2 个案例的标"候选"。

**判定标准**：PLAYBOOK 中的 PAT-NNN 条目必须引用 ≥2 个 CN-NNN 来源。

## P4 — Deterministic Gates（确定性门禁）

验证必须产出二值结果（PASS / FAIL），不接受"应该能通过"。门禁脚本 exit code 为唯一判定依据，人类判断仅在交叉 Critical 分歧时介入裁决。

**判定标准**：每个 harness 的 `verification_contract.checks` 中的每条 check 必须有 `severity` 和可自动化的 `type`。

## P5 — 最小结构，有机生长

不预设完美分类体系。目录、标签、Pattern 按需增长，当同类项 ≥3 时才考虑结构化重组。

**判定标准**：新建目录 / 新增分类必须引用触发条件（如 Harness 迭代触发条件表）。

## P6 — 3 次上限，然后 Re-Plan

AI Agent 在同一步骤连续失败 3 次必须停止执行，输出诊断信息并请求人类裁决或 Re-Plan。不允许无限重试。

**判定标准**：slice-execute / gen_service 等 harness 的失败处理章节必须包含 3 次上限条款。

## P7 — 封装为制品

能力不以散件形式交付。Skill 有 SKILL.md + version，Harness 有 harness.yaml + verification + evals。封装使能力可实例化、可版本化、可复用。

**判定标准**：任何新建的 Skill / Harness 必须包含 frontmatter（name, description, version）。
