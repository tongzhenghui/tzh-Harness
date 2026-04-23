# Evals｜评测资产入口

> 版本：v0.1 | 日期：2026-04-23 | 状态：ACTIVE
> 定位：Evaluation assets index（评测资产索引）

---

## 1. 文档定位

`30-evals` 保存可复用评测方法、验收记录格式和运行日志。

本目录不定义治理身份，不实现 runtime。治理身份由 tzhOS 定义，runtime 实现由对应工程仓库承担。

---

## 2. 当前评测资产

| 资产 | 用途 | 记录 |
|---|---|---|
| `agent-runtime-readiness/README.md` | 大辉子 / 暴走辉运行就绪评测 | `agent-runtime-readiness/logs/readiness-log.jsonl` |
| `toolkit-usage/README.md` | Cowork Toolkit 使用统计 | `toolkit-usage/logs/usage-log.jsonl` |

---

## 3. 记录规则

- 新评测资产必须有 `README.md`，说明目标、输入、必检项、判定规则和记录格式。
- 运行记录优先使用 JSONL，每行一条完整 JSON。
- 记录不得包含 API key、access token、refresh token、cookie、完整 prompt secret 或 private callback URL。
- 评测资产只保存方法和结果，不把当前模型快照写死为长期事实。

---

## 4. 与 tzhOS 的关系

- tzhOS 定义身份、职责、上位规则和升级条件。
- tzh-Harness 定义评测方法、复用记录格式和迭代触发条件。
- 当 tzhOS runbook 或 agent profile 改变运行验收标准时，应检查本目录是否需要同步。
