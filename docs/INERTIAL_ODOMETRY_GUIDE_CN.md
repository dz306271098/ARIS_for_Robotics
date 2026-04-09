# ARIS 使用指南：纯惯性里程计研究

> 面向纯惯性里程计（Inertial Odometry）领域，以 AIR-IO 为主基线，目标期刊 IEEE RAL。
> 执行模型：Claude Opus 4.6（执行器）+ GPT-5.4（审查器，通过三工具架构交互）
> 交互通道：`codex exec`（结构化评分/多轮对话/图片审查）+ `/codex:adversarial-review`（代码审查）+ `/codex:rescue`（深度调查/协作）
> 运行模式：**完全自主，无需人工干预**

---

## 目录

1. [环境准备](#1-环境准备)
2. [项目初始化](#2-项目初始化)
3. [ARIS 工作流总览](#3-aris-工作流总览)
4. [全自主决策机制](#4-全自主决策机制)
5. [阶段一：创意发现](#5-阶段一创意发现)
6. [阶段二：方法精炼](#6-阶段二方法精炼)
7. [阶段三：实验实现与部署](#7-阶段三实验实现与部署)
8. [阶段四：深度创新循环（核心）](#8-阶段四深度创新循环核心)
9. [阶段五：论文写作](#9-阶段五论文写作)
10. [一键全流程](#10-一键全流程)
11. [常用命令速查表](#11-常用命令速查表)
12. [会话恢复与中断处理](#12-会话恢复与中断处理)
13. [GPU 与实验管理](#13-gpu-与实验管理)
14. [Web 韧性与防卡死机制](#14-web-韧性与防卡死机制)
15. [三工具架构与强制审查](#15-三工具架构与强制审查)
16. [失败深度分析机制](#16-失败深度分析机制)
17. [研究知识图谱 (Research Wiki)](#17-研究知识图谱-research-wiki)
18. [自我优化 (Meta-Optimize)](#18-自我优化-meta-optimize)
19. [常见问题](#19-常见问题)

---

## 1. 环境准备

### 1.1 安装 Claude Code

```bash
# 方式一：npm 安装
npm install -g @anthropic-ai/claude-code

# 方式二：已安装则确认版本
claude --version
```

### 1.2 安装 ARIS 技能

```bash
# 克隆 ARIS 仓库（如果尚未克隆）
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git

# 将所有技能安装到 Claude Code
cp -r Auto-claude-code-research-in-sleep/skills/* ~/.claude/skills/
```

验证安装：在 Claude Code 中输入 `/` 后应能看到所有 ARIS 技能（如 `/research-pipeline`、`/deep-innovation-loop` 等）。

### 1.3 配置 Codex CLI + Codex Plugin（GPT-5.4 三工具架构）

ARIS 使用三种方式与 GPT-5.4 交互，全部基于 Codex CLI：

```bash
sudo apt update
sudo apt install -y curl git build-essential

# 安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# 让当前 shell 立即生效
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 安装 Node LTS 主线
nvm install 24
nvm use 24

# 验证
node -v
npm -v

# 安装 Codex CLI
npm i -g @openai/codex

# 验证
codex --version

# 配置 Codex（设置模型为 gpt-5.4）
codex setup
# 在弹出的配置中选择 gpt-5.4 模型
```

验证 Codex CLI：
```bash
codex exec --sandbox read-only --ephemeral "Say hello and list the top 3 files in this directory."
```

验证 Codex Plugin（安装后自动可用）：
```
/codex:setup
```

ARIS 使用三种 Codex 通道（GPT-5.4 在所有通道中都能直接读取项目文件）：

| 通道 | 用途 | 调用方式 |
|------|------|---------|
| `codex exec --output-schema` | 结构化评分（5维度 JSON）、多轮对话、图片审查 | Bash 命令 |
| `/codex:adversarial-review` | 代码审查（读 git diff，结构化 findings） | Skill 命令 |
| `/codex:rescue --effort xhigh` | 深度调查、失败诊断、协作问题解决 | Skill 命令 |

### 1.4 可选配置

#### 飞书通知（手机接收实验进度）

创建 `~/.claude/feishu.json`：
```json
{
  "mode": "push",
  "webhook_url": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_WEBHOOK"
}
```
模式：`off`（关闭）、`push`（仅推送）、`interactive`（交互审批）

#### W&B 训练监控

在你的项目 `CLAUDE.md` 中添加：
```markdown
- wandb: true
- wandb_project: inertial-odometry
```

---

## 2. 项目初始化

### 2.1 创建研究项目

```bash
mkdir ~/io-research && cd ~/io-research
git init
```

### 2.2 编写 CLAUDE.md

在项目根目录创建 `CLAUDE.md`，这是 ARIS 读取项目配置的核心文件：

```markdown
# Inertial Odometry Research Project

## Research Direction
Pure inertial odometry using deep learning, targeting IEEE RAL.
Primary baseline: AIR-IO

## GPU Configuration
- gpu: local
  (或 gpu: remote, ssh_alias: your-server, conda_env: io-env, code_dir: ~/io-research)
  (或 gpu: vast, auto_destroy: true, max_budget: 10.00)

## Project Notes
- Target venue: RAL (IEEE Robotics and Automation Letters)
- Primary baseline: AIR-IO
- Key metrics: ATE, RTE, heading drift
- Datasets: RIDI, OxIOD, RoNIN

## Dependencies
- Python 3.10+
- PyTorch 2.0+
- numpy, scipy, matplotlib
```

### 2.3 编写研究简报（推荐）

创建 `RESEARCH_BRIEF.md`，提供详细的研究背景。这个文件非常重要——它是 ARIS 自主决策的核心上下文来源。ARIS 会自动检测并加载：

```markdown
# Research Brief: Pure Inertial Odometry

## Problem Statement
纯惯性里程计（仅使用 IMU 数据）面临累积漂移问题。现有方法如 AIR-IO
虽然取得了不错的效果，但在长序列和复杂运动场景下仍有明显不足。

## Research Goal
提出一种新的深度学习方法，在纯惯性里程计任务上显著超越 AIR-IO，
同时保持实时推理能力。

## Known Constraints
- 仅使用 IMU 数据（加速度计 + 陀螺仪），不使用任何视觉/GNSS 辅助
- 方法需要能在嵌入式设备上实时运行
- 评估主要针对无人机设备

## Key Baselines
- AIR-IO (primary baseline)
- TLIO
- RoNIN
- RINS-W

## Available Resources
- GPU: [你的 GPU 配置]
- Datasets: RIDI, OxIOD, RoNIN dataset
- 时间预算: [你的时间规划]

## What I've Tried / Know
- [填写你已有的了解和尝试]
```

### 2.4 项目目录结构

ARIS 会在研究过程中自动创建以下文件结构：

```
~/io-research/
├── CLAUDE.md                        # 项目配置（你创建）
├── RESEARCH_BRIEF.md                # 研究简报（你创建）
├── IDEA_REPORT.md                   # 创意发现报告（阶段一生成）
├── IDEA_CANDIDATES.md               # 精简版创意候选（compact 模式）
├── refine-logs/                     # 方法精炼日志（阶段二生成）
│   ├── FINAL_PROPOSAL.md
│   ├── EXPERIMENT_PLAN.md
│   ├── EXPERIMENT_TRACKER.md
│   └── REFINEMENT_REPORT.md
├── innovation-logs/                 # 深度创新日志（阶段四生成）
│   ├── INNOVATION_STATE.json
│   ├── TECHNIQUE_LIBRARY.md
│   ├── EVOLUTION_LOG.md
│   ├── BLACKLIST.md
│   ├── FUSION_CANDIDATES.md
│   ├── FINAL_METHOD.md
│   ├── score-history.csv
│   └── round-NN/
├── AUTO_REVIEW.md                   # 审查循环日志
├── CLAIMS_FROM_RESULTS.md           # 从实验结果生成的论文声明
├── PAPER_PLAN.md                    # 论文大纲
├── paper/                           # LaTeX 论文源文件
│   ├── main.tex
│   ├── sections/
│   ├── figures/
│   └── references.bib
├── research-wiki/                   # 研究知识图谱（/research-wiki init 创建）
│   ├── index.md                     # 分类索引（自动生成）
│   ├── log.md                       # 操作日志
│   ├── gap_map.md                   # 领域差距图
│   ├── query_pack.md                # 压缩上下文（供 idea-creator 读取）
│   ├── papers/                      # 论文页面
│   ├── ideas/                       # 想法页面（含失败记录）
│   ├── experiments/                 # 实验页面
│   ├── claims/                      # 声明页面
│   └── graph/edges.jsonl            # 关系图谱
├── .aris/meta/                      # Meta-Optimize 日志（自动创建）
│   ├── events.jsonl                 # 使用事件日志
│   ├── optimizations.jsonl          # 已应用的优化记录
│   └── backups/                     # SKILL.md 备份
├── src/                             # 你的模型和实验代码
├── data/                            # 数据集
└── results/                         # 实验结果
```

---

## 3. ARIS 工作流总览

```
┌──────────────────────────────────────────────────────────────────────┐
│                  ARIS 完整工作流（全自主运行）                        │
│                                                                      │
│  ┌───────────┐   ┌───────────┐   ┌──────────────────┐   ┌───────┐  │
│  │ 阶段一    │──▶│ 阶段二    │──▶│ 阶段三           │──▶│阶段五 │  │
│  │ 创意发现  │   │ 方法精炼  │   │ 实验实现与部署   │   │论文   │  │
│  │ GPT审查   │   │ GPT博弈   │   │ GPT审查设计+代码 │   │写作   │  │
│  └───────────┘   └───────────┘   └────────┬─────────┘   └───────┘  │
│                                           │                         │
│                                           ▼                         │
│                                  ┌──────────────────┐               │
│                                  │ 阶段四           │               │
│                                  │ 深度创新循环     │               │
│                                  │ (40+ 轮迭代)     │               │
│                                  │ 每轮: GPT诊断    │               │
│                                  │ →调研→GPT对抗挑战 │               │
│                                  │ →GPT审查实验设计  │               │
│                                  │ →实现→评估→反思   │               │
│                                  └──────────────────┘               │
│                                                                      │
│  全程无需人工干预 · 所有决策自动记录 · 睡前启动 · 醒来看结果         │
└──────────────────────────────────────────────────────────────────────┘
```

**双模式博弈机制**（贯穿全流程）：

ARIS 采用 **"对抗博弈 + 联手合作"** 双模式。默认对抗模式保持质量压力；当对抗陷入僵局时自动升级为协作模式，双方联手解决问题：

```
默认：对抗模式 → GPT 批评/审查，Claude 实现/修复
        ↓ 陷入僵局（所有策略失败 / 所有变体被杀 / 持续停滞）
升级：协作模式 → Claude 分享实现证据 + GPT 分享理论分析 → 联合设计方案
        ↓ 找到方案
回归：对抗模式 → GPT 审查联合设计的方案（对抗审查始终拥有最终话语权）
```

| 阶段 | 对���博弈 | 联手合作（僵局时触发） |
|------|---------|---------------------|
| 创意生成 | 头脑风暴 + 扮演审稿人反驳每个想法 | — |
| 方法精炼 | 5 维度评审（新颖性/技术/实验/写作/影响力，目标 7/10）| — |
| 实验计划 | 对抗性审查——质疑弱基线、缺失实验、不公平对比 | — |
| 实验实现 | 基线公平性审计 + 统计显著性检查 + 代码审查 | — |
| 审查修复 | GPT 批评 → Claude 修复 → 验证门 | **所有修复策略失败 → 联合诊断+联合设计** |
| 深度创新 | 根因诊断 → 变体对抗挑战 → 实验审查 | **连续 2 轮变体全灭 → 协商式变体设计；停滞 3 轮 → 联合重诊断** |
| 研究评审 | 多轮批判性评审 + 反驳 | **5 轮后仍有分歧 → 共识检查点 + 联合实验路线设计** |
| 新颖性验证 | 跨模型交叉验证 | — |
| 论文写作 | 5 维度量规审查（阈值 7/10，高于业界 6/10 标准） | — |

---

## 4. 全自主决策机制

ARIS 被设计为**完全自主运行**，在每个决策点：

### 4.1 核心原则

1. **永不阻塞等待用户输入** — 基于可用数据做出最佳决策，记录推理过程，继续执行
2. **分叉自动选择** — 当存在多个选项（想法、变体、修复策略）时，应用量化标准选择最佳方案
3. **失败自动恢复** — 实验失败/网页搜索卡死/评审严厉时，自动诊断、修复、继续
4. **缺失上下文自动推断** — 当所需文件不存在时，从已有文件推断所需信息
5. **决策全部记录** — 每个自主决策记录 `[AUTO-DECISION]` 日志，用户事后可审查

### 4.2 自主行为详解

| 场景 | 旧行为（会阻塞） | 新行为（全自主） |
|------|------------------|------------------|
| 研究方向太宽泛 | 停下来问用户缩窄 | 自动从 RESEARCH_BRIEF.md 推断并缩窄 |
| 文献调研完成 | 问"是否匹配你的理解？" | 自动继续，不等待回复 |
| 无实验计划文件 | 问用户做什么实验 | 从项目文件自动推断实验方案 |
| 审查发现弱点 | 实现最小修复 | 调研文献提取底层原理，基于原理设计 2-3 策略 → 验证门 → 全失败则升级为联手合作模式 |
| 反驳需要补充实验 | 停下来问用户 | 自动调用 `/experiment-bridge` 补实验 |
| 无论文大纲 | 问用户描述贡献 | 自动从项目文件推断并先调用 `/paper-plan` |
| 无 GPU 配置 | 问用户 | 默认用本地 GPU，无 GPU 则尝试 CPU |
| 创新变体选择 | 等用户选 | Claude 根据 GPT-5.4 对抗反馈自动选最佳 |
| 对抗审查陷入僵局 | 无限循环或放弃 | 自动升级为协作模式：Claude 分享证据 + GPT 分享理论 → 联合设计 → 回归对抗验证 |
| 创新方法持续停滞 | 继续尝试同一方向 | 协作重诊断：Claude 提供日志证据 + GPT 修正根因 → 调整创新方向 |

### 4.3 决策日志

所有自主决策可在以下文件中追溯：
- `innovation-logs/EVOLUTION_LOG.md` — 每轮的选择理由
- `innovation-logs/round-NN/reflection.md` — 每轮的反思和决策
- `innovation-logs/round-NN/collaborative-design.md` — 协作设计对话（如触发）
- `innovation-logs/round-NN/collaborative-reanalysis.md` — 协作重诊断（如触发）
- `innovation-logs/round-NN/hparam-sweep.md` — 超参敏感性分析结果
- `innovation-logs/round-NN/inline-ablation.md` — ��联消融验证（改进时）
- `innovation-logs/round-NN/loss-experiment.md` — 损失函数实验（停滞时）
- `IDEA_REPORT.md` — 想法选择理由
- `AUTO_REVIEW.md` — 审查修复决策（含 `[COLLABORATIVE SESSION]` 标记）

搜索 `[AUTO-DECISION]` 标记找自主决���点，搜索 `[COLLABORATIVE SESSION]` 找联手合作点。

---

## 5. 阶段一：创意发现

**目标**：从研究方向出发，全自主生成、筛选、验证研究想法。

### 用法

```
/idea-discovery "pure inertial odometry improvement over AIR-IO"
```

带参数：
```
/idea-discovery "pure inertial odometry" — \
  ref paper: https://arxiv.org/abs/XXXX.XXXXX \
  arxiv download: true \
  compact: true
```

### 全自主流程

1. **文献调研**（`/research-lit`）：自动生成 3-5 个查询变体（同义词、宽/窄范围、基线名），搜索 arXiv（支持 `--category cs.RO` 类别过滤）、Semantic Scholar（默认启用，含 RAL/ICRA/IROS 期刊论文）、Google Scholar，对 top-5 关键论文执行引用图遍历（正向+反向），建立领域全景图
2. **创意生成**（`/idea-creator`）：GPT-5.4 xhigh 头脑风暴 8-12 个具体想法
3. **新颖性验证**（`/novelty-check`）：跨模型验证（覆盖 RAL/ICRA/IROS/CoRL/RSS 2024-2026）
4. **批判性评审**（`/research-review`）：GPT-5.4 扮演审稿人，指出最强反驳
5. **自动选择最佳想法**：根据试点信号 + 新颖性评分自动选定排名第一的想法并继续

### 输出

- `IDEA_REPORT.md`：排名后的想法列表，含试点实验结果、新颖性评分、审稿人反馈
- 自动选择排名第一的想法进入下一阶段（无需手动确认）

### 自主行为

- 方向太宽泛时，ARIS 自动从 `RESEARCH_BRIEF.md` 和 `CLAUDE.md` 推断并缩窄，记录 `[AUTO-NARROWED]` 日志
- 试点实验自动在 GPU 上运行（每个最多 2 小时，最多 3 个并行）
- 文献调研使用 API 工具优先（arXiv API 支持类别/标题/摘要过滤、Semantic Scholar API 默认启用），防止 WebSearch 卡死
- 引用图遍历（雪球搜索）：对最相关的 3-5 篇论文，自动获取其引用和被引论文，捕获不同术语但同一研究脉络的论文
- 术语驱动的迭代扩展：初次搜索后发现新术语时，自动补充 1 轮搜索（最多 3 个新查询）

---

## 6. 阶段二：方法精炼

**目标**：将选定的想法精炼为严谨的方法论和实验计划。

### 用法

```
/research-refine-pipeline "selected idea description"
```

### 全自主流程

1. **方法精炼**（`/research-refine`）：
   - 冻结"问题锚点"（Problem Anchor）——确保方法不偏离核心问题
   - **技术融合分析**：调研邻近领域（SLAM/VIO/信号处理/状态估计）技术，设计"1+1>2"的优雅融合方案
   - 构建初始提案 → GPT-5.4 多维度评审（最多 5 轮，目标 9/10）
   - 评审维度包含"贡献质量"：融合是否优雅（1+1>2）而非机械堆叠
   
2. **实验规划**（`/experiment-plan`）：
   - 生成声明驱动的实验路线图
   - 里程碑：健全性检查 → 基线 → 主方法 → 消融 → 优化
   - **GPT-5.4 对抗性审查实验计划**：质疑缺失实验、弱基线、不公平对比、声明-证据鸿沟

### 输出

```
refine-logs/
├── FINAL_PROPOSAL.md        # 最终方法提案
├── EXPERIMENT_PLAN.md        # 详细实验计划（含 Codex 审查反馈）
├── EXPERIMENT_TRACKER.md     # 实验追踪表
├── REVIEW_SUMMARY.md         # 评审摘要
└── REFINEMENT_REPORT.md      # 精炼过程报告
```

---

## 7. 阶段三：实验实现与部署

**目标**：将实验计划转化为可执行的代码，并部署到 GPU。

### 用法

```
/experiment-bridge — baseline comparison: AIR-IO
```

带参数：
```
/experiment-bridge — \
  code review: true \
  sanity first: true \
  baseline comparison: AIR-IO \
  auto deploy: true
```

### 全自主流程

1. 解析 `EXPERIMENT_PLAN.md`（若不存在则自动从项目文件推断）
2. 实现实验代码（如果设置了 `BASE_REPO`，会先克隆基础仓库）
3. **GPT-5.4 对抗审查实验设计+代码**：
   - 设计审查：实验是否真的测试了声明？基线是否最强？对比是否公平？
   - 代码审查：逻辑错误、评估指标正确性、是否使用正确的 ground truth
4. 健全性检查（先跑最小实验验证不崩溃）
5. 部署完整实验套件
6. 收集结果 + **自动对比 AIR-IO 基线**（含 delta 指标和显著性检验）

### 自动调试

实验失败时 ARIS 自动诊断并重试（最多 3 次）：
- OOM → 减小 batch size / 启用梯度检查点
- ImportError → 安装缺失包
- CUDA 错误 → 检查 GPU 可用性
- NaN → 降低学习率

### 负面结果的原理引导诊断（Phase 5.7）

当主实验结果为负面/不确定时，ARIS 自动：
1. 诊断失败根因（哪个指标不达标？为什么？）
2. 快速文献扫描（arXiv + Semantic Scholar 搜索根因关键词）
3. **提取原理而非方法**——对找到的 2-3 篇相关论文，应用"五层原理提取"：
   - 论文做了什么（表面方法）→ 为什么有效（底层原理）→ 如何适配我们的问题
   - 明确列出"不要复制"的具体元素
4. 将提取的原理写入结果摘要，为后续 `/auto-review-loop` 或 `/deep-innovation-loop` 提供可操作的灵感

---

## 8. 阶段四：深度创新循环（核心）

**这是最重要的阶段**——ARIS 完全自主进行 40+ 轮深度研究-创新迭代，无需任何人工干预。

### 用法

```
/deep-innovation-loop "learning-based Pure Inertial Odometry" — baseline: AIR-IO, venue: RAL
```

### 全自主工作原理

每轮包含 5+个阶段，融合对抗博弈与联手合作双模式：

```
Phase A: 深度诊断        ──▶ Phase B: 文献调研 ──▶ Phase C: 创新设计
  [GPT-5.4 根因分析]          [跨域检索+原理提取]    [GPT-5.4 提出变体]
  [停滞3轮→协作重诊断]        [API工具优先]          [GPT-5.4 对抗挑战]
                                                     [全灭2轮→协作设计]
    ▲                                                       │
    │    ┌──────────────────────────┐                       ▼
    │    │ Phase E: 反思学习        │◀── Phase D: 实现评估（多层验证）
    │    │ 显著性判定(p<0.05)       │     [超参敏感性 → 多种子评估]
    │    │ 内联消融(改进时)         │     [早停检查 → 统计显著性]
    │    │ 技术库/黑名单更新        │     [GPT-5.4 审查设计+代码]
    └────│ 进化日志/阶段转换        │     Phase D.5: 损失函数实验(停滞时)
         └──────────────────────────┘
```

#### Phase A — 深度诊断（GPT-5.4 xhigh）

GPT-5.4 分析当前方法的**根因**（不是表面症状）：
- 为什么 ATE 在某些序列上很高？→ 追溯到底层数学/物理原因
- 因果链：症状 ← 中间原因 ← 根因
- 邻近领域类比：SLAM/VIO/信号处理中是否解决过类似问题？
- 5 维度评分（新颖性/技术可靠性/实验严谨性/写作质量/影响力，RAL 标准，阈值 7/10）

**协作重诊断**（停滞 3+ 轮时触发）：当 patience_counter >= 3，说明之前的诊断可能有误。Claude 分享训练日志、指标、代码中的具体观察 → GPT 基于新证据修正根因分析 → 多轮对话（最多 4 轮）联合确定新方向。防止在错误诊断上浪费 10+ 轮。

#### Phase B — 定向文献调研 + 原理提取（条件触发）

当发现新的根因时（不是每轮都触发，有冷却期）：
- 优先使用 API 工具：`arxiv_fetch.py`（支持 `--category cs.RO` 类别过滤）、`semantic_scholar_fetch.py`（支持引用图遍历 `citations`/`references`）
- 多查询变体搜索 RAL/ICRA/IROS/TRO + 邻近领域（SLAM/VIO/信号处理）
- **五层原理提取**（核心改进）：对每篇相关论文，不是记录"论文做了什么"，而是提取"为什么有效"的底层原理：
  - 表面方法 → 底层原理（一句话，不含论文专有名词）→ 通用化表述 → 适配我们的问题 → 明确不要复制的元素
  - 例：论文用"IMU 窗口上的注意力机制" → 提取原理："基于估计信号可靠性的时序特征选择性加权"
- 更新 `TECHNIQUE_LIBRARY.md`（新增字段：提炼原理、通用形式、问题适配、禁止复制项）
- WebSearch 卡死时自动放弃并继续（不阻塞流水线）

#### Phase C — 创新设计 + GPT-5.4 对抗挑战

GPT-5.4 基于诊断结果和技术库中的**提炼原理**（非表面方法），提出 2-3 个方法变体，然后**立即自我对抗**：

1. **提出变体**：每个仅改变 1-2 个组件，阐述"1+1>2"协同效应，并标注**原理溯源**（哪个提炼原理启发了这个设计？设计是否与原论文实现不同？）
2. **对抗挑战**：GPT-5.4 对每个变体执行魔鬼代言人攻击：
   - 致命缺陷：这个方法最可能失败的原因？
   - 隐藏假设：什么假设可能是错的？
   - 更简单替代方案：能否用更简单的方法达到同样效果？
   - 评估陷阱：如何看起来改进了但实际是假改进？
3. **淘汰弱方案**：只有通过对抗挑战的变体才能进入实现阶段
4. **Claude 自动选择**：从幸存者中选最有前景的变体
5. **协作升级**（连续 2 轮变体全灭时）：从"GPT 提出 → GPT 挑战 → Claude 选择"切换为"Claude 分享实践约束 + GPT 提出满足理论+实践的设计" → 协商式联合设计变体 → 设计完成后回归对抗模式验证

三个宏观阶段的策略不同（软性转换，由耐心值驱动）：

| 预期轮次 | 宏观阶段 | 策略重点 |
|---------|---------|---------|
| 1-15 | **探索** | 大胆尝试跨领域技术嫁接 |
| 16-30 | **精炼** | 优化最佳变体，融合已验证技术 |
| 31-40+ | **打磨** | 消融简化，鲁棒性增强 |

#### Phase D — 实现与评估（多层验证）

1. Claude 实现代码改动
2. **GPT-5.4 审查实验设计+代码**：基线公平性审计（超参平等性、训练计划对齐、数据划分一致）+ 统计显著性检查 + 逻辑错误
3. **超参敏感性分析**：对新变体的关键超参测试 3-5 配置（默认/0.5×/2×），选最优配置
4. **多种子全量评估**：>= 3 seeds 运行，计算 mean ± std，95% 置信区间，close comparison 需 p 值
5. **早停检查**：第一个 seed 训练 30% 时检查 loss 轨迹，明显发散则终止（节省 GPU 时间）
6. **统计显著性判定**：不显著的改进标记为 "NS"（视同无改进），防止 lucky seed 误判
7. 自动调试失败（最多 3 次），不可恢复则自动回滚到最佳版本

#### Phase D.5 — 损失函数实验（停滞时触发）

当连续 2 轮无进步时（patience_counter >= 2），说明架构可能没问题但损失函数是瓶颈：
- 生成 2-3 种损失变体（当前损失+正则项 / 替代损失族 / 原理驱动修改）
- 快速对比（1 seed，最小数据集），选出最佳损失
- 改进则用于下轮全量评估

#### Phase E — 反思与学习

- **显著性判定**（核心改进）：
  - **改进** = mean 更好 AND p < 0.05（统计显著）→ 更新 best，执行内联消融
  - **无效** = mean 更好但 p >= 0.05（不显著）→ 视同 tied，递增耐心值
  - **退步** = mean 更差 → 递增耐心值或回滚
- **内联消融**（改进时自动执行）：去掉新组件，看改进是否消失。消失 = 确认因果贡献；未消失 = 混淆因素，降级为 tied
- 更新技术库（标记 TESTED-POSITIVE/NEGATIVE/MIXED + 提炼原理）
- 更新黑名单（两次失败的技术永不再试）
- 更新进化日志（方法谱系树 + `[AUTO-DECISION]` + `[COLLABORATIVE SESSION]` 记录）
- 检查宏观阶段转换条件（耐心值驱动）

### 每 5 轮的"融合优化"特殊轮次

每 5 轮（`round % 5 == 0`）自动触发融合优化：
- 从技术库选取所有 TESTED-POSITIVE 和 TESTED-MIXED 的技术
- GPT-5.4 排名融合候选（含 prompt）
- Claude 选择并测试 top 1-2 融合组合
- 这是实现"1+1>2"的核心机制

### 关键文件

| 文件 | 用途 |
|------|------|
| `TECHNIQUE_LIBRARY.md` | 累积知识库——所有探索过的技术、提炼原理、通用形式、问题适配方向及其状态 |
| `EVOLUTION_LOG.md` | 方法进化史——v0 到 vN 的完整谱系 + `[AUTO-DECISION]` + `[COLLABORATIVE SESSION]` |
| `BLACKLIST.md` | 已证实无效的方法（不会再尝试） |
| `FUSION_CANDIDATES.md` | 待测试的技术融合组合 |
| `score-history.csv` | 指标进展表（含 mean ± std + p 值） |
| `round-NN/hparam-sweep.md` | 超参敏感性分析结果 |
| `round-NN/inline-ablation.md` | 内联消融验证（改进时自动执行） |
| `round-NN/loss-experiment.md` | 损失函数实验（停滞时触发） |
| `round-NN/collaborative-*.md` | 协作对话记录（僵局时触发） |
| `FINAL_METHOD.md` | 终止时的最佳方法完整描述 + 架构图文字描述 |

### 停止条件

循环在以下任意条件满足时自动终止：
1. GPT-5.4 评分 >= 8/10 且显著优于 AIR-IO
2. 打磨阶段连续 3 轮无进步（耐心值耗尽）
3. 达到最大轮次上限（默认 50）
4. 连续回退触发回滚且长期无改善

---

## 9. 阶段五：论文写作

### 9.1 论文规划

```
/paper-plan "inertial odometry method" — venue: RAL
```

生成 `PAPER_PLAN.md`，包含：
- 声明-证据矩阵
- 按节分配的页面预算（RAL 共 6-8 页含参考文献）
- 图表规划（Figure 1 = 系统架构图）
- 引用脚手架
- GPT-5.4 交叉审查大纲

若无输入文件，ARIS 自动从项目文件推断论文贡献。

### 9.2 论文撰写

```
/paper-write "inertial odometry" — venue: RAL
```

自动生成完整 LaTeX 论文：
- IEEEtran 格式（journal 模式）
- 数字引用风格 `\cite{}`
- 真实 BibTeX（DBLP/CrossRef，非 LLM 生成）
- GPT-5.4 交叉审查论文质量
- 去 AI 化打磨

若无 `PAPER_PLAN.md`，ARIS 自动先调用 `/paper-plan` 生成大纲再撰写。

### 9.3 RAL 特别注意事项

- **页面限制**：6 页基础 + 2 页加长费 = 最多 8 页（含参考文献！）
- **非匿名**：包含完整作者信息和 IEEE 会员状态
- **视频附件**：强烈建议附带演示视频（10 MB 限制）
- **评审重点**：技术深度、实验严谨性、与 SOTA 基线对比、消融实验、失败案例分析
- **ICRA/IROS 选项**：RA-L 论文可选在 ICRA 或 IROS 做口头报告

### 9.4 编译与幻灯片

```
/paper-compile
/paper-slides "inertial odometry" — venue: RAL
```

---

## 10. 一键全流程

### 推荐命令（全自主深度创新）

```
/research-pipeline "learning-based Pure Inertial Odometry" — \
  deep innovation: true, \
  baseline: AIR-IO, \
  venue: RAL
```

这一条命令启动后，ARIS 会全自主完成：
1. 文献调研 → 生成 8-12 个想法 → 验证新颖性 → 自动选择最佳
2. 精炼方法 → GPT-5.4 多轮评审 → 生成实验计划 → GPT-5.4 审查计划
3. 实现代码 → GPT-5.4 审查设计+代码 → 部署实验 → 收集结果
4. 40+ 轮深度创新循环（每轮：诊断→调研→创新→对抗挑战→实现→评估→反思）
5. 生成论文声明 → 规划论文结构 → 撰写 LaTeX 论文

**无需任何人工干预。睡前启动，醒来查看结果。**

### 标准模式（4 轮审查，适用于快速迭代）

```
/research-pipeline "pure inertial odometry" — \
  baseline: AIR-IO, \
  venue: RAL
```

### 如何查看进展

启动后你可以随时（在另一个终端）查看进展：

```bash
# 查看当前轮次和评分
cat innovation-logs/INNOVATION_STATE.json | python -m json.tool

# 查看指标进展
cat innovation-logs/score-history.csv

# 查看方法进化历史
cat innovation-logs/EVOLUTION_LOG.md

# 查看技术库增长
wc -l innovation-logs/TECHNIQUE_LIBRARY.md

# 查看所有自主决策
grep "\[AUTO-DECISION\]" innovation-logs/EVOLUTION_LOG.md
```

---

## 11. 常用命令速查表

### 研究发现类

| 命令 | 用途 |
|------|------|
| `/idea-discovery "方向"` | 文献调研 + 创意生成 + 验证（全自主） |
| `/research-lit "关键词"` | 仅文献调研（含 RAL/ICRA/IROS 搜索） |
| `/novelty-check "方法描述"` | 仅新颖性验证（覆盖机器人学会议） |
| `/research-review "方法描述"` | 仅批判性评审 |

### 方法精炼类

| 命令 | 用途 |
|------|------|
| `/research-refine "方法"` | 迭代精炼方法提案（含技术融合分析） |
| `/research-refine-pipeline "方法"` | 精炼 + 实验规划一条龙 |
| `/experiment-plan "方法"` | 仅生成实验计划（含 GPT-5.4 对抗审查） |

### 实验管理类

| 命令 | 用途 |
|------|------|
| `/experiment-bridge — baseline comparison: AIR-IO` | 实现代码 + GPT审查 + 部署 + 基线对比 |
| `/run-experiment "命令"` | 部署单个实验到 GPU |
| `/monitor-experiment` | 监控实验进度 |
| `/training-check` | 检查训练质量（W&B） |
| `/vast-gpu provision` | 租赁 Vast.ai GPU |

### 创新迭代类

| 命令 | 用途 |
|------|------|
| `/deep-innovation-loop "主题" — baseline: AIR-IO, venue: RAL` | **40+ 轮深度创新（含对抗+协作双模式、多种子验证、超参搜索、损失实验）** |
| `/auto-review-loop "主题"` | 4 轮审查修复（5 维度量规 7/10 阈值 + 文献原理 + 验证门 + 协作升级） |
| `/auto-review-loop "主题" — research driven fix: false` | 4 轮审查修复（仅最小修复，不调研文献） |

### 论文写作类

| 命令 | 用途 |
|------|------|
| `/paper-plan "主题" — venue: RAL` | 生成论文大纲（含 GPT-5.4 审查） |
| `/paper-write "主题" — venue: RAL` | 撰写完整 LaTeX 论文 |
| `/paper-compile` | 编译 PDF |
| `/paper-figure` | 生成学术图表（自动从数据推断） |
| `/paper-slides "主题" — venue: RAL` | 生成演讲幻灯片 |

### 全流程类

| 命令 | 用途 |
|------|------|
| `/research-pipeline "方向" — deep innovation: true, baseline: AIR-IO, venue: RAL` | **一键全流程（深度创新，全自主）** |
| `/research-pipeline "方向"` | 一键全流程（标准 4 轮模式） |

### 知识管理类

| 命令 | 用途 |
|------|------|
| `/research-wiki init` | 初始化研究知识图谱 |
| `/research-wiki query "关键词"` | 生成压缩上下文（query_pack.md） |
| `/research-wiki stats` | 统计：论文/想法/实验/声明数量 |
| `/research-wiki lint` | 健康检查（孤立页面、过期声明、矛盾关系） |
| `/meta-optimize` | 分析使用模式，提出 SKILL.md 参数优化 |
| `/meta-optimize "技能名"` | 聚焦分析单个技能 |
| `/meta-optimize apply 1` | 应用推荐的第 1 项变更 |

---

## 12. 会话恢复与中断处理

ARIS 的长时间运行任务都有状态持久化机制，不怕中断。

### 自动恢复

深度创新循环会在每轮结束后写入 `INNOVATION_STATE.json`。如果会话中断：

```
# 重新启动 Claude Code，进入项目目录
cd ~/io-research
claude

# ARIS 会自动检测状态文件并恢复
/deep-innovation-loop "continue"
```

恢复规则：
- 状态文件存在且 < 24 小时 → **自动恢复**（从上次中断处继续）
- 状态文件 > 24 小时 → 视为过期，重新开始
- 状态文件标记 `completed` → 重新开始新循环

### 上下文窗口溢出

如果对话过长导致上下文压缩：
- ARIS 从 `INNOVATION_STATE.json` + `TECHNIQUE_LIBRARY.md` + `EVOLUTION_LOG.md` 恢复完整上下文
- 使用 `compact: true` 参数可以减少上下文占用

### 可选的人工干预

如果你想在某些时候手动引导方向（可选，非必需），添加 `human checkpoint: true`：

```
/deep-innovation-loop "topic" — baseline: AIR-IO, venue: RAL, human checkpoint: true
```

每轮结束后可以：
- `go` — 继续下一轮
- `focus on [主题]` — 引导下一轮关注特定方向
- `try [技术]` — 强制尝试特定技术
- `skip to refine` — 跳过探索阶段，直接进入精炼
- `stop` — 终止循环

**默认不开启**，ARIS 全自主运行。

---

## 13. GPU 与实验管理

### 本地 GPU

在 `CLAUDE.md` 中配置：
```markdown
- gpu: local
```

ARIS 自动使用 `nvidia-smi` 检测空闲 GPU 并分配。若无 GPU 配置，默认尝试本地 GPU。

### 远程 SSH 服务器

```markdown
- gpu: remote
- ssh_alias: my-server
- conda_env: io-env
- code_dir: ~/io-research
```

ARIS 通过 SSH 同步代码、在 screen 会话中运行实验。

### Vast.ai 按需租赁

```markdown
- gpu: vast
- auto_destroy: true
- max_budget: 10.00
```

ARIS 自动创建/销毁实例，实验结束后下载结果并释放资源。

### 实验监控

```
/monitor-experiment
```

监控内容：
- GPU 利用率和内存使用
- 训练损失曲线（如果配置了 W&B）
- 异常检测（DEAD/STALLED/IDLE/SLOW）
- 自动重试失败实验（最多 3 次）

---

## 14. Web 韧性与防卡死机制

ARIS 内置了多层防护，确保 WebSearch/WebFetch 卡死时不会阻塞流水线：

### 三层防御

| 层级 | 机制 | 说明 |
|------|------|------|
| **第一层** | API 工具优先 | `arxiv_fetch.py` 和 `semantic_scholar_fetch.py` 有内置超时，不会无限挂起 |
| **第二层** | 超时放弃 | WebSearch/WebFetch ~60 秒无响应则立即放弃，不重试同一查询 |
| **第三层** | 优雅降级 | 所有搜索失败时，使用已有 `TECHNIQUE_LIBRARY.md` 继续，记录 `[WEB UNAVAILABLE]` |

### 对你的影响

**零影响**——所有防护是自动的。你不需要配置任何东西。如果某次文献调研因网络问题不完整，ARIS 会在后续轮次（冷却期过后）自动补充搜索。

---

## 15. 三工具架构与强制审查

### 15.1 三工具架构

ARIS 已全面弃用 `mcp__codex__codex`（旧 MCP 通道），改用三种 Codex 工具，GPT-5.4 在每种通道中都能**直接读取项目文件**：

```
┌─────────────────────────────────────────────────────────────┐
│  codex exec --output-schema    → 结构化评分（5维度 JSON）   │
│  codex exec resume --last      → 多轮精炼（方法迭代）       │
│  codex exec -i image.pdf       → 图片审查（Figure/Poster）  │
│  codex exec review --base      → Git diff 代码审查          │
├─────────────────────────────────────────────────────────────┤
│  /codex:adversarial-review     → 代码审查检查点             │
│    --scope working-tree          （结构化 findings 输出）    │
│    --focus "specific concern"                               │
├─────────────────────────────────────────────────────────────┤
│  /codex:rescue --effort xhigh  → 深度调查/失败诊断/协作     │
│    GPT-5.4 自主读取项目全部文件                             │
└─────────────────────────────────────────────────────────────┘
```

### 15.2 强制代码审查规则

**每次代码修改 → 必须通过 `/codex:adversarial-review` → critical 问题修复后重审 → 通过后才能进入实验。无例外。**

| 技能 | 主路径审查点 | 失败修复路径审查点 |
|------|-------------|------------------|
| auto-review-loop | Step C.1.5 | Phase C.6 引用 C.1-C.4 |
| deep-innovation-loop | Step 1.1 | Step 2.7 → 回到 Step 1.1 |
| experiment-bridge | Phase 2.3 | Phase 5.7a → 回到 Phase 2.3 |
| result-to-claim | — | Step 4b 所有修复路径 |
| idea-creator | — | Phase 5 step 4 所有修复路径 |

### 15.3 结构化 JSON 评分

ARIS 使用 `codex exec --output-schema` 强制 GPT-5.4 按 JSON Schema 输出评审结果，自动解析：

```bash
codex exec --output-schema skills/shared-references/codex-schemas/review-5dim.schema.json \
  -o /tmp/aris-review.json --sandbox read-only -m gpt-5.4 \
  "Read project files. Score on 5 dimensions..."
```

可用 Schema：
- `review-5dim.schema.json` — 5 维度评审打分
- `novelty-verdict.schema.json` — 新颖性判定（novel/partial/not_novel）
- `claim-assessment.schema.json` — 声明评估（supported/partial/not_supported）
- `design-review.schema.json` — 实验设计审查（含基线公平性审计）

---

## 16. 失败深度分析机制

**核心原则：不轻易放弃任何 idea — 先让 GPT-5.4 独立检查是否实现/集成出了问题。**

当 idea 在任何阶段失败时，ARIS 自动触发 `codex:rescue` 进行 5 层诊断：

### 16.1 诊断维度

| 维度 | 检查内容 | 结论 |
|------|---------|------|
| 1. 实现检查 | 代码是否正确实现了 idea 的设计？有 bug 吗？ | 实现错误 → 修复重跑 |
| 2. 集成检查 | 新组件是否与现有架构冲突？API 用对了吗？ | 集成冲突 → 修复集成方式 |
| 3. 根因分析 | 失败是因为实现错误、集成问题、假设错误、还是调参不足？ | 区分可挽救 vs 根本缺陷 |
| 4. 挽救方案 | 如果 idea 可挽救，提出具体修改方案 | 有方案 → 实现+审查+重跑 |
| 5. 经验教训 | 从失败中学到什么？ | 记录到 wiki/findings |

### 16.2 各阶段的失败分析

| 阶段 | 失败场景 | rescue 分析 | 修复后流程 |
|------|---------|-----------|----------|
| idea-creator 试点 | Pilot 结果为负 | 检查实现/公平性/根因 | 修复→**强制审查**→重试 |
| experiment-bridge | 主实验失败 | 读取全部文件独立诊断 | 实现错误→修复→**强制审查**→重跑 |
| result-to-claim `no` | 声明被证伪 | 5 层分析+挽救方案 | 可挽救→实现修改→**强制审查**→重跑 |
| result-to-claim `partial` | 部分支持 | 分析哪些有效/失败 | 修复→**强制审查**→缩窄范围或补实验 |
| deep-innovation 变体退步 | 创新轮次无改进 | 检查实现/集成/假设/调参 | bug→同轮修复→**强制审查**→重测 |

> 所有修复路径都要求通过 `/codex:adversarial-review` 后才能进入实验。

---

## 17. 研究知识图谱 (Research Wiki)

### 17.1 概述

Research Wiki 是一个**持久化的、按项目的知识图谱**，跨轮次积累研究知识。每次文献调研、创意尝试、实验结果都会入库，系统越用越聪明。

**核心价值**：失败的想法永远不被遗忘 — 防止未来的创意生成重走死胡同。

### 17.2 初始化

```bash
/research-wiki init
```

创建目录结构：`papers/`、`ideas/`、`experiments/`、`claims/`、`graph/`

### 17.3 四种实体 + 八种关系

| 实体 | 目录 | 节点 ID |
|------|------|--------|
| 论文 | `papers/` | `paper:<slug>` |
| 想法 | `ideas/` | `idea:<id>` |
| 实验 | `experiments/` | `exp:<id>` |
| 声明 | `claims/` | `claim:<id>` |

关系类型：`extends`、`contradicts`、`addresses_gap`、`inspired_by`、`tested_by`、`supports`、`invalidates`、`supersedes`

### 17.4 自动集成钩子

| 技能 | 钩子 | 动作 |
|------|------|------|
| `/research-lit` | Step 6 | 论文入库（top 8-12 篇+关系边） |
| `/idea-creator` | Phase 0 | **读取** wiki（失败想法=黑名单，差距=优先种子） |
| `/idea-creator` | Phase 7 | **写回**所有想法（推荐+淘汰）到 wiki |
| `/result-to-claim` | Step 5 | 实验结果+声明状态入库 |

### 17.5 查询与维护

```bash
/research-wiki query "inertial odometry"    # 生成 query_pack.md（压缩上下文）
/research-wiki stats                        # 统计信息
/research-wiki lint                         # 健康检查
/research-wiki update paper:chen2025 — relevance: core
```

> 所有钩子受 `if research-wiki/ exists` 保护 — 未初始化时零影响。

---

## 18. 自我优化 (Meta-Optimize)

### 18.1 概述

Meta-Optimize 是 ARIS 的**自我改进系统**（Workflow M）。它被动收集使用日志，分析积累的模式，提出数据驱动的 SKILL.md 参数优化，经 GPT-5.4 审查后由用户批准应用。

### 18.2 工作原理

```
被动日志收集（Claude Code hooks）
    ↓ 积累 5+ 次技能调用
自动就绪提醒（SessionEnd 时检查）
    ↓ 用户运行 /meta-optimize
分析：频率/失败/收敛/人工干预模式
    ↓
生成补丁（unified diff + 数据证据）
    ↓
GPT-5.4 对抗审查（codex exec）→ 评分 ≥ 7 才推荐
    ↓
用户审批 → 应用（可逆，有备份）
```

### 18.3 使用

```bash
/meta-optimize                        # 分析当前项目
/meta-optimize "auto-review-loop"     # 聚焦单个技能
/meta-optimize --global               # 跨项目分析
/meta-optimize apply 1                # 应用推荐的第 1 项变更
```

### 18.4 日志收集

通过 Claude Code hooks 自动收集（在 `templates/claude-hooks/meta_logging.json` 中配置）：
- 技能调用频率和参数
- 工具失败模式
- Codex 调用类型（`codex exec`、`codex:rescue`、`codex:adversarial-review`）
- 用户手动干预模式（指示 SKILL.md 有缺陷）

### 18.5 安全保障

- 每项变更独立审查，评分 ≥ 7/10 才推荐
- 用户必须显式批准，永不自动应用
- 所有原文件备份到 `.aris/meta/backups/`
- 变更日志记录到 `.aris/meta/optimizations.jsonl`

---

## 19. 常见问题

### Q: Codex MCP 连接失败怎么办？

```bash
# 重新安装 Codex
npm install -g @openai/codex

# 验证 API key
codex --version

# 重新注册 MCP
claude mcp remove codex
claude mcp add codex -s user -- codex mcp-server
```

### Q: 深度创新循环看起来在"绕圈"？

ARIS 内置了多层防绕圈机制：
- 黑名单阻止重复失败的方法
- 相似性检查阻止近似重复的变体
- 每个变体仅改变 1-2 个组件（可归因原则）
- GPT-5.4 对抗挑战淘汰弱方案
- **协作升级**：连续 2 轮变体全灭 → 从对抗切换为协作设计
- **协作重诊断**：停滞 3+ 轮 → Claude + GPT 联合修正根因
- **损失函数实验**：连续 2 轮无进步 → 测试替代损失函数
- **统计显著性判定**：lucky seed 不算改进（p >= 0.05 = tied）
- **内联消融**：改进时自动验证是否为混淆因素

检查 `innovation-logs/BLACKLIST.md`、`innovation-logs/EVOLUTION_LOG.md` 和 `innovation-logs/round-NN/collaborative-*.md` 了解循环状态。

### Q: 实验 OOM 怎么办？

ARIS 自动处理：减小 batch size → 启用梯度检查点 → 减小模型规模。3 次都失败则自动回滚到最佳版本并继续下一轮。

### Q: 如何跳过某个阶段直接开始？

每个阶段都可以独立运行：
```
# 跳过创意发现，直接从你的方法开始精炼
/research-refine "your method description"

# 跳过精炼，直接开始深度创新
/deep-innovation-loop "your method" — baseline: AIR-IO, venue: RAL

# 跳过所有前期工作，直接写论文
/paper-write "your topic" — venue: RAL
```

### Q: 如何查看 ARIS 做了哪些自主决策？

```bash
# 查看所有自主决策
grep -r "\[AUTO-DECISION\]" innovation-logs/

# 查看方法进化谱系
cat innovation-logs/EVOLUTION_LOG.md

# 查看技术探索记录
cat innovation-logs/TECHNIQUE_LIBRARY.md
```

### Q: RAL 论文怎么附带视频？

1. ARIS 在论文中自动添加视频引用文字
2. 你需要自己制作演示视频（推荐 1-2 分钟）
3. 视频格式：MP4，大小 < 10 MB
4. 在 IEEE 投稿系统上传为 Multimedia 附件

### Q: 运行一次全流程大概需要多长时间？

| 阶段 | 预估时间 | 说明 |
|------|---------|------|
| 创意发现 | 30-60 min | 含文献调研 + 试点实验 |
| 方法精炼 | 20-40 min | 含 GPT-5.4 多轮评审 |
| 实验实现 | 15-60 min | 取决于代码复杂度 |
| 深度创新循环 | 数小时-数天 | 含超参搜索、多种子验证、协作对话 |
| 论文写作 | 30-60 min | 含交叉审查 |

**推荐策略**：晚上启动全流程，第二天查看结果。

### Q: 三工具架构和旧的 Codex MCP 有什么区别？

| | 旧 MCP | 新三工具架构 |
|---|---|---|
| GPT-5.4 能读文件？ | 不能，只看 Claude 粘贴的文本 | **直接读取项目文件** |
| 结构化输出？ | 自由文本 | **JSON Schema 强制格式** |
| 多轮对话？ | threadId | `codex exec resume --last` |
| 图片审查？ | 不支持 | `codex exec -i image.pdf` |

### Q: 如何启用 Research Wiki？

```bash
/research-wiki init          # 一次性初始化
# 之后 research-lit、idea-creator、result-to-claim 自动读写 wiki
```

### Q: Meta-Optimize 会自动修改我的技能吗？

不会。所有变更必须经过 GPT-5.4 审查（评分 ≥ 7/10）+ 用户显式批准。变更可逆，有完整备份。

---

## 附录：ARIS 技能参数速查

### 深度创新循环完整参数

```
/deep-innovation-loop "topic" — \
  baseline: AIR-IO,            # 主基线
  venue: RAL,                  # 目标期刊
  domain: inertial odometry,   # 研究领域
  max rounds: 40,              # 最大轮次
  target score: 8,             # 目标评分
  human checkpoint: false,     # 人工检查点（默认关闭）
  compact: false,              # 紧凑模式
  patience explore: 5,         # 探索阶段耐心值
  patience refine: 4,          # 精炼阶段耐心值
  patience polish: 3,          # 打磨阶段耐心值
  fusion interval: 5,          # 融合优化间隔
  lit search cooldown: 3       # 文献搜索冷却轮次
```

### 文献调研完整参数

```
/research-lit "topic" — \
  sources: all,                 # 搜索源（默认 all，含 Semantic Scholar）
  no-s2,                        # 排除 Semantic Scholar（更快）
  snowball: true,               # 引用图遍历（默认开启）
  arxiv download: true,         # 下载 arXiv PDF
  max download: 10              # 最多下载数
```

### 全流程完整参数

```
/research-pipeline "topic" — \
  deep innovation: true,       # 启用深度创新模式
  baseline: AIR-IO,            # 传递给 deep-innovation-loop
  venue: RAL,                  # 传递给论文写作
  auto proceed: true,          # 自动选择最佳想法（默认）
  human checkpoint: false,     # 无人工中断（默认）
  arxiv download: true,        # 下载相关论文 PDF
  compact: true                # 紧凑模式（节省上下文）
```
