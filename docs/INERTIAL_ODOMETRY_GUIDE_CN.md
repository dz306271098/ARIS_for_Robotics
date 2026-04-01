# ARIS 使用指南：纯惯性里程计研究

> 面向纯惯性里程计（Inertial Odometry）领域，以 AIR-IO 为主基线，目标期刊 IEEE RAL。
> 执行模型：Claude Opus 4.6（执行器）+ Codex GPT-5.4 xhigh（审查器）

---

## 目录

1. [环境准备](#1-环境准备)
2. [项目初始化](#2-项目初始化)
3. [ARIS 工作流总览](#3-aris-工作流总览)
4. [阶段一：创意发现](#4-阶段一创意发现)
5. [阶段二：方法精炼](#5-阶段二方法精炼)
6. [阶段三：实验实现与部署](#6-阶段三实验实现与部署)
7. [阶段四：深度创新循环（核心）](#7-阶段四深度创新循环核心)
8. [阶段五：论文写作](#8-阶段五论文写作)
9. [一键全流程](#9-一键全流程)
10. [常用命令速查表](#10-常用命令速查表)
11. [会话恢复与中断处理](#11-会话恢复与中断处理)
12. [GPU 与实验管理](#12-gpu-与实验管理)
13. [常见问题](#13-常见问题)

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

### 1.3 配置 Codex MCP（GPT-5.4 审查器）

这是实现"Claude 执行 + GPT-5.4 审查"的关键步骤：

```bash
# 安装 Codex CLI
npm install -g @openai/codex

# 配置 Codex（设置模型为 gpt-5.4）
codex setup
# 在弹出的配置中选择 gpt-5.4 模型

# 将 Codex 注册为 Claude Code 的 MCP 服务器
claude mcp add codex -s user -- codex mcp-server
```

验证配置：在 Claude Code 中输入以下命令测试 Codex MCP 是否可用：
```
请使用 mcp__codex__codex 发送一条测试消息
```

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

### 2.3 编写研究简报（可选但推荐）

创建 `RESEARCH_BRIEF.md`，提供更详细的研究背景，ARIS 会自动检测并加载：

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
- 评估需覆盖多种运动模式（步行、驾驶、手持等）

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
├── RESEARCH_BRIEF.md                # 研究简报（你创建，可选）
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
├── src/                             # 你的模型和实验代码
├── data/                            # 数据集
└── results/                         # 实验结果
```

---

## 3. ARIS 工作流总览

```
┌──────────────────────────────────────────────────────────────────────┐
│                        ARIS 完整工作流                               │
│                                                                      │
│  ┌───────────┐   ┌───────────┐   ┌──────────────────┐   ┌───────┐  │
│  │ 阶段一    │──▶│ 阶段二    │──▶│ 阶段三           │──▶│阶段五 │  │
│  │ 创意发现  │   │ 方法精炼  │   │ 实验实现与部署   │   │论文   │  │
│  │           │   │           │   │                  │   │写作   │  │
│  └───────────┘   └───────────┘   └────────┬─────────┘   └───────┘  │
│                                           │                         │
│                                           ▼                         │
│                                  ┌──────────────────┐               │
│                                  │ 阶段四           │               │
│                                  │ 深度创新循环     │               │
│                                  │ (40+ 轮迭代)     │               │
│                                  │ 诊断→调研→创新   │               │
│                                  │ →实现→评估→反思  │               │
│                                  └──────────────────┘               │
│                                                                      │
│  你可以单独使用任意阶段，也可以用 /research-pipeline 串联全部        │
└──────────────────────────────────────────────────────────────────────┘
```

每个阶段都可以**独立使用**，也可以通过 `/research-pipeline` **串联运行**。

---

## 4. 阶段一：创意发现

**目标**：从宽泛的研究方向出发，生成、筛选、验证研究想法。

### 基本用法

```
/idea-discovery "pure inertial odometry improvement over AIR-IO"
```

### 带参数

```
/idea-discovery "pure inertial odometry" — \
  ref paper: https://arxiv.org/abs/XXXX.XXXXX \
  arxiv download: true \
  compact: true
```

### 流程详解

1. **文献调研**（`/research-lit`）：自动搜索 arXiv、Semantic Scholar（RAL/ICRA/IROS）、Google Scholar，建立领域全景图
2. **创意生成**（`/idea-creator`）：GPT-5.4 xhigh 头脑风暴 8-12 个具体想法
3. **新颖性验证**（`/novelty-check`）：跨模型验证每个想法是否已被人做过
4. **批判性评审**（`/research-review`）：GPT-5.4 扮演审稿人，指出最强反驳

### 输出

- `IDEA_REPORT.md`：排名后的想法列表，含试点实验结果、新颖性评分、审稿人反馈
- 你可以选择其中一个想法进入下一阶段

### 关键提示

- 如果想法太宽泛（如"improve IMU"），ARIS 会要求你缩小范围
- 试点实验自动在 GPU 上运行（每个最多 2 小时，最多 3 个并行）
- 设置 `AUTO_PROCEED: false` 可以手动选择想法

---

## 5. 阶段二：方法精炼

**目标**：将选定的想法精炼为严谨的方法论和实验计划。

### 基本用法

```
/research-refine-pipeline "selected idea description"
```

### 流程详解

1. **方法精炼**（`/research-refine`）：
   - 冻结"问题锚点"（Problem Anchor）——确保方法不偏离核心问题
   - 构建初始提案 → GPT-5.4 多维度评审（最多 5 轮，目标 9/10）
   - **技术融合分析**（新增）：调研邻近领域技术，设计优雅融合方案
   
2. **实验规划**（`/experiment-plan`）：
   - 生成声明驱动的实验路线图
   - 里程碑：健全性检查 → 基线 → 主方法 → 消融 → 优化

### 输出

```
refine-logs/
├── FINAL_PROPOSAL.md        # 最终方法提案
├── EXPERIMENT_PLAN.md        # 详细实验计划
├── EXPERIMENT_TRACKER.md     # 实验追踪表
├── REVIEW_SUMMARY.md         # 评审摘要
└── REFINEMENT_REPORT.md      # 精炼过程报告
```

---

## 6. 阶段三：实验实现与部署

**目标**：将实验计划转化为可执行的代码，并部署到 GPU。

### 基本用法

```
/experiment-bridge — baseline comparison: AIR-IO
```

### 带参数

```
/experiment-bridge — \
  code review: true \
  sanity first: true \
  baseline comparison: AIR-IO \
  auto deploy: true
```

### 流程详解

1. 解析 `EXPERIMENT_PLAN.md`
2. 实现实验代码（如果设置了 `BASE_REPO`，会先克隆基础仓库）
3. GPT-5.4 代码审查（检查逻辑错误、评估指标正确性）
4. 健全性检查（先跑最小实验验证不崩溃）
5. 部署完整实验套件
6. 收集结果 + 自动对比 AIR-IO 基线

### 自动调试

如果实验失败，ARIS 会自动诊断（OOM、ImportError、CUDA 错误、NaN 等）并重试最多 3 次。

---

## 7. 阶段四：深度创新循环（核心）

**这是最重要的阶段**——ARIS 将自主进行 40+ 轮的深度研究-创新迭代。

### 基本用法

```
/deep-innovation-loop "improve inertial odometry" — \
  baseline: AIR-IO, venue: RAL
```

### 带人工检查点

```
/deep-innovation-loop "improve inertial odometry" — \
  baseline: AIR-IO, venue: RAL, \
  human checkpoint: true
```

### 工作原理

每轮包含 5 个阶段：

```
Phase A: 深度诊断 ──▶ Phase B: 文献调研 ──▶ Phase C: 创新设计
    ▲                                              │
    │                                              ▼
Phase E: 反思学习 ◀── Phase D: 实现评估
```

#### Phase A — 深度诊断

GPT-5.4 xhigh 分析当前方法的**根因**（不是表面症状）：
- 为什么 ATE 在某些序列上很高？→ 追溯到底层数学/物理原因
- 因果链：症状 ← 中间原因 ← 根因
- 邻近领域类比：SLAM/VIO/信号处理中是否解决过类似问题？

#### Phase B — 定向文献调研

当发现新的根因时（不是每轮都触发）：
- 搜索 arXiv（cs.RO, eess.SP）+ Semantic Scholar（RAL/ICRA/IROS/TRO）
- 寻找邻近领域的解决方案
- 提取技术要点，更新 `TECHNIQUE_LIBRARY.md`

#### Phase C — 创新设计

GPT-5.4 基于诊断结果和技术库，提出 2-3 个方法变体：
- 每个变体仅改变 1-2 个组件（可归因原则）
- 明确阐述"1+1>2"的协同效应
- 避免黑名单上的方法

三个宏观阶段的策略不同：

| 轮次 | 宏观阶段 | 策略重点 |
|------|---------|---------|
| 1-15 | **探索** | 大胆尝试跨领域技术嫁接 |
| 16-30 | **精炼** | 优化最佳变体，融合已验证技术 |
| 31-40+ | **打磨** | 消融简化，鲁棒性增强 |

#### Phase D — 实现与评估

- Claude 实现代码改动
- 部署实验，对比 AIR-IO + 当前最佳
- 自动调试失败（最多 3 次）

#### Phase E — 反思与学习

- 更新技术库（标记 TESTED-POSITIVE/NEGATIVE/MIXED）
- 更新黑名单（两次失败的技术）
- 更新进化日志（方法谱系树）
- 检查宏观阶段转换条件

### 关键文件

| 文件 | 用途 |
|------|------|
| `TECHNIQUE_LIBRARY.md` | 累积知识库——所有探索过的技术及其状态 |
| `EVOLUTION_LOG.md` | 方法进化史——从 v0 到 vN 的完整谱系 |
| `BLACKLIST.md` | 已证实无效的方法（不会再尝试） |
| `FUSION_CANDIDATES.md` | 待测试的技术融合组合 |
| `score-history.csv` | 指标进展表 |
| `FINAL_METHOD.md` | 终止时的最佳方法完整描述 |

### 停止条件

循环在以下任意条件满足时终止：
1. GPT-5.4 评分 >= 8/10 且显著优于 AIR-IO
2. 打磨阶段连续 3 轮无进步
3. 达到最大轮次上限（默认 50）
4. 用户手动停止（`human checkpoint: true` 时）

### 每 5 轮的"融合优化"特殊轮次

每 5 轮自动触发一次融合优化：
- 从技术库中选取所有 TESTED-POSITIVE 和 TESTED-MIXED 的技术
- 系统性评估哪些技术组合可以产生协同效应
- 测试 top 1-2 融合组合
- 这是实现"1+1>2"的核心机制

---

## 8. 阶段五：论文写作

### 8.1 论文规划

```
/paper-plan "inertial odometry method" — venue: RAL
```

生成 `PAPER_PLAN.md`，包含：
- 声明-证据矩阵
- 按节分配的页面预算（RAL 共 6-8 页含参考文献）
- 图表规划（Figure 1 = 系统架构图）
- 引用脚手架

### 8.2 论文撰写

```
/paper-write "inertial odometry" — venue: RAL
```

自动生成完整 LaTeX 论文：
- IEEEtran 格式（journal 模式）
- 数字引用风格 `\cite{}`
- 真实 BibTeX（DBLP/CrossRef，非 LLM 生成）
- GPT-5.4 交叉审查论文质量
- 去 AI 化打磨

### 8.3 RAL 特别注意事项

- **页面限制**：6 页基础 + 2 页加长费 = 最多 8 页（含参考文献！）
- **非匿名**：包含完整作者信息和 IEEE 会员状态
- **视频附件**：强烈建议附带演示视频（10 MB 限制）
- **评审重点**：技术深度、实验严谨性、与 SOTA 基线对比、消融实验、失败案例分析
- **ICRA/IROS 选项**：RA-L 论文可选在 ICRA 或 IROS 做口头报告

### 8.4 编译论文

```
/paper-compile
```

### 8.5 制作幻灯片（可选）

```
/paper-slides "inertial odometry" — venue: RAL
```

---

## 9. 一键全流程

如果你希望从头到尾全自动运行：

### 标准模式（4 轮审查）

```
/research-pipeline "pure inertial odometry improvement" — \
  auto proceed: true, \
  human checkpoint: false
```

### 深度创新模式（40+ 轮创新迭代）

```
/research-pipeline "pure inertial odometry" — \
  deep innovation: true, \
  baseline: AIR-IO, \
  venue: RAL, \
  auto proceed: true, \
  human checkpoint: false
```

### 带人工检查点的深度创新模式

```
/research-pipeline "pure inertial odometry" — \
  deep innovation: true, \
  baseline: AIR-IO, \
  venue: RAL, \
  auto proceed: false, \
  human checkpoint: true
```

### 推荐的"睡前启动"策略

1. **傍晚**：运行创意发现，手动选择想法
   ```
   /idea-discovery "pure inertial odometry" — auto proceed: false
   ```
   
2. **选定想法后**：启动方法精炼
   ```
   /research-refine-pipeline "selected idea"
   ```

3. **睡前**：启动深度创新循环
   ```
   /deep-innovation-loop "improve IO method" — \
     baseline: AIR-IO, venue: RAL, \
     human checkpoint: false
   ```

4. **第二天起床**：检查 `innovation-logs/EVOLUTION_LOG.md` 查看进展

---

## 10. 常用命令速查表

### 研究发现类

| 命令 | 用途 |
|------|------|
| `/idea-discovery "方向"` | 文献调研 + 创意生成 + 验证 |
| `/research-lit "关键词"` | 仅文献调研 |
| `/novelty-check "方法描述"` | 仅新颖性验证 |
| `/research-review "方法描述"` | 仅批判性评审 |

### 方法精炼类

| 命令 | 用途 |
|------|------|
| `/research-refine "方法"` | 迭代精炼方法提案 |
| `/research-refine-pipeline "方法"` | 精炼 + 实验规划一条龙 |
| `/experiment-plan "方法"` | 仅生成实验计划 |

### 实验管理类

| 命令 | 用途 |
|------|------|
| `/experiment-bridge` | 实现代码 + 部署实验 |
| `/run-experiment "命令"` | 部署单个实验到 GPU |
| `/monitor-experiment` | 监控实验进度 |
| `/training-check` | 检查训练质量（W&B） |
| `/vast-gpu provision` | 租赁 Vast.ai GPU |

### 创新迭代类

| 命令 | 用途 |
|------|------|
| `/deep-innovation-loop "主题" — baseline: AIR-IO, venue: RAL` | **40+ 轮深度创新** |
| `/auto-review-loop "主题"` | 4 轮标准审查修复 |
| `/auto-review-loop "主题" — research driven fix: true` | 带文献调研的审查修复 |

### 论文写作类

| 命令 | 用途 |
|------|------|
| `/paper-plan "主题" — venue: RAL` | 生成论文大纲 |
| `/paper-write "主题" — venue: RAL` | 撰写完整 LaTeX 论文 |
| `/paper-compile` | 编译 PDF |
| `/paper-figure` | 生成学术图表 |
| `/paper-slides "主题" — venue: RAL` | 生成演讲幻灯片 |

### 全流程类

| 命令 | 用途 |
|------|------|
| `/research-pipeline "方向" — deep innovation: true` | **一键全流程（深度模式）** |
| `/research-pipeline "方向"` | 一键全流程（标准模式） |

---

## 11. 会话恢复与中断处理

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

### 手动干预

在 `human checkpoint: true` 模式下，每轮结束后你可以：
- `go` — 继续下一轮
- `focus on [主题]` — 引导下一轮关注特定方向
- `try [技术]` — 强制尝试特定技术
- `skip to refine` — 跳过探索阶段，直接进入精炼
- `stop` — 终止循环

---

## 12. GPU 与实验管理

### 本地 GPU

在 `CLAUDE.md` 中配置：
```markdown
- gpu: local
```

ARIS 会自动使用 `nvidia-smi` 检测空闲 GPU 并分配。

### 远程 SSH 服务器

```markdown
- gpu: remote
- ssh_alias: my-server
- conda_env: io-env
- code_dir: ~/io-research
```

ARIS 会通过 SSH 同步代码、在 screen 会话中运行实验。

### Vast.ai 按需租赁

```markdown
- gpu: vast
- auto_destroy: true
- max_budget: 10.00
```

ARIS 会自动创建/销毁实例，实验结束后下载结果并释放资源。

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

## 13. 常见问题

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

检查 `innovation-logs/BLACKLIST.md` 是否有重复条目。ARIS 内置了防绕圈机制：
- 黑名单阻止重复失败的方法
- 相似性检查阻止近似重复的变体
- 每个变体仅改变 1-2 个组件

如果确实卡住，可以用 `human checkpoint: true` 手动引导方向。

### Q: 实验 OOM 怎么办？

ARIS 的自动调试会尝试：
1. 减小 batch size
2. 启用梯度检查点
3. 减小模型规模

如果 3 次都失败，会停止并报告。你可以修改代码后继续。

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

### Q: 如何查看当前进展？

```
# 查看创新循环进度
cat innovation-logs/score-history.csv

# 查看方法进化历史
cat innovation-logs/EVOLUTION_LOG.md

# 查看技术库
cat innovation-logs/TECHNIQUE_LIBRARY.md

# 查看当前状态
cat innovation-logs/INNOVATION_STATE.json
```

### Q: RAL 论文怎么附带视频？

1. ARIS 会在论文中自动添加视频引用文字
2. 你需要自己制作演示视频（推荐 1-2 分钟）
3. 视频格式：MP4，大小 < 10 MB
4. 在 IEEE 投稿系统上传为 Multimedia 附件

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
  human checkpoint: false,     # 人工检查点
  compact: false,              # 紧凑模式
  patience explore: 5,         # 探索阶段耐心值
  patience refine: 4,          # 精炼阶段耐心值
  patience polish: 3,          # 打磨阶段耐心值
  fusion interval: 5,          # 融合优化间隔
  lit search cooldown: 3       # 文献搜索冷却轮次
```

### 全流程完整参数

```
/research-pipeline "topic" — \
  deep innovation: true,       # 启用深度创新模式
  baseline: AIR-IO,            # 传递给 deep-innovation-loop
  venue: RAL,                  # 传递给论文写作
  auto proceed: true,          # 自动选择最佳想法
  human checkpoint: false,     # 无人工中断
  arxiv download: true,        # 下载相关论文 PDF
  compact: true                # 紧凑模式（节省上下文）
```
