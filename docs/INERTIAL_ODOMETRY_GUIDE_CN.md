# ARIS 使用示例：纯惯性里程计研究

> 面向纯惯性里程计场景，以 AIR-IO 为主基线，目标期刊 IEEE RAL。
> 当前使用的仍然是仓库唯一公开主线：
> **Codex 负责执行**，**Claude Code CLI 负责审稿**，两者通过本地 `claude-review` MCP bridge 连接。

这份文档不是第二份主手册，而是把当前主线压到一个具体研究方向上的落地示例。

---

## 1. 场景目标

研究目标可以写得很直接：

- 任务：纯惯性里程计
- 输入：仅 IMU
- 主基线：AIR-IO
- 目标 venue：RAL
- 关键指标：ATE、RTE、heading drift、长序列稳定性

适合这条示例的典型诉求：

- 想从零启动一个惯导研究项目
- 想验证 ARIS 主线在真实机器人方向上的落地方式
- 想看 `research-wiki`、`deep-innovation-loop`、`meta-optimize` 如何嵌进一个长期项目

---

## 2. 环境准备

### 2.1 安装执行器与审稿器

```bash
npm install -g @openai/codex @anthropic-ai/claude-code
codex setup
codex --version
claude --version
```

确认 Claude CLI 可用：

```bash
claude -p "Reply with exactly READY" --output-format json --tools ""
```

### 2.2 安装 ARIS 主线

```bash
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git
cd Auto-claude-code-research-in-sleep
bash scripts/install_codex_claude_mainline.sh
```

验证：

```bash
codex mcp get claude-review --json
```

---

## 3. 初始化惯导项目

### 3.1 创建项目

```bash
mkdir ~/io-research
cd ~/io-research
git init
codex -C .
```

### 3.2 编写 `CODEX.md`

对于纯惯性里程计，推荐最少写到这个粒度：

```markdown
# Inertial Odometry Research Project

## Research Direction
- Topic: pure inertial odometry with deep learning
- Target venue: IEEE_JOURNAL
- Main baseline: AIR-IO

## GPU Configuration
- gpu: remote
- ssh_alias: io-server
- conda_env: io-env
- code_dir: ~/io-research

## Notes
- Datasets: RIDI, OxIOD, RoNIN
- Key metrics: ATE, RTE, heading drift
- Constraints: IMU only, real-time friendly, long-sequence robustness

## Pipeline Status
stage: init
idea: ""
contract: docs/research_contract.md
current_branch: main
baseline: "AIR-IO as primary must-beat baseline"
training_status: idle
active_tasks: []
next: run /idea-discovery
```

### 3.3 编写 `RESEARCH_BRIEF.md`

建议把这些关键信息补进去：

- 为什么 AIR-IO 还不够
- 你最在意哪些误差模式
- 可用数据集与训练预算
- 已知不做什么
- 是否强调实时性或嵌入式约束

---

## 4. 这条主线在惯导场景里的实际链路

### 4.1 推荐按阶段运行

```text
/idea-discovery "pure inertial odometry beyond AIR-IO"
/research-refine-pipeline "pure inertial odometry beyond AIR-IO"
/experiment-bridge "refine-logs/EXPERIMENT_PLAN.md"
/run-experiment "your training command"
/deep-innovation-loop "pure inertial odometry — baseline: AIR-IO, venue: RAL"
/auto-review-loop "pure inertial odometry"
/paper-writing "NARRATIVE_REPORT.md"
```

### 4.2 一键总入口

如果你想先跑一条主干全流程：

```text
/research-pipeline "pure inertial odometry beyond AIR-IO"
```

这时默认语义是：

- `RESEARCH_WIKI: auto`
- `DEEP_INNOVATION: auto`
- `META_OPTIMIZE: false`

也就是说，主线会在初轮实验后判断：

- 当前问题是不是结构性的
- 是否需要进入 `deep-innovation-loop`
- 还是直接进入 `auto-review-loop`

---

## 5. 各阶段在惯导任务里的关注点

### 5.1 Idea Discovery

这一阶段最重要的是让系统明确：

- 误差主要来自什么：
  - bias drift
  - motion pattern shift
  - long-horizon accumulation
  - train/test sensor gap
- 哪些改进方向已经被做烂
- 哪些邻近领域原则可以迁移，但不能照搬

阶段产物重点看：

- `IDEA_REPORT.md`
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`

### 5.2 Experiment Bridge

在惯导里，这一阶段通常要特别注意：

- 数据切分是否公平
- 评估是否真的对齐 ground truth
- 序列长度、采样频率和坐标系处理是否一致
- baseline 调参预算是否公平
- 结果是否能稳定保存为后续分析可读的 JSON/CSV

### 5.3 Deep Innovation Loop

如果初轮实验只是小修小补，很可能不需要深度创新。

但当你遇到这些情况时，`deep-innovation-loop` 很有价值：

- 对 AIR-IO 的提升不稳定
- 改进只在少量序列上出现
- 指标提升不能支持想写的 claim
- 当前方法只是修参数，不是真正抓到根因

在惯导任务里，深度创新轮最值得追的通常是：

- 漂移根因诊断是否正确
- 物理约束或时序建模是否真的必要
- 哪类附加复杂度应该明确拒绝

### 5.4 Auto Review Loop

这一阶段更像审稿视角下的收尾和补强：

- baseline 公平性
- seeds 与方差
- ablation 是否真正隔离 novel component
- claim 是否和结果强度匹配
- 图表和表述是否会被 reviewer 一眼打穿

---

## 6. Research Wiki 如何嵌进惯导项目

如果这个项目会持续几周到几个月，建议尽早启用 `research-wiki`。

推荐方式：

1. 初始化：
   ```text
   /research-wiki init
   ```
2. 让 `/research-lit` 把惯导核心论文写入 `research-wiki/papers/`
3. 让 `/idea-creator` 在 ideation 前读取 `query_pack.md`
4. 把失败 idea 和失败实验也写回 wiki
5. 重新找方向或切新会话前，用：
   ```text
   /research-wiki query "inertial odometry"
   /research-wiki stats
   /research-wiki lint
   ```

对惯导这种长周期方向，wiki 的价值很实际：

- 避免反复重走无效 idea
- 保留失败实验与失效原因
- 把 gap、paper、idea、claim 连成可恢复的长期记忆

---

## 7. Meta Optimize 如何嵌进惯导项目

`meta-optimize` 不应该插在脆弱训练过程的中间。

更合适的时机是：

- 跑完一条完整 `/research-pipeline`
- `auto-review-loop` 反复卡在同一类意见
- `deep-innovation-loop` 连续多轮 plateau
- 论文或 rebuttal 阶段反复暴露同类 harness friction

典型调用：

```text
/meta-optimize "research-pipeline"
/meta-optimize "deep-innovation-loop"
/meta-optimize "paper-writing"
```

它分析的重点证据应该是：

- `AUTO_REVIEW.md`
- `innovation-logs/`
- `refine-logs/`
- `findings.md`
- `paper/`
- `CODEX.md`

只有在你明确 `apply` 时，才让它修改 harness。

---

## 8. 远程训练与监控

惯导项目通常需要远程 GPU。

最小使用路径：

```text
/experiment-bridge "refine-logs/EXPERIMENT_PLAN.md"
/run-experiment "python train.py ..."
/monitor-experiment "io-server"
```

如果是过夜训练，建议在服务器启动 watchdog：

```bash
screen -dmS watchdog python3 tools/watchdog.py
```

它能帮助你更早发现：

- session 死掉
- GPU 空闲
- 下载停滞

---

## 9. 会话恢复

不管项目进行到哪一步，都把 `CODEX.md` 里的 `## Pipeline Status` 当成第一恢复入口。

惯导项目里推荐写到这个粒度：

```yaml
## Pipeline Status
stage: training
idea: "bias-aware long-horizon inertial odometry"
contract: docs/research_contract.md
current_branch: feature/io-bias-aware
baseline: "AIR-IO on OxIOD"
training_status: running on io-server, gpu 0-1, tmux=train01
active_tasks:
  - "exp01 on io-server"
next: collect results and decide deep innovation gate
```

至少在这些时刻更新：

- 选定或切换 idea
- 启动或结束训练
- 进入 `deep-innovation-loop`
- 进入 `auto-review-loop`
- 准备切会话之前

---

## 10. 最短可执行路径

如果你只是想尽快在惯导课题上把主线跑起来，按这个顺序：

1. 安装 ARIS 主线
2. 在项目里写 `CODEX.md`
3. 补一份 `RESEARCH_BRIEF.md`
4. 跑 `/idea-discovery`
5. 跑 `/experiment-bridge`
6. 跑首轮实验
7. 让主线判断是否进入 `deep-innovation-loop`
8. 用 `/auto-review-loop` 收尾
9. 有叙事后进入 `/paper-writing`

如果你要看主线本身的维护说明，回到：

- [`README_CN.md`](../README_CN.md)
- [`docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md`](CODEX_CLAUDE_REVIEW_GUIDE_CN.md)
- [`docs/CODEX_MAINLINE_PARITY_RULES_CN.md`](CODEX_MAINLINE_PARITY_RULES_CN.md)
