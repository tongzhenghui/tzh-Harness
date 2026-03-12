# Toolkit Usage Tracking

Cowork Toolkit 使用情况追踪，支持持续迭代优化。

## 日志格式

`logs/usage-log.jsonl` — 每行一条 JSON 记录：

```json
{"ts":"2026-03-12T20:00:00+08:00","skill":"ggp","project":"guanghe","domain":"_infra","result":"PASS","duration_s":45,"notes":"DP-006 commit 审计"}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `ts` | ISO 8601 | ✅ | 执行时间戳 |
| `skill` | string | ✅ | skill 名称：ggp / codex-bridge / healthcheck / session-init / failure-log |
| `project` | string | ✅ | 项目名：guanghe / super-founder / 等 |
| `domain` | string | ✅ | PPR 域：_governance / _infra / _platform / huanlong |
| `result` | string | ✅ | 结果：PASS / FAIL / SKIP / ERROR |
| `duration_s` | number | ⚪ | 执行耗时（秒），可选 |
| `notes` | string | ⚪ | 备注，可选 |

## 记录时机

每个 skill 执行完毕后，追加一行到 `usage-log.jsonl`。通过 Desktop Commander：

```bash
echo '{"ts":"...","skill":"...","project":"...","domain":"...","result":"..."}' >> {HARNESS}/30-evals/toolkit-usage/logs/usage-log.jsonl
```

## 分析方式

在 Cowork session 中用 Python 分析：

```python
import json
lines = open('usage-log.jsonl').readlines()
records = [json.loads(l) for l in lines]

# 按 skill 统计
from collections import Counter
Counter(r['skill'] for r in records)

# 按结果统计
Counter(r['result'] for r in records)

# 失败率趋势
fails = [r for r in records if r['result'] == 'FAIL']
```

## 迭代触发条件

| 信号 | 行动 |
|------|------|
| 某 skill 失败率 > 30% | 优先修复该 skill |
| 某 skill 30 天未使用 | 评估是否废弃或合并 |
| 同类 notes 重复 ≥ 3 次 | 提炼为自动化规则 |
| duration_s 中位数持续上升 | 性能优化 |
| 新 skill 需求出现 ≥ 2 次 | 评估新建 skill |
