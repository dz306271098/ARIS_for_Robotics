# ARIS 项目架构指南

> 面向接手者的全局说明：这个仓库不是传统意义上的“应用代码仓库”，而是一个以 `SKILL.md` 为核心载体的科研 Agent 工作流系统。
>
> **重要说明**：`README_CN.md` 现在已经提升为当前主线的中文主手册，但像 `docs/INERTIAL_ODOMETRY_GUIDE_CN.md` 这类领域化指南仍然会暴露更多面向具体场景的落地细节，例如更强的实验约束、领域化参数和长周期运行建议。

## 一句话定义

ARIS 的本体不是某个 Python 框架，而是一套可被不同 Agent 宿主读取和执行的**科研工作流协议 + 持久化研究状态系统**：

- 用 `skills/*/SKILL.md` 定义流程
- 用项目级 Markdown/JSON 文件保存状态
- 用 `mcp-servers/` 把外部 reviewer、通知和模型能力接进来
- 用少量 `tools/` 补足检索、监控和适配脚本
- 用 `research-wiki/`、`innovation-logs/`、`.aris/meta/` 累积长期研究记忆与自我优化证据

如果把它硬套进传统分层，可以理解为：

```text
工作流定义层   = skills/
状态持久化层   = 项目根目录中的 Markdown / JSON 文件
能力接入层     = mcp-servers/
辅助脚本层     = tools/
文档与模板层   = docs/ + templates/
```

## 先抓主线：用户看到的是什么

从用户视角，这个项目提供的不是单个功能，而是一条完整科研链路。核心入口不止是“发现 idea 到写论文”的线性流程，还包括持续创新、知识沉淀和自我优化。

关键入口包括：

```text
/idea-discovery
/research-refine-pipeline
/experiment-bridge
/auto-review-loop
/deep-innovation-loop
/result-to-claim
/paper-writing
/rebuttal
/research-pipeline
/research-wiki
/meta-optimize
```

其中 `/research-pipeline` 是总编排器；而在较新的文档语境里，`/deep-innovation-loop` 已经不是边缘扩展，而是全自主科研的核心引擎。

### Workflow 1: `idea-discovery`

目标：从一个研究方向出发，产出经过文献调研、查新、审稿和初步 pilot 验证的 idea 候选。

内部子链路：

```text
/research-lit
  -> /idea-creator
  -> /novelty-check
  -> /research-review
  -> /research-refine-pipeline
```

这一阶段的关键产物不是代码，而是结构化状态文件，例如：

- `IDEA_REPORT.md`
- `IDEA_CANDIDATES.md`
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

### Workflow 1.5: `experiment-bridge`

目标：把“想法/方案”变成“可运行实验”。

它读取上游实验计划和 proposal，做三件事：

1. 理解实验设计和 run order
2. 在当前项目或 `base repo` 上补齐实现
3. 先自审，再部署，再收回首轮结果

这一步是从“研究规划”切换到“工程执行”的桥梁，所以被称为 bridge。

### Workflow 2: `auto-review-loop`

目标：让外部 reviewer 持续给出苛刻反馈，再由执行者修复问题，形成循环。

核心循环是：

```text
外部评审
  -> 解析问题
  -> 设计修复策略
  -> 改代码 / 改实验 / 改叙事
  -> 重新跑实验
  -> 再评审
```

这里最重要的设计思想是**执行者与审稿者分离**。ARIS 明确反对“同一个模型既写又审”的自我博弈，而是强调跨模型审稿。

不过在较新的使用手册里，`auto-review-loop` 更像**快速迭代模式**：适合 4 轮左右的 review-fix 循环，而不是系统最强形态。

### Workflow 2.5: `deep-innovation-loop`

目标：在已有方法和实验基础上，进行长周期、全自主、可恢复的“诊断 → 调研 → 创新 → 实现 → 评估 → 反思”迭代。

它不是 `auto-review-loop` 的简单加长版，而是另一套更强的运行范式：

- 默认以 40+ 轮为尺度
- 以**根因诊断**而不是表面修补为起点
- 引入**五层原理提取**，吸收邻近领域原理而不是照搬方法
- 每轮都包含 GPT 审查实验设计和代码
- 通过统计显著性、内联消融、黑名单、技术库避免“lucky seed”与重复试错

更关键的是，它引入了 ARIS 的双模式博弈机制：

- **对抗模式**：reviewer 负责挑战、淘汰弱方案
- **协作模式**：当系统陷入僵局时，执行者与 reviewer 联手重新诊断、联合设计新方案

这说明当前 ARIS 的核心已经不是“自动 review 几轮”，而是“自主研究进化循环”。

### Workflow 3: `paper-writing`

目标：把研究叙事和实验结果落成论文目录和 PDF。

内部子链路：

```text
/paper-plan
  -> /paper-figure
  -> /paper-write
  -> /paper-compile
  -> /auto-paper-improvement-loop
```

这条链路从 narrative 出发，不是从 LaTeX 模板出发。换句话说，ARIS 把“论文”理解为 research narrative 的工程化落地。

### Workflow 4: `rebuttal`

目标：在投稿后处理外部 review，生成安全、可追溯、受字符限制约束的 rebuttal。

这一工作流和前面的最大区别是：它不再围绕“发现新 idea”，而是围绕“已有论文 + 外部审稿意见 + 安全回复约束”展开。

它特别强调三个安全门：

- 不编造
- 不过度承诺
- 全覆盖

### 总入口: `research-pipeline`

`/research-pipeline` 的作用是把上面的阶段拼成总路线：

```text
idea-discovery
  -> research-refine-pipeline
  -> implementation / experiment-bridge
  -> run-experiment
  -> auto-review-loop 或 deep-innovation-loop
  -> result-to-claim
  -> paper-writing
  -> 可继续进入 rebuttal
```

所以它不是“另一个 skill”，而是整个系统的总导演。

在更新的运行范式里，更准确的理解是：

```text
research-pipeline
  = 创意发现
  -> 方法精炼
  -> 实验桥接
  -> 深度创新或快速审查
  -> 从结果抽取声明
  -> 论文写作
```

## 再看内部：开发者真正要维护什么

### 1. `skills/` 是系统本体

这个目录是 ARIS 的核心。绝大多数能力不是写在 Python 里，而是写在 `SKILL.md` 里。

可以把每个 `SKILL.md` 理解为：

- 任务边界定义
- 输入/输出契约
- 工具使用规则
- 下游 skill 调用方式
- 中间状态文件约定

因此，这个项目更接近“声明式工作流仓库”，而不是“函数调用仓库”。

可粗分为几类：

- 主 workflow：
  - `idea-discovery`
  - `research-refine-pipeline`
  - `experiment-bridge`
  - `auto-review-loop`
  - `deep-innovation-loop`
  - `result-to-claim`
  - `paper-writing`
  - `rebuttal`
  - `research-pipeline`
- 原子能力：
  - `research-lit`
  - `idea-creator`
  - `novelty-check`
  - `research-review`
  - `paper-plan`
  - `paper-figure`
  - `paper-write`
  - `paper-compile`
- 配套能力：
  - `monitor-experiment`
  - `training-check`
  - `ablation-planner`
  - `feishu-notify`
  - `vast-gpu`
  - `research-wiki`
  - `meta-optimize`
- 扩展型能力：
  - `deep-innovation-loop`
  - `grant-proposal`
  - `paper-slides`
  - `paper-poster`
  - `proof-writer`
  - `formula-derivation`

### 2. `shared-references/` 提供跨 skill 共享协议

这个目录不是 skill，但它很关键。里面放的是：

- reviewer 输出 schema
- principle extraction 规则
- citation / writing / venue checklist
- context integrity 等共识性规范

作用是把多个 skill 的行为约束统一起来，避免每个 `SKILL.md` 各写各的。

### 3. `skills-codex*` 不是分叉系统，而是适配层

这部分很容易被误解。仓库里有三套相关目录：

- `skills/skills-codex/`
- `skills/skills-codex-claude-review/`
- `skills/skills-codex-gemini-review/`

它们不是三套互不相干的产品，而是：

1. `skills-codex/`
   - 把主线 skill 翻译成 Codex CLI 可执行的版本
   - 保留工作流边界，但把原先的控制写法改成 Codex 侧的 agent / tool 语义

2. `skills-codex-claude-review/`
   - 在 `skills-codex/` 之上覆写 reviewer-heavy skills
   - 把“第二个 Codex reviewer”替换成“Claude reviewer bridge”

3. `skills-codex-gemini-review/`
   - 同理，把 reviewer-heavy skills 替换成 Gemini reviewer bridge

因此，它们的关系是：

```text
主线 skills
  -> Codex 适配
     -> Claude reviewer overlay
     -> Gemini reviewer overlay
```

这也是为什么安装文档里总强调“先装基础 skill，再叠加 overlay”。

### 4. `mcp-servers/` 是主要代码维护面，但不再是全部运行时真相

如果说 `skills/` 是流程定义层，那么 `mcp-servers/` 是运行时能力接入层的一部分。较新的文档还表明，主线 reviewer 路径已经明显转向 **Codex 三工具架构**，而不是完全依赖旧的 `mcp__codex__codex` 通道。

当前主要包括：

- `llm-chat/`
  - 通用 OpenAI-compatible reviewer 通道
  - 通过环境变量切模型和 base URL
- `minimax-chat/`
  - MiniMax Chat Completions 的 MCP server
  - 是当前测试覆盖最明确的一支
- `claude-review/`
  - 让 Codex 执行、Claude 审稿
- `gemini-review/`
  - 让 Codex 执行、Gemini 审稿
  - 同时支持同步和异步 review
- `feishu-bridge/`
  - 负责通知和简单的人在回路交互

这些 server 的共同点是：

- 都是窄接口
- 都围绕某个非常具体的 reviewer 或通知契约
- 都不是通用平台，而是为 ARIS 当前工作流量身适配

但需要更新一个认识：

- 旧文档强调的是 “Claude Code + Codex MCP”
- 新文档强调的是：
  - `codex exec --output-schema` 负责结构化评分、多轮对话、图片审查
  - `/codex:adversarial-review` 负责强制代码审查
  - `/codex:rescue --effort xhigh` 负责失败诊断、深度调查、协作求解

也就是说，当前系统的 reviewer 能力已经不只是 bridge server，而是**bridge + Codex 原生命令/插件 + JSON schema 协议**共同组成的。

### 5. `tools/` 是补洞脚本，但有些已经成为关键基础设施

这个目录里的脚本分三类：

- 检索类：
  - `arxiv_fetch.py`
  - `semantic_scholar_fetch.py`
  - `research_wiki.py`
- 适配/生成类：
  - `generate_codex_claude_review_overrides.py`
- 运维/监控类：
  - `watchdog.py`
  - `meta_opt/*`

它们很重要，但定位不是“项目主入口”，而是支撑 skill 工作流的工具件。

其中需要特别单独拎出来的是：

- `watchdog.py`
  - 已不是普通辅助脚本，而是长期运行任务监控的统一守护工具
- `arxiv_fetch.py` / `semantic_scholar_fetch.py`
  - 是“Web 韧性”设计的重要组成部分，因为新工作流明确要求 API 优先、超时放弃、优雅降级

## 这个项目真正怎么跑起来

### 机制 1: skill 不是文档注释，而是执行规格

在 ARIS 里，`SKILL.md` 不是“说明书”，而是实际运行时会被 agent 读取并执行的工作流协议。

这意味着：

- 读 skill 等于读系统设计
- 改 skill 等于改业务逻辑
- 许多行为变化不会出现在 Python diff，而会出现在 Markdown diff

这和传统项目很不一样。

### 机制 2: 项目状态靠文件，不靠数据库

ARIS 的长期状态保存在项目目录内的 Markdown / JSON 文件中，而不是数据库。

核心设计见 `PROJECT_FILES_GUIDE*`，但更近期的手册显示，状态体系已经从基础 pipeline 文件扩展为多层持久化：

```text
idea 流
  IDEA_REPORT.md
  -> IDEA_CANDIDATES.md
  -> docs/research_contract.md

实验流
  EXPERIMENT_PLAN.md
  -> EXPERIMENT_TRACKER.md
  -> EXPERIMENT_LOG.md
  -> findings.md

review 流
  AUTO_REVIEW.md
  -> REVIEW_STATE.json

创新流
  innovation-logs/INNOVATION_STATE.json
  -> TECHNIQUE_LIBRARY.md
  -> EVOLUTION_LOG.md
  -> BLACKLIST.md
  -> score-history.csv

知识图谱流
  research-wiki/papers
  -> ideas
  -> experiments
  -> claims
  -> graph/edges.jsonl

自优化流
  .aris/meta/events.jsonl
  -> optimizations.jsonl
  -> backups/
```

这样设计的目的不是“简单”，而是为了：

- 会话恢复
- 上下文压缩后继续工作
- 不依赖宿主平台的会话历史
- 让不同 Agent 共享同一份项目状态

### 机制 3: reviewer 被外置，而且已经形成“三工具架构”

ARIS 的关键方法论是：

- 主执行者负责实现、跑实验、改文稿
- 外部 reviewer 负责打分、找漏洞、提出修复要求

因此 reviewer 是系统中的一等公民，而不是辅助工具。并且在新主线里，reviewer 已经被标准化成三种能力接口：

- 结构化评审
- 强制代码审查
- 深度救援/协作诊断

这也是 `claude-review` / `gemini-review` / `llm-chat` 这些 bridge 的存在意义。

更进一步说，ARIS 现在的真正方法论是：

- reviewer 负责批判和验证
- executor 负责实现和收集证据
- 当批判循环卡住时，系统会升级到“协作诊断/协作设计”，然后再回到对抗验证

### 机制 4: overlay 复用主工作流，而不复制整套系统

Codex、Claude、Gemini 的差异主要出现在“谁来当 reviewer”“调用接口是什么”这层，而不是研究工作流本身。

所以仓库采取的是：

- 复用主线流程结构
- 仅覆写 reviewer-aware skills
- 用脚本自动生成部分 overlay

`tools/generate_codex_claude_review_overrides.py` 就体现了这个思路：它不是手写重构全部 skills，而是对目标 skills 做受控变换。

## 典型调用链

### A. 从研究方向到实验计划

```text
/research-pipeline
  -> /idea-discovery
     -> /research-lit
     -> /idea-creator
     -> /novelty-check
     -> /research-review
     -> /research-refine-pipeline
  -> 读取 refine-logs/EXPERIMENT_PLAN.md
```

### B. 从实验计划到首轮结果

```text
/experiment-bridge
  -> 读 proposal / plan / tracker
  -> 补实验代码
  -> reviewer 代码审查
  -> /run-experiment
  -> /monitor-experiment
```

### C. 从结果到 submission-ready 版本

```text
/auto-review-loop
  -> reviewer 给分
  -> 解析 blocking weaknesses
  -> 设计 fix strategy
  -> 改实现 / 改实验 / 改叙事
  -> 多轮复审
```

更新后的旗舰路径则更接近：

```text
/deep-innovation-loop
  -> 根因诊断
  -> 定向文献调研 + 五层原理提取
  -> 变体设计 + 对抗挑战
  -> 实现 + 强制代码审查
  -> 多种子评估 + 显著性判定
  -> 内联消融 + 技术库更新 + 黑名单更新
  -> 僵局时协作诊断 / 协作设计
```

### D. 从 narrative 到 PDF

```text
/paper-writing
  -> /paper-plan
  -> /paper-figure
  -> /paper-write
  -> /paper-compile
  -> /auto-paper-improvement-loop
```

### E. 投稿后答辩

```text
/rebuttal
  -> review atomization
  -> strategy plan
  -> 可选 evidence sprint
  -> draft
  -> safety validation
  -> stress test
  -> paste-ready rebuttal
```

## 哪些地方成熟，哪些地方要谨慎

### 相对成熟的部分

- 工作流拆分清晰，主线非常完整
- 状态文件体系设计明确
- 创新循环的长期状态设计比 README 展示得更成熟
- reviewer overlay 的思路统一
- `gemini-review` / `claude-review` 已经明显按“可恢复任务”设计
- `templates/` 和 `docs/` 很适合新用户上手

### 需要谨慎理解的部分

- “零依赖”主要指 skill 层足够轻，不代表代码层没有依赖
- 顶层 README 更适合营销和入门，不适合作为当前系统全貌的唯一依据
- 仓库中的核心逻辑大量写在 Markdown 里，传统代码搜索并不能覆盖全部行为
- 大部分 workflow 是声明式规范，不是可直接 import 的 Python API
- 部分工程质量更像“高质量脚本/协议仓库”，而不是严格模块化的软件包

### 当前代码维护的真实重点

如果要持续维护这个项目，最值得重点看的是：

1. 三工具 reviewer 契约是否稳定
2. `deep-innovation-loop`、`result-to-claim`、`research-wiki`、`meta-optimize` 是否与主线协同
3. 各类 `SKILL.md` 是否仍与最新状态文件规范一致
4. 远程实验、监控、通知链路是否还能跑通
5. 领域指南与顶层 README 是否发生语义漂移

而不是先去做传统意义上的“类设计优化”。

## 测试与工程现实

`tests/` 目前主要围绕 `mcp-servers/minimax-chat/`，而不是整个 ARIS 流程。

这说明当前自动化验证重点是：

- 某些 MCP server 是否按预期响应 JSON-RPC
- 某些模型接入的参数是否正确

而不是：

- 全工作流端到端验证
- 各类 skill 的统一回归测试

另外，`tests/_minimax_helpers.py` 的存在也说明一个现实问题：`server.py` 在模块顶层直接改写 `stdin/stdout`，导致测试不得不引入 helper 镜像逻辑来规避副作用。

这类写法对 CLI/MCP server 是实用的，但会削弱可测试性。

## 推荐的阅读顺序

如果你要快速接手，不要从零散脚本开始读。推荐顺序如下：

1. `docs/INERTIAL_ODOMETRY_GUIDE_CN.md`
   - 这是当前最能体现系统新形态的操作手册之一，能看到 `deep-innovation-loop`、三工具架构、wiki、meta-optimize
2. `docs/PROJECT_FILES_GUIDE_CN.md`
   - 理解状态文件和恢复机制
3. 核心 workflow skill
   - `skills/research-pipeline/SKILL.md`
   - `skills/idea-discovery/SKILL.md`
   - `skills/research-refine-pipeline/SKILL.md`
   - `skills/experiment-bridge/SKILL.md`
   - `skills/auto-review-loop/SKILL.md`
   - `skills/deep-innovation-loop/SKILL.md`
   - `skills/result-to-claim/SKILL.md`
   - `skills/paper-writing/SKILL.md`
   - `skills/rebuttal/SKILL.md`
4. 系统扩展能力
   - `skills/research-wiki/SKILL.md`
   - `skills/meta-optimize/SKILL.md`
5. reviewer overlay 文档
   - `docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md`
   - `docs/CODEX_GEMINI_REVIEW_GUIDE_CN.md`
6. 关键代码入口
   - `mcp-servers/claude-review/server.py`
   - `mcp-servers/gemini-review/server.py`
   - `mcp-servers/llm-chat/server.py`
   - `mcp-servers/minimax-chat/server.py`
7. 辅助脚本
   - `tools/generate_codex_claude_review_overrides.py`
   - `tools/watchdog.py`
   - `tools/arxiv_fetch.py`
   - `tools/semantic_scholar_fetch.py`
8. 最后再回头读 `README_CN.md`
   - 用来理解对外叙事，而不是作为当前实现真相

## 最后的判断

对 ARIS 最准确的理解不是“自动写论文工具”，也不是“几个 prompt 的集合”，而是：

> 一套围绕科研流程、文件状态机和跨模型审稿机制构建的 Agent 工作流系统。

它的核心竞争力不在单个脚本，而在下面几件事的组合：

- 从 idea 到 rebuttal 的完整流程编排
- `deep-innovation-loop` 带来的长期、自主、可恢复的研究进化机制
- 文件化状态管理 + wiki + meta 日志带来的长周期可恢复性
- 执行者与 reviewer 分离、并在僵局时切换到协作模式的跨模型反馈闭环
- 三工具 reviewer 架构带来的结构化评分、强制审查和深度诊断能力

理解了这三点，整个仓库的脉络就基本清楚了。
