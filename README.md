# tzh-Harness

> Harness Engineering — AI 驱动研发方法论
> 治理归属：tzhOS（CHARTER + SAAC-001）
> 状态：初始化

## 定位

Harness Engineering 的方法论标准仓库，定义 AI 驱动研发的：

- **SOP（标准作业程序）**：Plan-Then-Execute、Spec-Driven、Deterministic Gates
- **执行标准**：Trace / Evals / GC 验证体系
- **评测体系**：黄金样本、验收标准、运行记录格式

## 与唤龙超级工厂的关系

- `tzh-Harness`：方法论标准（tzhOS 治理视角），定义"怎么做研发"
- `hl-factory/harness-engineering/`：唤龙超级工厂的研发执行内核（SAAC-HL-001 治理），是工厂级落地实现
- **两者无代码/包依赖关系**，可参考但独立演进

## 治理

本仓库受 tzhOS 全部治理约束，遵循：

- INV-0：创始人裁决权
- CHARTER：使命与行为规范
- SAAC-001：架构分层契约

## 目录结构（规划）

```
tzh-Harness/
├── README.md
├── CLAUDE.md           # AI 会话上下文协议
├── 00-principles/      # 核心原则与哲学
├── 10-sop/             # 标准作业程序
├── 20-standards/       # 执行标准与验收标准
├── 30-evals/           # 评测框架与模板
└── 40-references/      # 参考资料与案例库
```
