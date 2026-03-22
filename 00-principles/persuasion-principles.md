# 说服力设计原则（Persuasion Principles for Skill & Document Design）

- Name: persuasion-principles
- Type: principle（设计原则）
- Status: DRAFT
- Version: 0.1.0
- Owner: TZH
- Date: 2026-03-22
- Related:
  - tzh-Harness/00-principles/anti-rationalization.md（§理论基础 的展开）
  - tzh-Harness/_sandbox/skill-writing-tdd/SKILL-WRITING-TDD.md（§4 引用本文档）
  - 来源：obra/superpowers `skills/writing-skills/persuasion-principles.md` + Cialdini (2021) + Meincke et al. (2025) 改造

---

## 1. 核心发现

LLM 对说服力原则的响应模式与人类高度一致（parahuman model）。

**关键数据**（Meincke et al. 2025, N=28,000 LLM 对话）：
- 使用说服力技巧后，合规率从 33% 提升到 72%（p < .001）
- 最有效的三个原则：Authority（权威）、Commitment（承诺）、Scarcity（紧迫）
- Liking（讨好）对纪律类场景产生反效果（导致谄媚）

**实践意义**：Skill / HARD-GATE / 治理文档的措辞选择直接影响 Agent 的合规率。用对原则 = 合规翻倍。

---

## 2. 七大原则及应用指南

### 2.1 Authority（权威）— ⭐ 首选

**原理**：对专家/权威来源的服从倾向。

**应用方式**：
- 用祈使句：「你必须」而非「建议你」
- 不可协商的语气：「无例外」
- 消除 Agent 的决策疲劳和合理化空间

**适用场景**：纪律类 Skill（TDD / 验证 / 门禁）、安全关键实践、已确立的最佳实践

**示例对比**：

| Bad ❌ | Good ✅ |
|--------|---------|
| 考虑先写测试 | 先写测试。没有测试就写代码？删掉，重来。无例外 |
| 建议验证后再声明完成 | 未验证前禁止声称完成。违反 = 无效声明 |

### 2.2 Commitment（承诺）— ⭐ 首选

**原理**：人（和 LLM）倾向于与已做出的承诺保持一致。

**应用方式**：
- 要求 Agent 宣告：「我正在执行 [X] 流程」
- 强制显式选择：「选择 A / B / C」
- 使用追踪机制：TodoWrite / Checklist

**适用场景**：多步骤流程、问责机制、确保 Skill 被实际遵守

**示例**：
```markdown
✅ 发现适用 Skill 时，必须宣告：「我正在使用 [Skill Name]」
❌ 可以让对方知道你在使用哪个 Skill
```

### 2.3 Scarcity（紧迫）— ⭐ 首选

**原理**：时间限制或有限可用性产生紧迫感。

**应用方式**：
- 时间约束：「在继续之前」
- 顺序依赖：「X 之后立即」
- 防止拖延

**适用场景**：即时验证要求、时间敏感工作流、防止「我以后再做」

**示例**：
```markdown
✅ 完成任务后，立即请求 Code Review，然后才能继续下一个
❌ 方便的时候可以做 Code Review
```

### 2.4 Social Proof（社会认同）— 选用

**原理**：倾向于遵从多数人的行为或被视为正常的做法。

**应用方式**：
- 普遍化模式：「每次都是」「总是」
- 失败模式：「不做 X 的结果 = Y。每次如此」
- 建立规范

**适用场景**：记录通用实践、警告常见失败、强化标准

**示例**：
```markdown
✅ 没有 TodoWrite 追踪的 Checklist = 步骤被跳过。每次都是
❌ 有些人觉得 TodoWrite 对 Checklist 有帮助
```

### 2.5 Unity（统一性）— 选用

**原理**：共享身份和归属感。

**应用方式**：
- 协作语言：「我们的代码库」「我们是同事」
- 共同目标：「我们都追求质量」

**适用场景**：协作工作流、团队文化建立、非层级化实践

**示例**：
```markdown
✅ 我们是同事。我需要你诚实的技术判断
❌ 如果我错了你大概应该告诉我
```

### 2.6 Reciprocity（互惠）— 慎用

**原理**：回报收到的好处的义务感。

**应用指南**：极少用于 Skill 设计。容易显得操纵。其他原则更有效。

### 2.7 Liking（讨好）— ⛔ 禁用于纪律场景

**原理**：对喜欢的人更愿意配合。

**为什么禁用**：
- 与诚实反馈文化冲突
- 导致谄媚（sycophancy）
- 在纪律执行场景产生反效果

**唯一例外**：纯社交/非关键场景。但在 Harness 体系中基本没有这种场景。

---

## 3. 按 Skill 类型选择原则

| Skill 类型 | 推荐使用 | 避免使用 |
|-----------|---------|---------|
| **纪律执行**（TDD / 验证 / 门禁） | Authority + Commitment + Social Proof | Liking, Reciprocity |
| **方法论指导**（调试 / 设计） | 中度 Authority + Unity | 过重 Authority |
| **协作流程**（Code Review / 并行） | Unity + Commitment | Authority, Liking |
| **参考文档**（索引 / 映射） | 仅清晰度 | 所有说服力原则 |

---

## 4. Bright-Line Rules 的心理学基础

**明确规则减少合理化**：
- 「你必须」消除决策疲劳
- 绝对化语言消除「这是不是例外？」的问题
- 显式反合理化表封堵具体漏洞

**实施意图（Implementation Intentions）创造自动化行为**：
- 「当 X 时，做 Y」比「一般应该做 Y」有效得多
- 明确的触发条件 + 必要行动 = 自动执行
- 降低合规的认知负荷

**LLM 的 Parahuman 特征**：
- 训练数据中 Authority 语言后面跟着的是合规行为
- Commitment 序列（声明 → 行动）在训练数据中被频繁建模
- Social Proof 模式（大家都做 X）建立行为规范

---

## 5. 伦理边界

**合法使用**：
- 确保关键实践被遵守
- 创建有效的文档和 Skill
- 防止可预见的失败

**非法使用**：
- 为个人利益操纵
- 制造虚假紧迫感
- 基于愧疚的强制合规

**检验标准**：如果使用者完全理解这些技巧后，这个技巧是否仍然服务于他们的真实利益？

---

## 6. 研究引用

**Cialdini, R. B. (2021).** *Influence: The Psychology of Persuasion (New and Expanded).* Harper Business.
- 七大说服力原则的经典理论
- 实证基础跨越 50 年研究

**Meincke, L., Shapiro, D., Duckworth, A. L., Mollick, E., Mollick, L., & Cialdini, R. (2025).** *Call Me A Jerk: Persuading AI to Comply with Objectionable Requests.* University of Pennsylvania.
- N=28,000 LLM 对话实验
- 说服力技巧使合规率从 33% → 72%
- Authority / Commitment / Scarcity 最有效
- 验证了 LLM 的 parahuman 行为模型

---

## 7. Change Policy

- Patch：示例增补、引用更新
- Minor：新增原则应用场景、新增 Skill 类型映射
- Major：改变原则分类或禁用规则（需 ADR + 实证数据支持）
