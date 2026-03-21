# Harness Engineering 执行标准

> 来源：hl-factory harness 制品 + tzh-agent-configs skill 治理规则 + 实践沉淀
> 治理归属：tzhOS CHARTER
> 版本：1.0.0

## 1. Skill 元数据标准

所有 SKILL.md 文件必须包含 YAML frontmatter，字段定义如下：

```yaml
---
name: <kebab-case 标识符>              # 必填
description: "<一句话描述触发条件>"      # 必填
version: <semver>                       # 必填，遵循语义化版本
layer: <1|2|3>                          # 可选，1=session 级, 2=通用工程级, 3=工厂制品级
role: <Judge|Orchestrator|Executor|Verifier|Auditor>  # 可选，PPR 五角色
argument-hint: "<参数格式提示>"          # 可选
allowed-tools: <工具白名单>             # 可选
---
```

**变更规则**：
- PATCH（0.0.x）：措辞修正、格式调整
- MINOR（0.x.0）：新增检查项、新增步骤
- MAJOR（x.0.0）：接口变更、删除步骤、语义变更

## 2. Harness 制品标准

harness.yaml 必须包含以下 6 个契约段：

| 段 | 字段 | 必填 | 说明 |
|----|------|------|------|
| 头部 | harness_id, harness_version, task_type, description | ✅ | 制品标识 |
| 输入契约 | required_inputs.fields[] | ✅ | 每个字段含 name/type/description/required |
| 上下文装配 | context_sources[] | ✅ | 每个源含 source_id/type/path_or_query/purpose |
| 工具权限 | tool_allowlist[] | ✅ | 最小权限原则 |
| 输出契约 | output_contract.files[] + metadata | ✅ | 产出文件模式 + 元数据字段 |
| 验证契约 | verification_contract.checks[] | ✅ | 每条含 check_id/type/description/severity |
| 评测契约 | eval_contract | 🔶 | min_regression_cases ≥ 3 |

## 3. 使用日志标准

每次 Skill / Harness 执行完毕后追加一行到：
`tzh-Harness/30-evals/toolkit-usage/logs/usage-log.jsonl`

```json
{"ts":"ISO-8601","skill":"<name>","project":"<项目>","domain":"<PPR域>","result":"PASS|FAIL|SKIP|ERROR","duration_s":N,"notes":"<简述>"}
```

**迭代触发条件**：

| 信号 | 行动 |
|------|------|
| 某 skill 失败率 > 30% | 优先修复该 skill |
| 某 skill 30 天未使用 | 评估是否废弃或合并 |
| 同类 notes 重复 ≥ 3 次 | 提炼为自动化规则 |
| duration_s 中位数持续上升 | 性能优化 |
| 新 skill 需求出现 ≥ 2 次 | 评估新建 skill |

## 4. SSOT 单一真源标准

每个概念只在一个位置维护 canonical 定义，其他位置通过引用消费：

| 概念 | Canonical 位置 | 消费方式 |
|------|---------------|---------|
| GGP 审计协议 | `tzh-agent-configs/skills/audit/ggp/SKILL.md` | 引用路径，不复制内容 |
| 模型名与版本 | GGP canonical 定义 | slice-execute 等引用 GGP |
| Harness 制品规格 | `hl-factory/specs/harness_spec.v0.1.yaml` | harness.yaml 头部声明 spec_version |
| PPR 五角色定义 | `tzhOS/PPR-AI-MODES.md` | skill frontmatter 中 role 字段引用 |
| 治理约束 | `tzhOS/CHARTER + SAAC-001` | 各仓库 CLAUDE.md 引用 |

## 5. 验收 Checklist 模板

新建 Skill 或 Harness 时使用此 checklist：

```markdown
## 验收 Checklist

- [ ] frontmatter 含 name / description / version
- [ ] 步骤有序编号，每步有明确的输入/输出
- [ ] 失败处理包含 3 次上限条款（P6）
- [ ] 引用外部概念使用路径而非内联复制（SSOT）
- [ ] 验证步骤产出二值结果（P4）
- [ ] 执行完毕写入 usage-log（§3）
- [ ] version 号与上一版本相比符合 semver 规则
```
