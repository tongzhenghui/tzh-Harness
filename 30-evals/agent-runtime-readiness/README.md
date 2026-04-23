# Agent Runtime Readiness Eval｜领域智能体运行就绪评测

> 版本：v0.2 | 日期：2026-04-23 | 状态：ACTIVE
> 上游治理：tzhOS `40-AGENT-MANAGER/AGENT-RUNTIME-OPS-RUNBOOK.md`
> 定位：Eval asset（评测资产），用于把领域智能体运行态从“人工确认”沉淀为可复用验收记录。

---

## 1. 目标

本评测用于判断逻辑智能体资产是否处于可用、可巡检、可升级的运行状态。

当前覆盖对象：

- 大辉子（`dahuizi`）：终生技术合伙人智能体，当前承载于 NODE-C。
- 暴走辉（`baozouhui`）：终生事业合伙人智能体，当前承载于 NODE-D。

本评测不定义节点身份、不改变职责边界、不替代 tzhOS 治理真源。它只保存验收方法和运行记录。

---

## 2. 评测输入

每次评测必须绑定以下输入：

| 字段 | 必填 | 说明 |
|---|---|---|
| `eval_id` | 是 | 唯一评测编号，例如 `agent-runtime-readiness-20260423-01` |
| `ts` | 是 | ISO 8601 时间戳 |
| `operator` | 是 | 执行者，例如 `codex-desktop` |
| `governance_commit` | 是 | tzhOS 当前治理 commit |
| `runtime_refs` | 是 | 各智能体 runtime commit、service version 或 runtime alias |
| `checks` | 是 | 实际执行的检查项与摘要 |
| `verdict` | 是 | `PASS` / `WARN` / `FAIL` |

---

## 3. 必检项

### 3.1 大辉子

| 检查项 | 合格标准 |
|---|---|
| `dahuizi_health` | `/health` 返回 `status=ok`、`agent.id=dahuizi`、`queueSize=0` 或有明确任务解释 |
| `dahuizi_master_brain_auth` | Claude first-party Max 登录态有效，且 `opus` alias 最小调用返回约定字符串；状态可见但调用失败仍判 `FAIL` |
| `dahuizi_codex_runner_auth` | Codex Runner 订阅登录态有效；需要人工授权时必须标记 `WARN` 或 `FAIL` |
| `dahuizi_runtime_tests` | `tech-cofounder-bot` 当前测试套件 fail 为 0 |
| `dahuizi_commit` | runtime clone commit 与已推送真源一致，无未解释源码漂移 |

### 3.2 暴走辉

| 检查项 | 合格标准 |
|---|---|
| `baozouhui_health` | OpenClaw health 返回 `ok=true`，Feishu probe 正常，agents 包含 `biz-governor` |
| `baozouhui_light_smoke` | Gateway `model.run` light smoke 返回约定字符串 |
| `baozouhui_governance_sync` | NODE-D 只读 tzhOS clone fast-forward 到 GitHub main 当前治理 commit |
| `baozouhui_business_smoke` | 仅在业务上下文、agent 配置或重大商业判断前执行；高频巡检不强制 |

---

## 4. 判定规则

| Verdict | 条件 |
|---|---|
| `PASS` | 必检项全部通过；可选重型验收无阻断失败 |
| `WARN` | 运行可用但存在非阻断风险，例如重型 smoke 未跑、非关键注解、历史未跟踪文件噪声 |
| `FAIL` | 任一必检项失败，或运行态与治理真源冲突，或需要创始人手动授权而未完成 |

禁止把以下情况判为 `PASS`：

- 没有 fresh verification evidence（新鲜验证证据）。
- 只检查 health，没有检查模型通道或登录态。
- 只检查 Codex Runner 登录态，没有验证大辉子 Claude 主脑 first-party Max 授权和 `opus` alias 最小调用。
- 节点本地治理 clone 落后主线且未解释。
- 把业务上下文重型 smoke 当作日常心跳反复运行。
- 在治理文档中硬写当前模型快照作为长期事实。

---

## 5. 记录格式

运行记录写入：

```text
30-evals/agent-runtime-readiness/logs/readiness-log.jsonl
```

每行一条 JSON：

```json
{"eval_id":"agent-runtime-readiness-YYYYMMDD-NN","ts":"YYYY-MM-DDTHH:mm:ss+08:00","operator":"codex-desktop","governance_commit":"<sha>","verdict":"PASS","agents":{"dahuizi":{"health":"PASS","master_brain_auth":"PASS","codex_runner_auth":"PASS","runtime_tests":"PASS"},"baozouhui":{"health":"PASS","light_smoke":"PASS","governance_sync":"PASS"}},"notes":"brief summary"}
```

记录中不得包含 API key、access token、refresh token、cookie、完整 prompt secret 或 private callback URL。

---

## 6. 迭代触发条件

| 信号 | 行动 |
|---|---|
| 同一智能体连续 2 次 `WARN` | 更新 tzhOS runbook 或 runtime 配置 |
| 任一 `FAIL` | 升级给创始人，并在修复后追加新记录 |
| 新增领域智能体 | 扩展本 eval 的覆盖对象和必检项 |
| smoke 成本明显过高 | 拆分 light smoke 与 heavy acceptance |
| runtime alias 变更 | 只更新 runtime registry / 记录，不把模型快照写死进本 eval |

---

## 7. 与 tzhOS 的边界

- tzhOS 定义身份、职责、治理规则、升级条件。
- tzh-Harness 定义评测方法、记录格式、复用模式。
- runtime 仓库负责实现服务、工具调用、测试和部署。

本文件是 tzhOS runbook 的验收资产化承接层，不是新的治理真源。
