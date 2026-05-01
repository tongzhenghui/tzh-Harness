# Judgment Harness Observation Eval｜判断回路观察评测

> 版本：v0.1.1 | 日期：2026-05-01 | 状态：ACTIVE-DRAFT
> 上游治理：tzhOS `ai/JUDGMENT-HARNESS.md` v0.1.2 / AI-R0005
> 定位：Eval asset（评测资产），用于记录 Judgment Harness 实战案例的 24h / 72h / 7d 观察。

---

## 1. 目标

本评测用于把 Judgment Harness（判断回路）的真实任务观察沉淀为可续填、可审计的记录。

它只回答一个问题：

> 某次判断密集型任务是否按 `boundary -> grill -> baseline -> evidence -> human sign-off` 推进，并且是否有效防止目标、事实、判断责任和执行输入漂移。

本评测不定义 Judgment Harness 方法论，不替代 tzhOS 真源，不把跨对话草稿、AI 输出、过程文件或即时沟通记录升级为决定。

---

## 2. 评测输入

每条观察记录必须绑定以下输入：

| 字段 | 必填 | 说明 |
|---|---|---|
| `eval_id` | 是 | 唯一观察编号，例如 `jh-observation-20260501-01` |
| `case_id` | 是 | tzhOS Judgment Harness 案例编号，例如 `JH-002` |
| `ts` | 是 | ISO 8601 时间戳 |
| `operator` | 是 | 记录者，例如 `codex-desktop` |
| `tzhos_commit` | 是 | 对应 tzhOS 治理 commit |
| `method_version` | 是 | Judgment Harness 方法版本，例如 `v0.1.2` |
| `source_scope` | 是 | 来源范围，例如 `current-thread`、`cross-conversation` |
| `observation_status` | 是 | `pending` / `observing` / `observed` / `blocked` |
| `classification` | 是 | `facts` / `assumptions` / `judgments` / `preferences` 四类分离 |
| `checkpoints` | 是 | `h24` / `h72` / `d7` 三个观察节点 |
| `verdict` | 是 | `INSUFFICIENT_EVIDENCE` / `PASS` / `WARN` / `FAIL` |

历史记录中的 `method_version` 保留记录创建时使用的方法版本，不随当前上游版本指针回写。

---

## 3. 必检项

| 检查项 | 合格标准 |
|---|---|
| `boundary_present` | 已明确任务、真源、禁区、非目标、未决判断和预期输出 |
| `grill_trace_present` | 关键判断以一次一问方式推进，问题与选择进入决策树 |
| `baseline_signed` | baseline 有明确人工签字；未签字不得记为 baseline |
| `evidence_separated` | facts / assumptions / judgments / preferences 已分离 |
| `no_unsigned_source_promotion` | 未把未确认草稿、AI 输出、过程文件或即时沟通记录作为真源 |
| `dispatch_after_signoff` | 派发、落库、写 Skill 或工程执行发生在 human sign-off 之后 |
| `mode_boundary_stable` | 如涉及 Product-as-Runtime / Mode A-B-Hybrid，模式边界没有被下游重定义 |

---

## 4. 判定规则

| Verdict | 条件 |
|---|---|
| `PASS` | 三个观察节点均无阻断漂移，且下游可依据签字 baseline 启动或审查 |
| `WARN` | 方法链路大体成立，但存在非阻断风险，例如解释成本偏高、字段不完整、轻微边界漂移 |
| `FAIL` | 未签字内容被当成决定、AI 代替用户做关键判断、下游越过门禁执行，或 baseline 已实质漂移 |
| `INSUFFICIENT_EVIDENCE` | 观察尚未完成，或缺少关键输入，不能判断通过或失败 |

禁止把以下情况判为 `PASS`：

- 仅凭“感觉有用”或单次会话体验。
- 没有 24h / 72h / 7d 观察记录。
- 未签字 baseline 被下游直接使用。
- 事实、假设、判断和偏好混写，且无法追溯来源。
- Product-as-Runtime、AER、AUM、Air 或其他治理域被混作 Judgment Harness 成熟度证据。

---

## 5. 记录格式

运行记录写入：

```text
30-evals/judgment-harness-observation/logs/observation-log.jsonl
```

每行一条 JSON：

```json
{"eval_id":"jh-observation-YYYYMMDD-NN","case_id":"JH-002","ts":"YYYY-MM-DDTHH:mm:ss+08:00","operator":"codex-desktop","tzhos_commit":"<sha>","method_version":"v0.1.2","source_scope":"cross-conversation","observation_status":"pending","classification":{"facts":[],"assumptions":[],"judgments":[],"preferences":[]},"checkpoints":{"h24":{"status":"pending","pass_signals":[],"drift_signals":[],"founder_intervention":null},"h72":{"status":"pending","pass_signals":[],"drift_signals":[],"founder_intervention":null},"d7":{"status":"pending","pass_signals":[],"drift_signals":[],"founder_intervention":null}},"verdict":"INSUFFICIENT_EVIDENCE","notes":"brief summary"}
```

记录中不得包含 API key、access token、refresh token、cookie、完整 prompt secret、private callback URL、未公开客户资料或未经确认的跨对话业务细节。

---

## 6. 迭代触发条件

| 信号 | 行动 |
|---|---|
| 任一案例 `FAIL` | 回到 tzhOS `ai/JUDGMENT-HARNESS.md` 评估是否需要修订方法 |
| 连续 2 个案例 `WARN` | 检查字段是否过重、盘问是否过密、baseline 是否不够可执行 |
| 3 个案例均完成观察 | 准备是否进入 Skill / Pro Charter 的裁决材料 |
| 出现跨域混用 | 在记录中标明冲突，并回到 tzhOS 做治理归域 |
| 观察成本高于收益 | 降级为 lite 模式或暂停自动化沉淀 |

---

## 7. 与 tzhOS 的边界

- tzhOS 定义 Judgment Harness 方法论、状态、升级条件和案例登记。
- tzh-Harness 定义观察评测方法、记录格式和复用门槛。
- 具体业务对话、产品方案或智能体设计不得直接写入本 eval，除非已经在对应真源中签字。

本文件是 tzhOS Judgment Harness active-draft 的观察承接层，不是新的方法论真源。
