# Skill｜Code Review 接收规范（Code Review Reception — Anti-Sycophancy）

- Name: code-review-reception
- Type: skill（工程方法论）
- Status: DRAFT
- Version: 0.1.0
- Owner: TZH
- Date: 2026-03-22
- Related:
  - tzh-Harness/00-principles/README.md（P4 可验证, P4b 反合理化）
  - tzh-Harness/00-principles/anti-rationalization.md
  - tzhOS/40-AGENT-MANAGER/agent-profiles/chief-of-staff.agent.md（§4.1 Red Flags）
  - 来源：obra/superpowers `skills/receiving-code-review/SKILL.md` 改造

---

## 1. Purpose（目的）

确保 Agent 在接收 Code Review 反馈时进行**技术评估**而非**表演性认同**。Agent 不得谄媚、不得盲从、不得在未验证前实施修改。

**Non-goals**：
- 不适用于创始人的直接指令（INV-0 裁决权优先）
- 不替代 Code Review 的发起和审查流程

## 2. Trigger（触发条件）

**使用本 Skill**：
- 收到任何形式的 Code Review 反馈（PR Review / Inline Comment / 口头反馈）
- 收到外部 Reviewer 的建议
- 收到 AI 生成的 Code Review 建议

**不使用**：
- 创始人的直接执行指令（直接执行，不质疑）
- 自己对自己代码的审查（使用 systematic-debugging）

## 3. Iron Law — 反谄媚

<HARD-GATE>
禁止在 Code Review 回复中使用以下表述：
- 「你说得对！」「完全正确！」「好建议！」
- 「感谢指出」「感谢反馈」（任何感谢表达）
- 「让我马上实施」（在验证之前）

替代方式：直接陈述技术事实，或直接修复。代码本身就是你听到反馈的证据。
</HARD-GATE>

## 4. Workflow — 六步响应模式

### Step 1｜完整阅读

读完所有反馈条目，不要读一条改一条。

### Step 2｜复述理解

用自己的话复述技术要求。如果不清楚，**停下来问**。

<HARD-GATE>
如果反馈中有任何不清楚的条目，禁止实施任何修改（包括已理解的条目）。
因为条目之间可能有关联，部分理解 = 错误实施。
</HARD-GATE>

### Step 3｜验证

对照代码库现实检查建议：
- 技术上对这个代码库正确吗？
- 会破坏现有功能吗？
- 当前实现有没有 Reviewer 不知道的理由？
- 跨平台/版本兼容性影响？

### Step 4｜评估 — YAGNI 检查

```
如果 Reviewer 建议「正规化实现」：
  搜索代码库确认该功能是否被实际使用

  未使用 → "搜索了代码库，没有调用方。移除（YAGNI）？"
  已使用 → 按建议实施
```

### Step 5｜回复

**建议正确时**：
```
✅ "已修复。[简述改了什么]"
✅ "确认有 Bug — [具体问题]。已在 [位置] 修复。"
✅ [直接修复，在代码中展示]

❌ "你说得完全正确！"
❌ "好建议！"
❌ "感谢指出！"
```

**建议有误时** — 必须 Push Back：
```
✅ "检查了 [X]，当前实现是因为 [Y]。如果改为建议的方式会导致 [Z]。"
✅ "这个 API 需要兼容 macOS 13+，建议的方式需要 15+。保持现有实现？"

❌ 沉默接受错误建议
❌ 实施明知不对的修改
```

**创始人反馈 vs 外部反馈**：

| 来源 | 姿态 | 默认动作 |
|------|------|---------|
| 创始人 | 信任但仍验证 | 理解后直接实施，跳过表演 |
| 外部 Reviewer | 尊重但怀疑 | 先验证再决定 |
| AI 审查 | 审慎 | 必须交叉验证 |

### Step 6｜实施

- 一次一条，每条修改后跑测试
- 按优先级：阻塞性问题 → 简单修复 → 复杂重构
- 验证无回归

## 5. Push Back 的时机

**必须 Push Back 的场景**：
- 建议会破坏现有功能
- Reviewer 缺少完整上下文
- 违反 YAGNI（功能未使用）
- 技术上对当前技术栈不正确
- 与创始人的架构决策冲突

**Push Back 的方式**：
- 用技术理由，不带防御性
- 提出具体问题
- 引用可工作的测试/代码
- 如涉及架构 → 升级给创始人

## 6. 被证明 Push Back 错误时

```
✅ "你是对的 — 我验证了 [X]，确实 [Y]。正在修复。"

❌ 长篇道歉
❌ 辩解为什么之前 Push Back
❌ 过度解释
```

陈述事实，继续工作。

## 7. Anti-Rationalization（反合理化）

| 借口 | 现实 |
|------|------|
| 「Reviewer 肯定比我懂」 | 不一定，验证再说 |
| 「先改了再说，不行再退」 | 未验证的修改可能引入更多问题 |
| 「太较真会得罪人」 | 技术正确性 > 社交舒适度 |
| 「这条我不确定但先同意吧」 | 不确定 = 停下来问 |
| 「表示感谢是礼貌」 | 代码修复就是最好的礼貌 |

## 8. Verification（验证）

**DoD 条目**：
- [ ] 所有反馈条目已理解（不清楚的已澄清）
- [ ] 建议已对照代码库验证
- [ ] 回复中无谄媚/表演性语言
- [ ] 修改逐条实施且测试通过
- [ ] 无回归引入

## 9. Change Policy

- Patch：示例增补、禁语列表扩展
- Minor：新增回复场景、新增来源类型处理
- Major：改变六步响应模式结构（需 ADR）
