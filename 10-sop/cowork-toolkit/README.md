# tzhOS Toolkit

tzhOS 的个人 Cowork 工具箱插件。封装日常开发中的可复用工作流，减少重复配置。

## 安装

在 Cowork 聊天中，点击出现的 `.plugin` 文件卡片，按提示安装。

## Skills

### `session-init`

**用途**：PPR session 初始化协议。根据用户选择的工作域，加载项目配置、建立 session 上下文。

**触发方式**：输入 `/tzhos-toolkit:session-init`，或说"初始化""开始工作""set context"

**执行流程**：

1. **选择焦点域** — 从 PPR 四域中选择本次 session 工作焦点
2. **加载项目 CLAUDE.md** — 摘要提取核心规则（不全量注入，防 context 膨胀）
3. **Git 焦点摘要** — 最近 commits + 当前分支 + 工作区状态
4. **写入 session 状态** — `/tmp/cowork-session.json`，其他 skill 可读取

**与 healthcheck 的关系**：healthcheck = 只读诊断，session-init = 有写入权限的初始化动作。建议先 healthcheck 再 init。

---

### `cowork-healthcheck`

**用途**：每次新建 Cowork session 时执行环境诊断。

**触发方式**：输入 `/tzhos-toolkit:cowork-healthcheck`

**检查内容**（PPR v2.1 aligned）：

1. **PPR 四域 Repo 扫描** — `_governance/` `_infra/` `_platform/` `huanlong/` 全域 git 状态
2. **工具链就绪度** — Claude Code CLI、API Keys（GGP 依赖）、Desktop Commander
3. **Context Budget 审计** — 统计全部 skill description 字符数，按阈值标色（🟢/🟡/🔴）
4. **PPR 角色映射** — 验证 5 System Roles（Judge/Orchestrator/Executor/Verifier/Auditor）工具覆盖
5. **CLAUDE.md 健康检查** — 路径是否过期、文件是否过长
6. **构建状态快照** — 可选，按需触发

**输出**：结构化诊断报告 + 按优先级排序的建议操作列表。选编号执行，或说"跳过"开始工作。

### `codex-bridge`

**用途**：从 Cowork 向宿主机 Claude Code CLI 同步派发 skill 并自动回收结果。替代旧的异步 codex-dispatch。

**触发方式**：说"build""编译""测试""跑一下"，或 `/tzhos-toolkit:codex-bridge <skill-command>`

**支持的 skills**：dual-build, slice-execute, compliance-audit, p0-gate

**核心升级**：通过 osascript + 日志捕获 + sentinel 轮询实现结果自动回收，无需切到 Terminal 查看。

### `ggp`

**用途**：Guanghe Gate Protocol 三轮交叉审计。通过 Gemini + GPT 竞争模型交叉检查 Claude 盲区。

**触发方式**：说"审计""跑 GGP""三审""gate check"，或 `/tzhos-toolkit:ggp`

**三轮分工**：

| Round | 模型 | 角色 |
|-------|------|------|
| 1 | Gemini 3.1 Pro | 安全与逻辑审计 |
| 2 | GPT-5.4 | 工程质量审计 |
| 3 | Gemini 3.1 Pro | 测试完整性审计（条件触发） |

**前置条件**：宿主机需设置 `GOOGLE_AI_KEY` + `OPENAI_API_KEY` 环境变量。

### `failure-log`

**用途**：结构化失败归档。将 GGP 审计失败、构建错误、Verify Re-Plan 等事件写入项目 `.claude/failure-log/`，Git 版本化追踪。

**触发方式**：说"记录失败""failure log""归档失败"，或由 GGP/codex-bridge 失败时自动建议

**核心能力**：

1. **归档** — 生成结构化 JSON 失败记录，写入项目 repo（走高风险确认）
2. **查询** — 按时间/类型/项目筛选历史失败
3. **关闭** — `resolve {ID}` 标记已修复，记录修复方案和 lessons learned
4. **提炼** — 同类失败 ≥ 2 次时，建议提炼为 Checklist 更新 CLAUDE.md

**设计原则**：CLAUDE.md 第 27 条——"犯错留痕，转化为资产"。

## 版本历史

- **0.6.0** — 新增 failure-log（结构化失败归档、resolve 关闭、Checklist 提炼）
- **0.5.0** — 新增 session-init（PPR 域焦点选择、项目 CLAUDE.md 加载、session 状态文件）
- **0.4.0** — cowork-healthcheck PPR v2.1 升级（四域扫描、工具链检查、PPR 角色映射、构建快照改为按需）
- **0.3.0** — codex-dispatch → codex-bridge 升级（同步结果回收、多项目支持、去除已废弃的 dual-audit）
- **0.2.0** — 新增 GGP 三轮交叉审计 skill（多项目支持、JSON 结构化报告）
- **0.1.0** — 初版，包含 cowork-healthcheck + codex-dispatch
