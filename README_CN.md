# Auto-claude-code-research-in-sleep (ARIS)

![ARIS Logo](docs/aris_logo.svg)

![Hero](docs/hero_combined.svg)

[English](README.md) | 中文版

> 本文档是 ARIS 当前的中文主手册。
>
> 当前仓库主线已经切到：**Codex 负责执行**，**Claude Code CLI 负责审稿**，两者通过本地 `claude-review` MCP bridge 连接。
>
> 如果你现在第一次接触这个项目，先看这份 README；如果你需要领域化落地示例，再看 [`docs/INERTIAL_ODOMETRY_GUIDE_CN.md`](docs/INERTIAL_ODOMETRY_GUIDE_CN.md)。

---

## 目录

1. [项目定位](#1-项目定位)
2. [当前主线路径](#2-当前主线路径)
3. [环境准备](#3-环境准备)
4. [安装验证重装与卸载](#4-安装验证重装与卸载)
5. [项目初始化](#5-项目初始化)
6. [ARIS 工作流总览](#6-aris-工作流总览)
7. [阶段一Idea Discovery](#7-阶段一idea-discovery)
8. [阶段二Method Refinement 与 Experiment Plan](#8-阶段二method-refinement-与-experiment-plan)
9. [阶段三Experiment Bridge 与 GPU 执行](#9-阶段三experiment-bridge-与-gpu-执行)
10. [阶段四Auto Review Loop 与 Deep Innovation Loop](#10-阶段四auto-review-loop-与-deep-innovation-loop)
11. [阶段五Paper Writing](#11-阶段五paper-writing)
12. [阶段六Rebuttal Slides Poster](#12-阶段六rebuttal-slides-poster)
13. [一键全流程与常用命令速查](#13-一键全流程与常用命令速查)
14. [会话恢复与 Pipeline Status](#14-会话恢复与-pipeline-status)
15. [可选集成与高级能力](#15-可选集成与高级能力)
16. [关键文件与输出物](#16-关键文件与输出物)
17. [常见问题](#17-常见问题)
18. [领域示例与非主线内容](#18-领域示例与非主线内容)

---

## 1. 项目定位

ARIS 不是一个 Web 平台，也不是一个必须绑定某个模型厂商的框架。它更接近一个**科研工作流 harness**：

- 用一组 `SKILL.md` 把科研流程拆成可复用阶段
- 用 Codex 处理代码、实验、文件修改和执行
- 用独立审稿器对结果做外部审查，而不是让执行器自我博弈
- 用纯 Markdown 工件保留过程状态，便于跨会话恢复

当前仓库主线的默认分工是：

- **执行器**：Codex CLI
- **审稿器**：Claude Code CLI
- **桥接层**：本地 `claude-review` MCP server

这条主线的目标不是“给你一句万能 prompt”，而是把下面这些动作串成一条可复用的流水线：

1. 找方向
2. 做文献调研
3. 生成并筛选 idea
4. 精炼方法与实验计划
5. 实现代码并部署实验
6. 自动审稿并修复
7. 写论文
8. 做 rebuttal / slides / poster

---

## 2. 当前主线路径

主线路径由三部分组成：

- 基础执行技能包：[`skills/skills-codex/`](skills/skills-codex/)
- Claude 审稿覆盖层：[`skills/skills-codex-claude-review/`](skills/skills-codex-claude-review/)
- 审稿 bridge：[`mcp-servers/claude-review/`](mcp-servers/claude-review/)

安装顺序固定为：

1. 先安装 `skills/skills-codex/*`
2. 再叠加 `skills/skills-codex-claude-review/*`
3. 最后注册 `claude-review` MCP

仓库已经提供一键安装器：

- 安装脚本：[`scripts/install_codex_claude_mainline.sh`](scripts/install_codex_claude_mainline.sh)
- 卸载脚本：[`scripts/uninstall_codex_claude_mainline.sh`](scripts/uninstall_codex_claude_mainline.sh)
- 冒烟测试：[`scripts/smoke_test_codex_claude_mainline.sh`](scripts/smoke_test_codex_claude_mainline.sh)

主线架构说明文档见：

- [`docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md`](docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md)

关于 `deep-innovation-loop`，当前事实需要明确：

- 它**已经在 Codex 主线技能包中**
- 安装主线后会一起安装
- 它**是可用工作流**
- 它现在已经**进入 `/research-pipeline` 默认主线**
- 当前默认行为是 `DEEP_INNOVATION: auto`
- 也就是说，主线会在初始实验后自动做一次“是否进入深度方法进化”的判断
- 你仍然可以用 `DEEP_INNOVATION: true` 强制进入，或用 `DEEP_INNOVATION: false` 显式跳过

---

## 3. 环境准备

### 3.1 必需软件

建议先确认本机具备：

- `git`
- `node` / `npm`
- `python3`
- `codex`
- `claude`

安装 Codex 与 Claude Code CLI：

```bash
npm install -g @openai/codex @anthropic-ai/claude-code
codex setup
```

验证：

```bash
codex --version
claude --version
python3 --version
```

### 3.2 Claude CLI 登录态

主线安装只负责把技能包和 MCP bridge 放到位，不负责替你完成 Claude CLI 的登录。你需要先确保本机 Claude CLI 可用，然后再安装 ARIS 主线。

推荐在安装前先做一次最小检查：

```bash
claude -p "Reply with exactly READY" --output-format json --tools ""
```

如果这条命令不能返回 `READY`，先修复 Claude CLI 登录态，再继续。

### 3.3 远程实验的常见前置条件

如果你计划让 ARIS 自动跑实验，通常还需要：

- 可用 GPU
- SSH 连接
- 远程 Python/conda 环境
- `screen` 或 `tmux`

这些不是安装 ARIS 的硬前提，但会影响 `/run-experiment`、`/monitor-experiment`、`/experiment-bridge` 的执行质量。

---

## 4. 安装验证重装与卸载

### 4.1 首次安装

```bash
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git
cd Auto-claude-code-research-in-sleep
bash scripts/install_codex_claude_mainline.sh
```

安装器会完成这些事情：

- 拷贝 `skills/skills-codex/*` 到 `~/.codex/skills/`
- 叠加 `skills/skills-codex-claude-review/*`
- 安装 `mcp-servers/claude-review/server.py`
- 注册 `claude-review` MCP
- 写入安装状态清单
- 复制一份本地可执行的卸载脚本到 `~/.codex/.aris/codex-claude-mainline/`

### 4.2 安装后验证

先检查 MCP：

```bash
codex mcp list
codex mcp get claude-review --json
```

再检查 Claude CLI：

```bash
claude -p "Reply with exactly READY" --output-format json --tools ""
```

然后进入你的项目目录启动 Codex：

```bash
codex -C /path/to/your/project
```

如果安装成功，你应该能在 Codex 中使用诸如：

- `/idea-discovery`
- `/experiment-bridge`
- `/auto-review-loop`
- `/paper-writing`
- `/rebuttal`
- `/deep-innovation-loop`

### 4.3 固定审稿模型

如果你希望固定 Claude 审稿模型：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --review-model claude-opus-4-1
```

### 4.4 使用 AWS wrapper

如果你的 Claude CLI 依赖 wrapper：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --use-aws-wrapper
```

### 4.5 重装

安装器默认拒绝覆盖已有主线安装。需要显式带上 `--reinstall`：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

### 4.6 卸载

主线安装完成后，卸载优先使用写入到本地状态目录的脚本：

```bash
bash ~/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh
```

这个卸载脚本会：

- 删除安装器注册的 `claude-review` MCP
- 回滚安装器接管过的文件
- 恢复安装前备份的旧文件
- 清理 `~/.codex/.aris/codex-claude-mainline/` 状态目录

也就是说，它不是简单粗暴地删整个 `~/.codex/skills`，而是按安装 manifest 做精确回滚。

### 4.7 维护者冒烟测试

如果你在修改安装器、overlay 或 bridge，建议运行：

```bash
bash scripts/smoke_test_codex_claude_mainline.sh
```

这个脚本会在隔离的 `HOME` 下验证：

- 安装成功
- `deep-innovation-loop` 等关键技能已落盘
- MCP 注册成功
- 重装逻辑正常
- 本地卸载脚本可用
- 卸载后能恢复旧文件

---

## 5. 项目初始化

### 5.1 创建研究项目

```bash
mkdir ~/my-research-project
cd ~/my-research-project
git init
codex -C .
```

### 5.2 使用 `CODEX.md` 作为项目主配置

当前 Codex 主线使用项目根目录的 `CODEX.md` 作为唯一主配置文件。

一个最小可用模板如下：

```markdown
# Project Overview

## Research Direction
- Topic: 你的研究方向
- Target venue: ICLR / ICML / NeurIPS / CVPR / ACL / AAAI / IEEE_JOURNAL / IEEE_CONF
- Main baseline: 你的主基线

## GPU Configuration
- gpu: local

## Notes
- Key metrics: 你关心的指标
- Constraints: 计算预算、数据限制、上线约束

## Pipeline Status
stage: init
idea: ""
contract: docs/research_contract.md
current_branch: main
baseline: ""
training_status: idle
active_tasks: []
next: run /idea-discovery

## State Persistence Rules
- Update Pipeline Status on stage changes, major decisions, experiment start/end, and before session handoff.
- On session recovery, read Pipeline Status first, then docs/research_contract.md, then recent logs.
```

如果你要配置远程 GPU，可以把 `## GPU Configuration` 写得更具体，例如：

```markdown
## GPU Configuration
- gpu: remote
- ssh_alias: my-server
- conda_env: research
- code_dir: ~/my-research-project
```

### 5.3 编写 `RESEARCH_BRIEF.md`

`RESEARCH_BRIEF.md` 适合放项目背景、已有认知、限制条件和目标。很多工作流会自动把它当作研究上下文。

建议最少包含：

- 研究问题
- 当前痛点
- 已知基线
- 数据与资源
- 你已经做过的尝试
- 明确不做什么

模板可参考：

- [`templates/RESEARCH_BRIEF_TEMPLATE.md`](templates/RESEARCH_BRIEF_TEMPLATE.md)

### 5.4 选定 idea 之后的 `research_contract`

当你完成 `/idea-discovery`，真正进入实现阶段后，建议把当前选中的 idea 收敛到：

- `docs/research_contract.md`

模板见：

- [`templates/RESEARCH_CONTRACT_TEMPLATE.md`](templates/RESEARCH_CONTRACT_TEMPLATE.md)

这份文件的作用是让新会话不必重新阅读整份 `IDEA_REPORT.md`，而是直接回到“当前正在做的那个 idea”。

### 5.5 推荐目录

不是硬性要求，但实践中下面这个结构最顺手：

```text
project/
├── CODEX.md
├── RESEARCH_BRIEF.md
├── docs/
│   └── research_contract.md
├── papers/
├── literature/
├── src/
├── scripts/
├── results/
├── paper/
└── rebuttal/
```

---

## 6. ARIS 工作流总览

当前主线最推荐的实际使用路径是**模块化串联**，而不是一上来把所有事情都塞给一条总命令。

### 6.1 推荐主流程

1. `/idea-discovery`
2. `/experiment-bridge`
3. `/deep-innovation-loop` 或主线自动进入的创新阶段
4. `/auto-review-loop`
5. `/paper-writing`
6. `/rebuttal` / `/paper-slides` / `/paper-poster`

### 6.2 一键路径

如果你想先跑一条主干全流程，可以使用：

```text
/research-pipeline "你的研究方向"
```

当前这条技能的实际主链路是：

```text
/idea-discovery -> implementation -> /run-experiment -> innovation gate -> /deep-innovation-loop? -> /auto-review-loop
```

也就是说：

- 它覆盖了从找 idea 到实现、部署、深度方法进化判断、最终自动审稿抛光
- `DEEP_INNOVATION: auto` 会决定是否自动进入 `/deep-innovation-loop`
- `DEEP_INNOVATION: true` 会强制进入深度创新
- `DEEP_INNOVATION: false` 会跳过深度创新，直接进 `/auto-review-loop`
- 论文写作和 rebuttal 也仍然建议显式调用后续工作流

### 6.3 各阶段对应关系

| 阶段 | 推荐命令 | 主要输出 |
|------|----------|----------|
| 方向探索 | `/research-lit` | 文献表、领域综述 |
| Idea 发现 | `/idea-discovery` | `IDEA_REPORT.md`、`refine-logs/*` |
| 方法精炼 | `/research-refine-pipeline` | `FINAL_PROPOSAL.md`、`EXPERIMENT_PLAN.md` |
| 实验落地 | `/experiment-bridge` | 代码、初始实验、`EXPERIMENT_TRACKER.md` |
| 自动审稿 | `/auto-review-loop` | `AUTO_REVIEW.md`、`REVIEW_STATE.json` |
| 深度创新 | `/deep-innovation-loop` | `innovation-logs/*`、`FINAL_METHOD.md` |
| 写论文 | `/paper-writing` | `paper/`、PDF、改稿日志 |
| 投稿后回应 | `/rebuttal` | `rebuttal/` |
| 展示材料 | `/paper-slides`、`/paper-poster` | 幻灯片、海报、演讲材料 |

---

## 7. 阶段一Idea Discovery

`/idea-discovery` 是当前主线中最完整的“从方向到可执行方案”入口。

它内部会串起来：

```text
/research-lit -> /idea-creator -> /novelty-check -> /research-review -> /research-refine-pipeline
```

### 7.1 典型调用

```text
/idea-discovery "离散扩散语言模型中的 factorized gap"
```

如果你不想在筛选 idea 时自动继续：

```text
/idea-discovery "你的方向" — AUTO_PROCEED: false
```

如果你有参考论文：

```text
/idea-discovery "你的方向" — ref paper: https://arxiv.org/abs/2406.04329
```

### 7.2 当前主线下最实用的参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `AUTO_PROCEED` | `true` | 是否在 checkpoint 无响应时自动继续 |
| `sources` | `all` | `research-lit` 文献源选择：`zotero`、`obsidian`、`local`、`web`、`all` |
| `arxiv download` | `false` | 是否下载最相关 arXiv PDF |
| `ref paper` | `false` | 指定参考论文 |
| `compact` | `false` | 是否生成 `IDEA_CANDIDATES.md` 等压缩工件 |

要点有两个：

1. 当前 Codex 主线里的 `research-lit`，`sources:` 可选值是 `zotero`、`obsidian`、`local`、`web`、`all`
2. `semantic-scholar` 当前更适合作为**单独技能**使用，而不是写成 `research-lit` 的 `sources:` 选项

如果你需要补充正式出版物检索，可以额外调用：

```text
/semantic-scholar "你的主题"
```

### 7.3 阶段一输出物

`/idea-discovery` 跑完后，最重要的不是一句总结，而是这些落盘文件：

- `IDEA_REPORT.md`
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

在真实项目里，这四个文件通常就足够把你带进实现阶段。

---

## 8. 阶段二Method Refinement 与 Experiment Plan

如果你已经有一个基本想法，但还没有把方法和实验设计压实，建议显式跑：

```text
/research-refine-pipeline "你的 idea 描述"
```

它会把模糊想法压成三个关键工件：

- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

### 8.1 这一步要解决什么问题

不是“多想几个花活”，而是明确：

- 问题锚点到底是什么
- 主要贡献是方法、诊断、还是实验发现
- 哪些实验是 must-run
- 哪些对比和消融是必要的
- 预算是否合理

### 8.2 常见搭配

当主结果开始出来以后，常用的补充技能是：

- `/ablation-planner`
- `/training-check`
- `/result-to-claim`

一个典型组合是：

```text
/research-refine-pipeline "你的 idea"
/experiment-bridge
/result-to-claim
```

---

## 9. 阶段三Experiment Bridge 与 GPU 执行

`/experiment-bridge` 是当前仓库里最适合把“计划”落成“实验代码 + 初始结果”的桥接层。

### 9.1 推荐输入

优先级最高的是：

1. `refine-logs/EXPERIMENT_PLAN.md`
2. `refine-logs/EXPERIMENT_TRACKER.md`
3. `refine-logs/FINAL_PROPOSAL.md`

### 9.2 典型调用

```text
/experiment-bridge "refine-logs/EXPERIMENT_PLAN.md"
```

如果你要基于外部 repo 开发：

```text
/experiment-bridge "refine-logs/EXPERIMENT_PLAN.md" — base repo: https://github.com/org/project
```

### 9.3 这一步会做什么

- 解析实验计划
- 扫描现有代码库
- 实现缺失的训练/评估脚本
- 先做 sanity-stage 试跑
- 调用 `/run-experiment` 部署实验
- 调用 `/monitor-experiment` 监控实验
- 更新 `refine-logs/EXPERIMENT_TRACKER.md`

### 9.4 远程 GPU 的最小配置思路

ARIS 不强行规定你只能用哪种 GPU 来源。主线里常见的是：

- 本地 GPU
- SSH 到远程服务器
- Vast 等临时算力

你至少要在 `CODEX.md` 里把“代码在哪、环境叫什么、GPU 怎么连”写清楚，否则执行器只能靠猜。

### 9.5 W&B 是可选的

如果你想让训练质量检查更可靠，可以在 `CODEX.md` 写：

```markdown
- wandb: true
- wandb_project: your-project-name
```

然后让 `/training-check` 在实验完成后读取训练曲线。

---

## 10. 阶段四Auto Review Loop 与 Deep Innovation Loop

这两个技能都重要，但职责不同。

### 10.1 `/auto-review-loop` 解决什么

它适合下面这类问题：

- 结果已经有了，但叙事还不够稳
- 缺指标、缺消融、缺解释
- reviewer 会卡你哪些点，还需要几轮修补
- 想让系统自主做 1 到 4 轮 review -> fix -> re-review

典型调用：

```text
/auto-review-loop "你的论文主题"
```

如果你希望每轮 review 后手动介入：

```text
/auto-review-loop "你的论文主题" — human checkpoint: true
```

核心输出：

- `AUTO_REVIEW.md`
- `REVIEW_STATE.json`
- `CLAIMS_FROM_RESULTS.md`（如果结果可转成 claim）

### 10.2 `/deep-innovation-loop` 解决什么

它适合的是“方法本身已经碰到结构性瓶颈”，而不只是缺几个实验或缺几段解释。

你应该在这些情况下考虑它：

- 分数多轮卡住不动
- 主要问题是根因没找对
- 当前方法需要真正演化，而不是继续缝补
- 你想让系统在 `innovation-logs/` 下持续积累技术库和失败库

典型调用：

```text
/deep-innovation-loop "你的方法描述" — baseline: 你的主基线, venue: ICML, domain: ml
```

关键点再强调一次：

- `deep-innovation-loop` 已安装、可用、在主线路径里
- 当前 `/research-pipeline` 默认会以 `DEEP_INNOVATION: auto` 把它作为方法进化阶段接入
- 如果你明确知道项目需要长周期方法演化，可以直接在主线里指定 `DEEP_INNOVATION: true`
- 如果你只想做快速 review-polish，也可以用 `DEEP_INNOVATION: false` 跳过它

### 10.3 两者如何配合

一个常见顺序是：

```text
/experiment-bridge
/deep-innovation-loop "当前方法" — baseline: xxx, venue: xxx, domain: xxx
/auto-review-loop "创新后方法"
```

前者负责“方法式进化”，后者负责“论文级抛光与审稿式修补”。

---

## 11. 阶段五Paper Writing

`/paper-writing` 是论文写作总工作流，适合在实验和叙事已经相对稳定后使用。

它内部主链路是：

```text
/paper-plan -> /paper-figure -> /paper-write -> /paper-compile -> /auto-paper-improvement-loop
```

### 11.1 推荐输入

最好是：

- `NARRATIVE_REPORT.md`

模板见：

- [`templates/NARRATIVE_REPORT_TEMPLATE.md`](templates/NARRATIVE_REPORT_TEMPLATE.md)

### 11.2 典型调用

```text
/paper-writing "NARRATIVE_REPORT.md" — venue: ICML
```

如果你是 IEEE 方向：

```text
/paper-writing "NARRATIVE_REPORT.md" — venue: IEEE_JOURNAL
```

### 11.3 阶段五输出

- `PAPER_PLAN.md`
- `paper/`
- 编译后的 PDF
- 自动改稿日志

如果你已经有计划或 LaTeX 草稿，也可以分阶段调用：

- `/paper-plan`
- `/paper-figure`
- `/paper-write`
- `/paper-compile`

### 11.4 关于 AI 插图

仓库中有 `/paper-illustration`，可以作为补充能力使用。但它不是论文主线成功的前提，先保证论点、实验和图表成立，再考虑 AI 插图。

---

## 12. 阶段六Rebuttal Slides Poster

### 12.1 `/rebuttal`

投稿后收到 review，可以进入：

```text
/rebuttal "paper/ + reviews" — venue: ICML, character limit: 5000
```

这条工作流的重点是：

- 解析 review
- 原子化 issue
- 建立回应策略
- 生成 grounded 的 rebuttal 草稿
- 做安全检查
- 生成 `PASTE_READY.txt`

如果你希望它为了 rebuttal 自动补实验：

```text
/rebuttal "paper/ + reviews" — venue: ICML, character limit: 5000, auto experiment: true
```

### 12.2 `/paper-slides` 与 `/paper-poster`

论文录用后，展示材料可以继续沿用 ARIS：

```text
/paper-slides "paper/"
/paper-poster "paper/"
```

这两条工作流适合在最终论文定稿后使用，不建议提前过早投入。

---

## 13. 一键全流程与常用命令速查

### 13.1 最常用命令

```text
/research-lit "你的主题"
/idea-discovery "你的主题"
/research-refine-pipeline "你的 idea"
/experiment-bridge "refine-logs/EXPERIMENT_PLAN.md"
/run-experiment "python train.py ..."
/monitor-experiment "server-name"
/deep-innovation-loop "你的方法" — baseline: xxx, venue: xxx, domain: xxx
/auto-review-loop "你的论文主题"
/paper-writing "NARRATIVE_REPORT.md" — venue: ICML
/rebuttal "paper/ + reviews" — venue: ICML, character limit: 5000
/paper-slides "paper/"
/paper-poster "paper/"
```

### 13.2 一键全流程入口

```text
/research-pipeline "你的研究方向"
```

适合这些情况：

- 你想先跑一条主线验证整个项目能不能动起来
- 你接受从 idea 到初轮自动审稿的自动串联
- 你后续愿意再手动进入 `/deep-innovation-loop`、`/paper-writing`、`/rebuttal`

### 13.3 Research Wiki 速查

如果你想长期积累某一方向的知识图谱：

```text
/research-wiki init
/research-wiki ingest "paper title"
/research-wiki query "topic"
/research-wiki update paper:xxx — relevance: core
/research-wiki lint
/research-wiki stats
```

---

## 14. 会话恢复与 Pipeline Status

ARIS 的长流程一定会遇到两个问题：

1. 上下文压缩
2. 新会话接力

当前主线最重要的恢复约定是：

- 在项目根目录维护 `CODEX.md`
- 在 `CODEX.md` 里维护 `## Pipeline Status`

推荐配合阅读：

- [`docs/SESSION_RECOVERY_GUIDE_CN.md`](docs/SESSION_RECOVERY_GUIDE_CN.md)

### 14.1 建议写法

```yaml
## Pipeline Status
stage: training
idea: "一句话说明当前 idea"
contract: docs/research_contract.md
current_branch: feature/current-idea
baseline: "baseline metric = 0.82"
training_status: running on server-a, gpu 0-3, tmux=train01
active_tasks:
  - "exp01 on server-a"
next: wait for results and run /auto-review-loop
```

### 14.2 什么时候更新

至少在这些时刻更新：

- 阶段切换
- 选定 idea
- 启动或结束训练
- 做出关键方法决策
- 你准备切会话、压缩上下文、收工之前

### 14.3 已有状态文件

除了 `CODEX.md`，这些文件也会帮助恢复：

- `REVIEW_STATE.json`
- `AUTO_REVIEW.md`
- `innovation-logs/INNOVATION_STATE.json`
- `innovation-logs/EVOLUTION_LOG.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

但是它们不能替代 `Pipeline Status`。前者是阶段内状态，后者是项目级索引。

---

## 15. 可选集成与高级能力

### 15.1 飞书通知

Codex 主线路径下，飞书配置文件是：

```text
~/.codex/feishu.json
```

最小示例：

```json
{
  "mode": "push",
  "webhook_url": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_WEBHOOK_ID"
}
```

模式：

- `off`
- `push`
- `interactive`

如果这个文件不存在，飞书功能自动关闭，不影响任何主工作流。

### 15.2 Zotero 与 Obsidian

`/research-lit` 当前支持：

- `zotero`
- `obsidian`
- `local`
- `web`
- `all`

这些集成通过 Codex MCP 使用。也就是说，你需要先按自己的实现方式注册对应 MCP，再让 `/research-lit` 去调用它们。

形式上类似：

```bash
codex mcp add zotero -- <your-zotero-mcp-command>
codex mcp add obsidian-vault -- <your-obsidian-mcp-command>
```

这里故意不写死具体实现，因为不同用户选用的 Zotero/Obsidian MCP 发行版、启动命令和参数都可能不同。

### 15.3 Semantic Scholar

当前主线里，`semantic-scholar` 作为**独立技能**保留：

```text
/semantic-scholar "你的主题"
```

更适合在这些场景下使用：

- 想补 arXiv 之外的正式发表论文
- 想做查新补强
- 想对某个具体 idea 做更严格的近邻工作排查

### 15.4 Research Wiki

如果你的项目会持续几周到几个月，建议把 `research-wiki/` 建起来。它对于避免重复踩坑非常有帮助，尤其是在长周期项目里。

把它嵌进主线的推荐方式是：

1. 在 `CODEX.md` 和 `RESEARCH_BRIEF.md` 稳定后，先执行一次：
   ```text
   /research-wiki init
   ```
2. 然后让 `/research-lit` 自动把核心论文写进 `research-wiki/papers/`
3. 让 `/idea-creator` 在 ideation 前读取 `query_pack.md`，在 ideation 后把推荐与淘汰的 idea 都写回 wiki
4. 让 `/result-to-claim` 在结果判定后把 experiment / claim / failure notes 回写 wiki
5. 在长会话切换、准备重新找 idea 或做阶段复盘时，手动使用：
   ```text
   /research-wiki query "你的主题"
   /research-wiki stats
   /research-wiki lint
   ```

简单理解：Research Wiki 不是额外的笔记本，而是主线工作流的**长期研究记忆层**。

### 15.5 Meta Optimize

`/meta-optimize` 现在更适合被理解为**主线之后的维护环**，而不是研究执行阶段里的必经步骤。

它的推荐嵌入方式是：

1. 先让主线工作流真正跑出工件：
   - `AUTO_REVIEW.md`
   - `innovation-logs/`
   - `refine-logs/`
   - `findings.md`
   - `paper/`
   - `rebuttal/`
2. 然后在阶段边界运行：
   ```text
   /meta-optimize "research-pipeline"
   /meta-optimize "auto-review-loop"
   /meta-optimize "deep-innovation-loop"
   /meta-optimize "paper-writing"
   ```
3. 它会优先分析这些实际工件；如果你另外配置了 `.aris/meta/events.jsonl`，它也会把事件日志一起作为增强证据
4. 只有在你明确执行 `apply` 时，才应该让它改 harness；不要在主研究流程中自动应用优化补丁

如果你只是第一次跑通 ARIS 主线，可以先不启用它；如果你已经开始进入第二个、第三个项目，它就开始有价值了。

---

## 16. 关键文件与输出物

| 文件或目录 | 作用 |
|------------|------|
| `CODEX.md` | 项目主配置与 `Pipeline Status` |
| `RESEARCH_BRIEF.md` | 研究背景、目标、限制、资源 |
| `IDEA_REPORT.md` | 阶段一 idea 总报告 |
| `IDEA_CANDIDATES.md` | compact 模式的 idea 摘要 |
| `refine-logs/FINAL_PROPOSAL.md` | 固化后的方法提案 |
| `refine-logs/EXPERIMENT_PLAN.md` | 结构化实验路线图 |
| `refine-logs/EXPERIMENT_TRACKER.md` | 实验执行与状态跟踪 |
| `AUTO_REVIEW.md` | 自动审稿完整日志 |
| `REVIEW_STATE.json` | 自动审稿恢复状态 |
| `CLAIMS_FROM_RESULTS.md` | 从结果萃取出的论文声明 |
| `innovation-logs/` | 深度创新循环的状态、技术库与轮次记录 |
| `paper/` | 论文 LaTeX 与编译产物 |
| `rebuttal/` | rebuttal 各阶段工件 |
| `research-wiki/` | 研究知识图谱 |

把这些文件看清楚，比记住一堆口号更重要。

---

## 17. 常见问题

### 17.1 我应该写哪个项目配置文件？

主线路径下直接写 `CODEX.md`。当前 Codex 主线只读取 `CODEX.md` 作为项目配置入口。

### 17.2 安装成功了，但看不到技能

先查三件事：

1. `~/.codex/skills/` 下是否有对应目录
2. `codex mcp get claude-review --json` 是否正常
3. 是否曾有旧的 ARIS / 旧 MCP 配置干扰

必要时执行：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

### 17.3 `deep-innovation-loop` 在不在主线里？

在。安装主线就会一起安装，也已经进入当前 `/research-pipeline` 的默认主线；默认行为是 `DEEP_INNOVATION: auto`，你也可以手动强制开启或关闭。

### 17.4 没有 Zotero 或 Obsidian MCP 可以用吗？

可以。`/research-lit` 会回退到本地 PDF 和 Web 搜索，不会因为缺少这些 MCP 直接失效。

### 17.5 不想全自动，能半自动吗？

可以。很多工作流都有：

- `AUTO_PROCEED: false`
- `human checkpoint: true`

你可以只把最费时间的阶段交给 ARIS，把关键决策点保留给自己。

### 17.6 怎么彻底卸载？

用安装器复制到本地状态目录的脚本：

```bash
bash ~/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh
```

### 17.7 README 里的一键总流程是否等于全部能力都自动接好了？

不是。当前一键总流程已经把深度创新阶段以 `DEEP_INNOVATION: auto` 方式接入，但论文写作、rebuttal、slides、poster 仍建议显式进入各自工作流。

---

## 18. 领域示例与非主线内容

### 18.1 领域化示例

如果你想看“把 ARIS 真的落到某个具体研究方向”会是什么写法，优先看：

- [`docs/INERTIAL_ODOMETRY_GUIDE_CN.md`](docs/INERTIAL_ODOMETRY_GUIDE_CN.md)

那份文档展示的是如何把这套主线工作流压到“纯惯性里程计”这个具体场景。

### 18.2 更多项目文档

- [`docs/PROJECT_ARCHITECTURE_GUIDE_CN.md`](docs/PROJECT_ARCHITECTURE_GUIDE_CN.md)
- [`docs/PROJECT_FILES_GUIDE_CN.md`](docs/PROJECT_FILES_GUIDE_CN.md)
- [`docs/SESSION_RECOVERY_GUIDE_CN.md`](docs/SESSION_RECOVERY_GUIDE_CN.md)
- [`docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md`](docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md)

<details>
<summary>替代模型组合与其他入口</summary>

当前仓库仍保留一些非默认主线文档，适合有明确需求时再看：

- Codex + Gemini 审稿：[`docs/CODEX_GEMINI_REVIEW_GUIDE_CN.md`](docs/CODEX_GEMINI_REVIEW_GUIDE_CN.md)
- Cursor 适配：[`docs/CURSOR_ADAPTATION.md`](docs/CURSOR_ADAPTATION.md)
- Trae 适配：[`docs/TRAE_ARIS_RUNBOOK_CN.md`](docs/TRAE_ARIS_RUNBOOK_CN.md)
- Antigravity 适配：[`docs/ANTIGRAVITY_ADAPTATION_CN.md`](docs/ANTIGRAVITY_ADAPTATION_CN.md)
- OpenClaw 适配：[`docs/OPENCLAW_ADAPTATION.md`](docs/OPENCLAW_ADAPTATION.md)
- 其他 API 混搭：[`docs/LLM_API_MIX_MATCH_GUIDE.md`](docs/LLM_API_MIX_MATCH_GUIDE.md)

如果你只是想把当前项目稳定跑起来，不要从这些分支入口开始，先把 Codex + Claude 主线跑通。

</details>

<details>
<summary>社区贡献与扩展技能</summary>

仓库中还保留了很多可独立使用的技能，例如：

- `grant-proposal`
- `paper-slides`
- `paper-poster`
- `proof-writer`
- `formula-derivation`
- `comm-lit-review`
- `dse-loop`

它们不是这份 README 主线叙事的重点，但都可以在合适阶段直接调用。

</details>

<details>
<summary>社区案例、引用与协议</summary>

社区中已经有使用 ARIS 完成从 idea 到投稿甚至接收的真实案例。更详细的展示、截图和背景信息可以按需回看旧版英文 README 或相关 issue / PR 讨论。

如果这个项目对你的研究有帮助，可以引用：

```bibtex
@misc{yang2026aris,
    author       = {Yang, Ruofeng and Li, Yongcan and Li, Shuai},
    title        = {ARIS: Fully Autonomous Research via Adversarial Multi-Agent Collaboration},
    year         = {2026},
    organization = {GitHub},
    url          = {https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep}
}
```

仓库许可证为 `MIT`。

</details>

---

## 最后建议

第一次上手时，不要试图一次吃掉全部能力。最稳妥的落地顺序是：

1. 安装主线并验证
2. 用一个小项目写好 `CODEX.md` 和 `RESEARCH_BRIEF.md`
3. 如果项目是长周期，先执行一次 `/research-wiki init`
4. 跑 `/idea-discovery`
5. 跑 `/experiment-bridge`
6. 让 `/research-pipeline` 或主线创新阶段自动判断是否进入 `/deep-innovation-loop`
7. 结果稳定后，再进 `/paper-writing` 与 `/rebuttal`
8. 有了完整工件之后，再用 `/meta-optimize` 做维护优化

这样最符合当前仓库的真实状态，也最不容易被旧文档或旧路径带偏。
