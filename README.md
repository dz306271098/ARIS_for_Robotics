# ARIS — Auto-claude-code-research-in-sleep

![ARIS Logo](docs/aris_logo.svg)

> 让 Claude Code 在你睡觉时做科研。醒来发现论文已被打分、弱点已被定位、实验已跑完、叙事已重写——全自动。

**ARIS** 是一套基于 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 的纯 Markdown 技能（Skills），用于自主 ML 科研工作流。核心机制是**跨模型对抗协作**——Claude Code 负责执行（读文件、写代码、跑实验、收结果），GPT-5.4（通过 [Codex CLI](https://github.com/openai/codex)）负责评审（打分、找弱点、建议修复）。两个模型互不评自己的作业，形成真正的反馈循环。

**极致轻量——零依赖，零锁定。** 整个系统就是纯 Markdown 文件。没有框架要学、没有数据库要维护、没有 Docker 要配。每个 skill 就是一个 `SKILL.md`，任何 LLM 都能读懂。

> 👤 **人类读者**：[SKILLS_GUIDE.md](SKILLS_GUIDE.md) 是按主题分组的技能速查手册，回答"我要写论文用哪个 skill？我要复现实验用哪个？"
> 📘 **AI agent 读者**：[AGENT_GUIDE.md](AGENT_GUIDE.md) 是 agent 视角的路由索引，本 README 面向人类读者。

---

## 目录

- [安装](#安装)
- [使用说明](#使用说明)
- [用例展示](#用例展示)
- [替代模型组合](#替代模型组合)
- [全部技能一览](#全部技能一览)
- [许可证与引用](#许可证与引用)

---

## 安装

### 前置条件

| 工具 | 最低版本 | 用途 | 安装方式 |
|------|---------|------|---------|
| **Node.js** | 18+ | Claude Code 和 Codex CLI 的运行环境 | [nodejs.org](https://nodejs.org) |
| **Claude Code** | 最新版 | 主执行引擎（CLI / Desktop / Web 均可） | `npm install -g @anthropic-ai/claude-code` |
| **Codex CLI** | 最新版 | GPT-5.4 评审通道 | `npm install -g @openai/codex` |
| **Python** | 3.10+ | 工具脚本（文献检索、图表渲染等） | 系统自带或 `apt install python3` |

**API Key 需求：**

| Key | 用途 | 必需？ | 获取方式 |
|-----|------|--------|---------|
| `ANTHROPIC_API_KEY` | Claude Code 执行 | 是 | [console.anthropic.com](https://console.anthropic.com) |
| `OPENAI_API_KEY` | Codex CLI / GPT-5.4 评审 | 是（评审类 skill 需要） | [platform.openai.com](https://platform.openai.com) |
| `EXA_API_KEY` | Exa AI 网络搜索（`/exa-search`） | 否（可选） | [exa.ai](https://exa.ai) |
| `SEMANTIC_SCHOLAR_API_KEY` | Semantic Scholar 高级查询 | 否（无 key 也能用，有 key 速率更高） | [api.semanticscholar.org](https://api.semanticscholar.org) |
| `GEMINI_API_KEY` | AI 作图（`/paper-illustration`） | 否（仅 AI 作图需要） | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| `OPENAI_API_KEY` | Oracle MCP（GPT-5.4 Pro 评审，`— reviewer: oracle-pro`） | 否（可选更强评审） | [platform.openai.com](https://platform.openai.com) |

### 第一步：克隆仓库并安装 Skills

**推荐方式：使用 `install_aris.sh`（符号链接 + 清单追踪，可安全卸载/更新）：**

```bash
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git
cd Auto-claude-code-research-in-sleep

# 全局安装（默认）— 所有 Claude Code 项目可见
bash tools/install_aris.sh

# 或项目级安装
bash tools/install_aris.sh --project /path/to/your/project

# 预览安装计划而不实际写入
bash tools/install_aris.sh --dry-run
```

`install_aris.sh` 把每个 skill 以符号链接（Linux/macOS）或 junction（Windows，见下文 PowerShell 版本）链接到仓库，`git pull` 后 skill 自动更新——无需再次运行 cp。它记录清单到 `~/.claude/.aris/installed-skills.txt`，卸载时只删自己创建的链接，绝不动用户文件。

**13 条安全规则**（S1–S13）：
- S1 不删除非链接路径；S2 不删除指向仓库外的链接；S4 不覆盖已存在的真实目录
- S5 清单原子写入；S6 并发锁；S8 卸载前重新验证链接目标；S11 突变前 lstat 验证
- S13 skill 名必须匹配 `^[A-Za-z0-9][A-Za-z0-9._-]*$`

**卸载**：

```bash
bash tools/uninstall_aris.sh                # 卸载全局安装
bash tools/uninstall_aris.sh --project PATH # 卸载项目级安装
bash tools/uninstall_aris.sh --dry-run      # 预览
```

**Windows 用户**：

```powershell
# 在 PowerShell 中
.\tools\install_aris.ps1                    # 全局安装
.\tools\install_aris.ps1 -Project C:\my-proj # 项目级
.\tools\install_aris.ps1 -Uninstall         # 卸载
```

使用 Windows junction（不需要管理员权限，与 Linux symlink 等价）。

**从旧版 `cp -r` 安装迁移**：

如果之前用 `cp -r .../skills/* ~/.claude/skills/` 手动安装过，现在想切换到符号链接安装：

```bash
bash tools/uninstall_aris.sh --global --archive-copy  # 把现有真实目录归档到 ~/.claude/skills.aris-backup-<ts>/
bash tools/install_aris.sh                            # 重新用符号链接安装
```

**简单方式（仍然支持）**：

```bash
cp -r skills/* ~/.claude/skills/
```

但建议用 `install_aris.sh`——它有清单追踪、安全卸载、以及 `--reconcile` 模式（跟上 ARIS 仓库新增/删除的 skill）。

<details>
<summary>安装成功输出示例（点开查看）</summary>

```
ARIS Install
  Mode:         global
  Install root: /home/user/.claude
  Skills dir:   /home/user/.claude/skills
  ARIS repo:    /home/user/.../Auto-claude-code-research-in-sleep
  Action:       auto

Plan summary:
  CREATE:        52  (new flat symlinks to add)
  ADOPT:         0   (orphan symlinks already pointing to correct target)
  UPDATE_TARGET: 0   (managed symlinks with stale target)
  REUSE:         0   (already correct, no-op)
  REMOVE:        0   (in old manifest, no longer upstream)
  CONFLICT:      0   (must be resolved before apply)

Apply these 52 changes? y

Applying:
  + ablation-planner
  + alphaxiv
  + analyze-results
  + arxiv
  + auto-paper-improvement-loop
  ... (all 52 skills + shared-references)
  + citation-audit          ← v2.1
  + research-wiki           ← 6 entity types (v2)
  ...
  ✓ updated CLAUDE.md (ARIS managed block)  [project mode only]

✓ Install complete. 52 changes applied.
```

**安装后状态**：
- `~/.claude/skills/` 含 52 个符号链接 + `shared-references/` 目录链接
- `~/.claude/.aris/installed-skills.txt` 是清单文件（卸载 / 更新时的真相来源）
- `git pull` 在 ARIS 仓库后，所有 skill 自动更新（符号链接指向仓库内容）——无需再次运行 `install_aris.sh`

</details>

### 第二步：安装 Codex CLI + Plugin（评审通道）

ARIS 通过 Codex CLI 调用 GPT-5.4 做评审，通过 Codex Plugin 提供代码审查和深度诊断能力。**不需要** Codex MCP Server。

```bash
# 安装 Codex CLI
npm install -g @openai/codex

# 交互式配置（选择模型时选 gpt-5.4）
codex setup
```

**验证配置文件** `~/.codex/config.toml`：

```toml
model = "gpt-5.4"    # 推荐。其他可选：gpt-5.3-codex, o3
```

> 这个文件决定了 `codex exec` 使用的模型。

**ARIS 使用的三个工具（均不依赖 MCP）：**
- `codex exec` — Bash 命令，直接调用 GPT-5.4 做结构化评审
- `/codex:adversarial-review` — Codex Plugin 提供的代码审查 Skill
- `/codex:rescue` — Codex Plugin 提供的深度诊断 Skill

### 第三步：安装 Python 依赖（可选）

```bash
# 核心工具依赖
pip install arxiv requests

# Exa 网络搜索（需要 EXA_API_KEY）
pip install exa-py

# DeepXiv 渐进式论文阅读（可选）
pip install deepxiv-sdk

# 设置环境变量（按需）
export EXA_API_KEY="your-exa-key"
export SEMANTIC_SCHOLAR_API_KEY="your-ss-key"
```

### 第四步：配置 Oracle MCP（GPT-5.4 Pro 评审）

Oracle MCP 让 ARIS 调用 **GPT-5.4 Pro**——目前最强的评审模型。默认使用**浏览器模式**（通过 Chrome 中登录的 ChatGPT Pro 会话调用，无需 API Key）。

```bash
# 1. 安装 Oracle CLI + MCP
npm install -g @steipete/oracle

# 2. 注册到 Claude Code
claude mcp add oracle -s user -- oracle-mcp

# 3. 完全重启 Claude Code 会话（不只是 /mcp reconnect）

# 4. 浏览器模式（默认推荐）：
#    在 Chrome 中登录 ChatGPT Pro（https://chatgpt.com）
#    保持 Chrome 运行中，Oracle 自动使用浏览器会话
#    无需 API Key。每次调用约 2-4 分钟（GPT-5.4 Pro 思考时间较长）

# 5.（可选）API 模式（更快，适合多轮循环）：
#    export OPENAI_API_KEY="your-key"  # 需要有 GPT-5.4 Pro API 权限
```

**使用方式：** 在任何评审类 skill 后添加 `— reviewer: oracle-pro`：
```bash
/auto-review-loop "topic" — reviewer: oracle-pro          # 用 GPT-5.4 Pro 做评审
/proof-checker "paper/" — reviewer: oracle-pro             # 深度数学证明验证
/research-review "my approach" — reviewer: oracle-pro      # 最强批判性评审
/rebuttal "paper/ + reviews" — reviewer: oracle-pro        # 提交前压力测试
```

未安装 Oracle 时 `— reviewer: oracle-pro` 会静默回退到标准 `codex exec`，不影响任何功能。

### 第五步：配置 GPU 服务器（可选）

如果需要远程跑实验，在项目的 `CLAUDE.md` 中添加：

```markdown
## GPU Server
- host: your-server-hostname     # SSH 别名或 IP
- user: username                 # SSH 用户名
- gpu_dir: /data/experiments     # 远程实验目录
- conda_env: myenv               # conda 环境名
- gpu_ids: 0,1,2,3               # 可用 GPU 编号
```

ARIS 会自动：`rsync` 代码到服务器 → `screen` 启动实验 → 监控进度 → 收集结果。

**Vast.ai 按需租 GPU（可选）：**

```bash
pip install vastai
vastai set api-key YOUR_VAST_API_KEY
# 上传 SSH 公钥到 https://cloud.vast.ai/manage-keys/
```

配置好后，`/run-experiment` 和 `/vast-gpu` 会自动检测并使用 Vast.ai 实例。

### 验证安装

```bash
claude
> /research-lit "transformer attention mechanisms"
```

如果能返回文献搜索结果，说明安装成功。如果 `codex exec` 报错，检查第二步的 Codex CLI 配置。

### 常见问题

| 问题 | 解决方案 |
|------|---------|
| `codex: command not found` | `npm install -g @openai/codex` |
| `codex exec` 报错 | 确认 `npm install -g @openai/codex` 已安装，`codex setup` 已配置，`~/.codex/config.toml` 中 model = "gpt-5.4" |
| 文献搜索超时 | 检查网络连接；API 工具和 WebSearch 会并行运行，一个超时不影响另一个 |
| GPU 实验部署失败 | 确认 `CLAUDE.md` 中的 SSH 配置正确，`ssh your-server` 能免密登录 |
| LaTeX 编译失败 | 安装 `texlive-full`：`apt install texlive-full latexmk` |
| `HALT: Feedback Verification missing for Round N` | 评审已跑但每条 finding 的 verdict 表缺失。打开 `AUTO_REVIEW.md`（或 `PAPER_IMPROVEMENT_LOG.md`），在 `## Round N — Feedback Verification` 下补齐每条 finding 的 Verdict / Action / Reasoning 列。不想人工介入可删除 `REVIEW_STATE.json` 让当前轮重跑 |
| `HALT: Trajectory Reanalysis mandatory at checkpoint round N` | 轮次 15/30/45 是强制轨迹重审检查点。执行 `/codex:rescue --effort xhigh "..."` 或删除状态文件让本轮重跑 |
| 仲裁 JSON 格式错误（malformed adjudication） | v2 自动走保守回退：按 `finding_correct` 处理（采纳 reviewer 原意见），在 dispute 日志中标记 `[malformed → defaulting to reviewer]`。无需人工介入 |
| 首次运行 research-wiki 为空 | 正常现象。query_pack 的"latent principles / unresolved failures"段落为空时，工作流降级到纯文献 ideation，不会报错。随 `/research-lit` 多次运行 wiki 会自动累积 |
| `HALT: Hypothesis Sparring section missing for Round N` (N≥2) | Round 2+ 前必须做假设切磋。确认 `AUTO_REVIEW.md` 有 `## Round N — Hypothesis Sparring` 段落；若只想跳过这一步，删除 `REVIEW_STATE.json` 从 Round 1 重跑 |
| `install_aris.sh` 报告 52 个 `CONFLICT: real_path` | 说明 `~/.claude/skills/` 下已有真实目录（旧的 `cp -r` 安装）。运行 `bash tools/uninstall_aris.sh --global --archive-copy` 把它们归档到 `~/.claude/skills.aris-backup-<ts>/`，然后重新运行 `install_aris.sh` |
| `install_aris.sh` 报 S9 错误 | `.aris/` 或 `.claude/skills/` 本身是符号链接——为安全起见拒绝安装。删除或重命名该链接再重试 |
| 另一个 install_aris 正在运行 | 锁文件 `.aris/.install.lock.d/` 阻塞。若确定无其他进程：`bash tools/install_aris.sh --clear-stale-lock` |
| `paper-writing` 报 `HALT: verify_paper_audits.sh exit 1` | 一个或多个审计 verdict 是 FAIL/BLOCKED/ERROR/STALE。查看 `paper/.aris/audit-verifier-report.json` 的 `details` 定位具体审计；修好后重跑对应审计 skill（如 `/citation-audit paper/`），然后重新生成 Final Report |

### 新增 HALT 消息速查（v2 / v2.1）

所有 HALT 消息的一览表（源于"没有静默跳过"的硬强制门）：

| HALT 消息 | 触发阶段 | 根本原因 | 修复步骤 |
|-----------|----------|----------|----------|
| `Feedback Verification missing for Round N` | auto-review-loop Phase B · auto-paper-improvement-loop Step 2.5 | 每条 finding 的 verdict 表未写入 | 在 `AUTO_REVIEW.md` / `PAPER_IMPROVEMENT_LOG.md` 补齐 `## Round N — Feedback Verification` 表（`Agree/Partially agree/Disagree/Need more info`） |
| `Hypothesis Sparring section missing for Round N` (N ≥ 2) | auto-review-loop Phase A | Round 2+ 前必须做 ≥ 3 竞争性根因假设 | 补齐 `## Round N — Hypothesis Sparring` 段落，或删 `REVIEW_STATE.json` 从 Round 1 重跑 |
| `Trajectory Reanalysis mandatory at checkpoint round N` | deep-innovation-loop Phase E Step 2.9 | 轮次 15/30/45 强制轨迹重审缺文件 | 运行 `/codex:rescue` 做 trajectory reanalysis，写 `TRAJECTORY_REANALYSIS_CHECKPOINT_{N}.md` |
| `Assumption Attack required after convergent diagnosis` | deep-innovation-loop Phase A.5 | 诊断收敛后必须攻击隐含假设 | 写 `round-N/assumption-attack.md` |
| `verify_paper_audits.sh exit 1` | paper-writing Phase 6 | 至少一个审计 verdict 是 FAIL/BLOCKED/ERROR/STALE | 查看 `paper/.aris/audit-verifier-report.json` 的 `details` → 重跑对应审计 skill |
| `S4 violation: ... appeared between plan and apply` | install_aris.sh | 并发修改；另一个进程在写同一路径 | 重跑 `install_aris.sh` |
| `S9: ... is a symlink` | install_aris.sh | `.aris/` 或 `.claude/skills/` 本身是符号链接 | 删除或重命名该链接再重试 |
| `Review output missing or empty` | 任何评审类 skill Phase A | `codex exec --output-schema` 产物缺失/空 | 检查 Codex CLI 是否报错；若是网络超时重跑该 Phase |

---

## 使用说明

### 工作流总览

ARIS 的 66 个技能组成完整科研流水线（其中 v2.2 新增 14 个 cpp-* / ros2-* / cuda-* / complexity-claim-audit / tensorrt-engine-audit）。六个工作流可以单独使用，也可以串联：

```
/research-lit → /idea-creator → /novelty-check → /research-refine → /experiment-bridge → /auto-review-loop → /paper-writing → /rebuttal
  (调研文献)      (找idea)       (查新验证)      (打磨方案)      (实现+部署)       (自动改到能投)     (论文写作)     (答复审稿)
  ├──────────── 工作流 1：Idea 发现 ────────────┤ ├─ 工作流 1.5 ─┤ ├── 工作流 2 ──┤ ├─ 工作流 3 ─┤ ├─ 工作流 4 ─┤
```

一键全流程：`/research-pipeline "研究方向"` 自动串联工作流 1 → 1.5 → 2 → 3。

---

### 创新能力与跨项目学习（v2 增强）

ARIS v2 将创新能力从"自由式 brainstorming"升级为**结构化的四环抽象链**——所有 workflow 围绕这四环联动，共享一个持久化的 `research-wiki/`：

> **论文方法 → 可迁移原理 → 跨域类比 → 失败反模式**

#### 1. 原理提取（5 层协议 · `shared-references/principle-extraction.md`）

`/research-lit` Step 2 对 top 5-8 篇论文强制执行：**表层方法 → 底层原理 → 泛化形式 → 适配 → 反复制守则**。提取结果持久化到 `research-wiki/principles/<slug>.md`。**原理是跨项目的**——A 项目提炼的原理在 B 项目可查询复用。

#### 2. 发散思维（5 算子 · `shared-references/divergent-techniques.md`）

- **SCAMPER** — 对种子 idea 做 7 种结构化变异
- **形态矩阵** — `[维度 A] × [维度 B] × [维度 C]` 强制覆盖 idea 空间
- **反转算子** — 当诊断收敛时，测试相反假设
- **跨域跳跃** — 从物理/生物/经济学/信号处理等**远域**借用原理（不是邻域）
- **约束放松** — 质疑问题的前提约束

触发：`/idea-creator` Phase 2.5（每次运行，idea 池从 8-12 扩到 20-30）；`deep-innovation-loop` **LEAP rounds** {10, 20, 30}（Phase C）+ **Cross-Domain rounds** {7, 14, 21, 28, 35, 42}（Phase B 替换）；`-- reviewer-role: lateral` 模式。

#### 3. 假设质疑与重构（`shared-references/hypothesis-sparring.md` + `reframing-triggers.md`）

- **假设切磋** — 每轮 Phase A 强制生成 **≥3 个竞争性根因假设**（权重 ≤ 0.6 防过早收敛）+ 最便宜证伪测试。先跑最便宜的 falsifier，再花训练预算。
- **假设攻击** — 协作重分析**收敛**时触发（危险区），攻击诊断中的隐含前提
- **问题重构** — 宏观阶段转换前触发，返回 3 种 reframing 标签：`metric` / `decomposition` / `family`（可改变成功度量、问题分解或方法族）
- **轨迹重审** — Round {15, 30, 45} 自动触发，diff 当前赢家 vs Round 0 承诺，提出 branch-reset 候选

#### 4. 失败反模式（5 层协议 · `shared-references/failure-extraction.md` · **v2 新增闭环**）

`research-wiki/` 现在有 **6 种一等实体**：paper / idea / exp / claim / **principle** / **failure-pattern**。每次 `/research-lit` 同步提取原理 + 失败模式（同一次 Codex call，零额外开销）。

| 触发位置 | 做什么 |
|---------|--------|
| `/idea-creator` Phase 0 | query_pack 的"Top unresolved failures"作为最锐利 ideation 种子（"反复被尝试、无人解决"比"没人试过"信号更强） |
| `/idea-creator` Phase 4 | devil's-advocate 查询失败库，标记 HIGH-RISK（≥ 2 原理共享失败模式且在 ≥ 2 过往 idea 中共现） |
| `/novelty-check` Phase B.5 | 交叉检查"surface-novel but semantically a known failure"——新增 `SEMANTICALLY REDUNDANT` verdict |
| `deep-innovation-loop` Phase C | 对抗挑战前列出变体原理的已知失败，要求 variant 给出"如何避开 failure trigger"的具体机制 |
| `auto-review-loop` Phase C.5.1 | 先查 wiki 失败库（确定性 < 5s），再降级到外部文献搜索；回写到 wiki 形成学习闭环 |
| `experiment-bridge` / `result-to-claim` / `deep-innovation-loop` Phase E | 负面/机制性失败自动持久化为新 failure-pattern → 跨项目记忆 |

`/research-wiki audit` 生成 4 项分析：**矛盾** / **趋势** / **原理覆盖** / **未解决失败**（后者直接作为 ideation 种子）。

#### 5. 评审者角色轴（`-- reviewer-role` · 与评审通道正交）

| 角色 | 做什么 | 触发 |
|------|--------|------|
| `adversarial`（默认） | 打分 + 找弱点 + 建议修复 | 默认所有评审 |
| `collaborative` | 联合设计（Claude + GPT-5.4 共同问题求解） | `/auto-review-loop` 卡住 2+ 轮自动切换 |
| `lateral` | 2 个重构 + 1 个跨域类比（不打分、不批评） | plateau 时自动；手动 `-- reviewer-role: lateral` |

与 `-- reviewer:`（通道：codex / rescue / adversarial / oracle-pro）正交。示例：`-- reviewer: oracle-pro — reviewer-role: lateral` = GPT-5.4 Pro 做侧向重构。

---

### 执行强制性与审计（v2 强化 · 解决"评审会不会被跳过？"）

**用户关切**：如果 skill 说"调用 GPT-5.4 评审"，Claude 会真的执行吗？评审返回后会真的被分析吗？分歧点真的会多轮讨论吗？还是被"我已审阅，都合理"一句话带过？

**v2 的回答**：所有关键环节都有**五层强制机制**，Claude 无法静默绕过。

#### 机制 1 — 逐条评估（Per-Finding Verification）

评审返回后，**每一条 finding 都必须分配 verdict**（不是"如果 Claude 有异议"才评估）：

| Verdict | 含义 | 行动 |
|---------|------|------|
| `Agree` | 发现正确 | 接受并修复 |
| `Partially agree` | 诊断对但修复建议不合适 | 采纳诊断，提出替代修复 |
| `Disagree` | 发现不对（需带证据） | 进入机制 3 争议流程 |
| `Need more info` | 无法判定 | 进入机制 3 请求澄清 |

#### 机制 2 — 证据质量门（Evidence Quality Gate）

`Disagree` verdict 必须带 **file:line 引用 + 具体数据/日志片段**。空谈式反对（"我觉得这个发现不对"无证据）在提交 `/codex:rescue` 前就被**自动降级**为 `Rejected rebuttal — insufficient evidence`（按 reviewer 意见接受 finding）。这防止 Claude 用"分析过了"敷衍掉争议。

#### 机制 3 — 结构化多轮争议（Structured Multi-Turn Dispute）

争议提交给 `/codex:rescue` 时**必须返回结构化 JSON**：

```json
{
  "verdict": "finding_correct" | "rebuttal_valid" | "compromise_needed",
  "evidence": "具体 file:line 或数字",
  "reasoning": "一段解释",
  "compromise_proposal": "如需妥协则具体化，否则 null"
}
```

- 每个 finding 最多 **3 轮**仲裁（防止无限 ping-pong）
- 第 3 轮仍未收敛 → `UNRESOLVED DISPUTE — conservative fallback`（保守采纳 reviewer）
- JSON 格式错误 → 默认当作 `finding_correct`（保守）
- 每轮 JSON 持久化到 `.aris/disputes/round-${N}-F${id}-round-${R}.json`

#### 机制 4 — 跨轮自动升级（Cross-Round Auto-Escalation）

如果某个 finding 在 Round N 被 `Disputed → Rebuttal accepted`，但 Round N+1 reviewer 再次提出同一 finding（语义匹配），**自动切换到 `-- reviewer-role: collaborative`** 联合设计——两个独立评审都认为是问题的事，不再用对抗模式继续拉锯。

#### 机制 5 — HALT-IF-MISSING 门（文件级强制）

工作流在关键节点检查所需产出文件是否存在；缺失则**立即停止**，不做静默降级：

| 检查点 | Skill | 必须存在的文件 |
|--------|-------|---------------|
| Phase C 启动前 | auto-review-loop | `## Round N — Feedback Verification` 表格（AUTO_REVIEW.md） |
| Phase B/C 启动前 | deep-innovation-loop | `round-N/hypothesis-sparring.md`、`diagnosis.md`；收敛时还要 `assumption-attack.md` |
| 轮次 15/30/45 后 | deep-innovation-loop | `TRAJECTORY_REANALYSIS_CHECKPOINT_${N}.md` |
| Phase E Step 3 前 | deep-innovation-loop | `round-N/failure-analysis-verdict.json`（Step 2.7 产出） |
| Phase E 记分前 | auto-review-loop | `/tmp/aris-fix-validation-round-N.json`（PASS/FAIL verdict） |
| Step 3 修复前 | auto-paper-improvement-loop | `## Round N — Feedback Verification` 表格 |

因基础设施故障（网络/磁盘）导致门未通过时，记录为 `[INFRASTRUCTURE_DEGRADATION]` 走记录在案的降级路径。**绝不因"Claude 忘了跑 review"走降级**。

#### 审计产物（每次运行后可溯源）

| 路径 | 内容 |
|------|------|
| `AUTO_REVIEW.md` `## Round N — Feedback Verification` | 每条 finding 的 verdict + 争议轮数 + 行动 + 证据 |
| `.aris/disputes/round-${N}-F${id}-round-${R}.json` | 每轮争议的 GPT-5.4 仲裁 JSON |
| `.aris/traces/<skill>/<date>_run<NN>/` | 完整评审 prompt + 响应存档 |
| `REVIEW_STATE.json` → `findings[]` | 每条 finding 的 `dispute_rounds` 与 `final_verdict`（状态持久化，断点续跑时可继续争议） |
| `innovation-logs/round-N/assumption-attack.md` | 诊断收敛时的隐含假设攻击结果 |
| `innovation-logs/TRAJECTORY_REANALYSIS_CHECKPOINT_${N}.md` | 轮次 15/30/45 轨迹重审输出 |
| `PAPER_IMPROVEMENT_STATE.json` → `findings[]` | 论文修复的 finding 级状态（与 REVIEW_STATE.json 同构） |

**如何审计**：查看 AUTO_REVIEW.md 的 Feedback Verification 表格即可看到每条评审意见的处理轨迹——同意/反驳/妥协/未决——以及对应证据链接。`.aris/disputes/` 下的 JSON 是每次多轮讨论的完整留痕。

#### 集成矩阵（哪些 skill 触发哪些机制）

| Skill | Per-Finding | 证据门 | 结构化争议 | 跨轮升级 | HALT 门 |
|-------|:-----------:|:-----:|:---------:|:-------:|:------:|
| auto-review-loop | ✓ | ✓ | ✓ | ✓ | ✓ |
| deep-innovation-loop | ✓ | ✓ | ✓ | — | ✓ |
| auto-paper-improvement-loop | ✓（v2 新加） | ✓ | ✓ | ✓ | ✓ |
| experiment-bridge | ✓ | ✓ | ✓ | — | ✓ |
| result-to-claim | ✓ | ✓ | ✓ | — | — |

完整协议：`skills/shared-references/codex-context-integrity.md` "Review Feedback Verification Protocol" + "Execution Enforcement Gates" 两章。

---

### 审计合规与外部验证（v2.1 强化 · "审计真的跑了吗？"）

上一节解决的是**评审反馈层面**（reviewer 说 X，Claude 真的评估了 X 吗？）。这一节解决的是**审计合规层面**（审计本身真的跑了吗？产出是否仍然有效？）。两层协议正交，组合起来消除所有已知 silent-skip 漏洞。

#### 两个新的架构契约

**1. `integration-contract.md`**（架构契约 · 每个跨 skill 集成必须满足 6 个组件）：

| # | 组件 | 含义 | 示例 |
|---|------|------|------|
| 1 | 激活谓词 | 一行从 LLM 外部可观测的条件 | `if [ -d research-wiki/ ]` |
| 2 | 规范助手 | 业务逻辑只存在一处，不复制粘贴 | `python3 tools/research_wiki.py ingest_paper` |
| 3 | 具体产物 | 成功执行留下文件、JSON 记录或日志行 | `paper/CITATION_AUDIT.json` |
| 4 | 可见清单 | 长工作流起点渲染 checkbox 块 | Phase 6 pre-flight 清单 |
| 5 | 补救命令 | 没触发时用户能手动回填 | `sync --arxiv-ids ...` |
| 6 | 验证脚本 | 失败会损害研究结果时用外部进程 + exit code | `verify_paper_audits.sh` |

**2. `assurance-contract.md`**（审计严格度的正交轴，与 `effort` 分开）：

| 轴 | 控制 | 默认 |
|----|------|------|
| `effort` | 深度 / 成本（论文数、轮数、idea 数） | `balanced` |
| `assurance` | 审计严格度（允许静默跳过 vs 必须发 verdict） | 由 `effort` 推导：`max`/`beast` → `submission`，其他 → `draft` |

**6-verdict 状态机**（每个强制审计必须发且仅发一个）：

| Verdict | 含义 | 审计跑了？ | submission 级别阻断？ |
|---------|------|-----------|----------------------|
| `PASS` | 所有检查通过 | 是 | 否 |
| `WARN` | 有问题但不阻断 | 是 | 否 |
| `FAIL` | 有阻断级问题 | 是 | **是** |
| `NOT_APPLICABLE` | 探测器返回负，但写了产物文件记录"检查过无内容" | 是 | 否 |
| `BLOCKED` | 应该审但前置条件缺失（如有数字声明但无原始数据） | 未完成 | **是** |
| `ERROR` | 审计调用失败（网络 / 超时 / 格式错误） | 尝试过但报错 | **是** |

关键区分：`NOT_APPLICABLE` 不等于 `SKIP`——前者留下可审计的产物文件，后者什么都没留下。过去 `effort: beast` 的 silent-skip 漏洞恰恰混淆了这两种情况。

**默认映射**（不显式传 `assurance` 时）：`lite`/`balanced` → `draft`，`max`/`beast` → `submission`。独立覆盖合法：`— effort: balanced, assurance: submission` 表示"常规深度但每个审计都必须发 verdict"。

#### 新增：`/citation-audit` skill

补齐第四层审计（引用整合度）。现在 paper-writing 有四层审计栈：

| 审计 | 检查什么 | 抓什么错 |
|------|----------|----------|
| `/experiment-audit` | 评估代码 | 假 ground truth、自归一化分数、虚构结果 |
| `/result-to-claim` | 结果到声明映射 | 证据不支撑的声明 |
| `/paper-claim-audit` | 论文中的数字声明 | 数字夸大、best-seed cherry-pick、配置不符 |
| `/citation-audit`（**v2.1 新**） | 参考文献 | **错误上下文引用**（最危险）、幻觉作者、年份漂移、DOI 假 |

最危险的引用问题不是"胡编的引用"（容易发现），而是"**真实论文用在错误上下文**"（例：引用 Self-Refine 支持"自反馈产生相关错误"——Self-Refine 实际论证的是迭代改进，恰恰相反）。`/citation-audit` 对每条 bib entry 走三轴验证（存在性 / 元数据 / 上下文）+ Web/DBLP/arXiv 查询。

#### 新增：外部验证脚本（exit code = 真相）

```bash
# 审计合规验证（paper-writing Phase 6 自动调用）
bash tools/verify_paper_audits.sh paper/ --assurance submission
# exit 0 = 3 个 JSON 产物齐全、schema 有效、hash 新鲜、无 FAIL/BLOCKED/ERROR
# exit 1 = 任何阻断项，Final Report 拒绝生成

# wiki 覆盖诊断（非阻断，只报告）
bash tools/verify_wiki_coverage.sh research-wiki/
# 扫描 .aris/traces/、paper/、references.bib，找出被引但未入库的 arXiv ID
```

**STALE 检测**：每个审计 JSON 携带 `audited_input_hashes`（被审文件的 SHA256）。用户编辑了 `sections/5.evidence.tex` 后重跑 verifier → hash 不符 → `STALE` 标记 → 拒绝 Final Report，强制重跑相关审计。

#### 规范助手：research_wiki.py 升级

`tools/research_wiki.py` 现在是所有 paper-reading skill 的规范入口（integration-contract §2）：

```bash
# 规范 paper ingest（每个 paper-reading skill 统一调用）
python3 tools/research_wiki.py ingest_paper research-wiki/ --arxiv-id 2501.12345

# 批量回填（integration-contract §5 补救命令）
python3 tools/research_wiki.py sync research-wiki/ --arxiv-ids id1,id2,id3

# ARIS v2 专属：持久化 principle + failure-pattern 实体
python3 tools/research_wiki.py upsert_principle research-wiki/ <slug> \
    --from paper:<slug> --name "..." --generalized "..."
python3 tools/research_wiki.py upsert_failure_pattern research-wiki/ <slug> \
    --from paper:<slug> --name "..." --generalized "..." \
    --affects-principles a,b --resolved-by-principles c,d
```

`/arxiv`、`/alphaxiv`、`/deepxiv`、`/exa-search`、`/semantic-scholar`、`/research-lit` 统统委托这个 helper，不再手写 page creation。避免 schema 漂移 + 解决了"wiki 是个墓碑（从没被填充过）"的老 bug。

---

### 工作流 1：Idea 发现（`/idea-discovery`）

```bash
/idea-discovery "tactile feedback for robotic manipulation"
```

**阶段：**
1. 文献调研（100+ 篇，arXiv + Semantic Scholar + Exa + WebSearch 并行）
2. 头脑风暴 8-12 个 idea（GPT-5.4 xhigh）
3. 初筛可行性 + 快速查新
4. Top idea 深度验证（完整查新 + devil's advocate review）
5. 并行 pilot 实验（top 2-3 个 idea，30 分钟 - 2 小时/个）
6. 按实验信号排名
7. 精炼方案（GPT-5.4 迭代 review，直到分数 >= 9/10）
8. 生成 claim-driven 实验路线图

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `AUTO_PROCEED` | `true` | 自动选择 top idea。设 `false` 在选择关卡暂停 |
| `ref paper` | — | 参考论文（arXiv URL 或本地 PDF 路径） |
| `base repo` | — | 基础代码 GitHub URL |
| `effort` | `balanced` | 工作强度（见下方 effort 说明） |
| `PILOT_MAX_HOURS` | `2` | 跳过预估 > 2 小时的 pilot |
| `MAX_TOTAL_GPU_HOURS` | `8` | 所有 pilot 的 GPU 总预算 |
| `arxiv download` | `false` | 下载最相关的 arXiv PDF |

**输入文件（可选）：** 在项目根目录放一个 `RESEARCH_BRIEF.md`（[模板](templates/RESEARCH_BRIEF_TEMPLATE.md)）���写清研究背景、约束条件、已尝试方法。比一句话 prompt 能提供更多上下文。

**输出文件：**
- `IDEA_REPORT.md` — 所有 idea 排名 + pilot 实验结果
- `refine-logs/FINAL_PROPOSAL.md` — 精炼后的方案
- `refine-logs/EXPERIMENT_PLAN.md` — 实验路线图

---

### 工作流 1.5：实验桥接（`/experiment-bridge`）

```bash
/experiment-bridge
```

**阶段：**
1. 解析实验计划（`refine-logs/EXPERIMENT_PLAN.md`）
2. 实现实验代码（复用已有代码，加 argparse/logging/seed）
3. GPT-5.4 代码审查 — 在浪费 GPU 前抓逻辑 bug
4. Experiment integrity 审计（`/experiment-audit`）
5. Sanity check — 先跑最小实验，发现运行时 bug
6. 部署完整实验到 GPU（`/run-experiment`）
7. 收集初始结果

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `code review` | `true` | GPT-5.4 部署前审查代码 |
| `base repo` | — | GitHub 仓库 URL，克隆作为基础代码 |
| `BASELINE_COMPARISON` | — | 基线名称（如 "DAgger"），自动生成 delta 对比表 |

**输入文件：** `refine-logs/EXPERIMENT_PLAN.md`（最佳）或 `IDEA_CANDIDATES.md`

---

### 工作流 2：自动评审循环（`/auto-review-loop`）

```bash
/auto-review-loop "tactile grasping optimization" — venue: RAL
```

GPT-5.4 以目标 venue 审稿人标准打分（5 维度 × 10 分），指出弱点，Claude Code 自动修复并重新跑实验，循环直到通过。

**阶段（每轮）：**
1. **Phase A** — GPT-5.4 独立评审（读取项目文件，5 维度打分）；Round 2+ 前先做 Hypothesis Sparring（≥3 个竞争性根因假设）
2. **Phase B** — 解析弱点 + **强制 Feedback Verification**（每条 finding 逐条给 verdict；空谈式反对被自动拒绝；必要时走多轮 `/codex:rescue` 仲裁 JSON 流程，最多 3 轮）
3. **Phase B.5** — 文献驱动的修复设计（先查 `research-wiki/principles/`，再外部搜索；提炼原理，设计 2-3 个修复策略）
4. **Phase C** — 实现修复 + 强制代码审查 + 多 seed 评估
5. **Phase C.5** — 修复验证（统计显著性 + 根因确认 + 独立验证；verdict 持久化到 `/tmp/aris-fix-validation-round-N.json`）
6. **Phase C.5.1** — Failure Archaeology（失败 2 次时先查 wiki 失败库 <5s，再降级到外部搜索；所有失败回写 wiki）
7. **Phase C.6** — Collaborative Escalation（全策略失败时联合设计 + Assumption Attack + Problem Reframing）
8. **Phase E** — 反思与文档记录（verification 表格 + dispute JSON 留痕）

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICLR` | 目标 venue，决定评分标准 |
| `max rounds` | `4` | 最大循环轮数 |
| `human checkpoint` | `false` | 每轮后暂停，可给修改意见 |
| `RESEARCH_DRIVEN_FIX` | `true` | 文献驱动修复（搜论文找原理，非直接修补） |
| `effort` | `balanced` | 工作强度 |
| `compact` | `false` | 使用精简日志文件 |

**Venue 评审标准：**

| Venue | 通过分数 | 特殊要求 |
|-------|---------|---------|
| RAL / TRO | >= 7/10 | 实验严谨度 >= 7 |
| ICRA | >= 7/10 | 技术可靠性 >= 7 |
| CVPR / ICCV | >= 7/10 | 新颖性 >= 7 |
| NeurIPS / ICML / ICLR | >= 7/10 | 无 BLOCKING 弱点 |

**输出文件：**
- `AUTO_REVIEW.md` — 累积评审日志（每轮打分 + 弱点 + 修复记录）
- `REVIEW_STATE.json` — 断点续跑状态文件

---

### 工作流 2+：深度创新循环（`/deep-innovation-loop`）

```bash
/deep-innovation-loop "improve manipulation baseline" — venue: RAL, baseline: DAgger
```

与普通评审循环不同，深度创新循环在 40+ 轮中驱动**方法本身的进化**：

**三阶段：**
- **探索期**（1-15 轮）— 大胆尝试新技术，宽搜索
- **精炼期**（16-30 轮）— 优化最佳变体，窄聚焦
- **打磨期**（31+ 轮）— 消融实验 + 鲁棒性测试

**每轮循环：** 诊断根因 → 搜索文献 → 创新设计 → 实现评估 → 反思学习

**每轮 Phase A 强制流程**：Hypothesis Sparring（≥3 竞争假设）→ 独立诊断 → 诊断收敛时自动触发 Assumption Attack（攻击隐含前提）。`patience_counter ≥ 3` 时额外触发 Collaborative Reanalysis。所有产物（`hypothesis-sparring.md`, `assumption-attack.md` 等）缺失则 HALT。

**轮次调度优先级**（避免混淆）：

| 轮次 | Phase B | Phase C | Phase E |
|-----|:-------:|:-------:|:-------:|
| 5, 25, 35, 45 | — | FUSION | — |
| 7, 14, 21, 28, 42 | CROSS_DOMAIN | — | — |
| 10, 20 | — | LEAP | — |
| 15, 45 | — | FUSION | TRAJECTORY |
| 30 | — | **LEAP**（LEAP 胜 FUSION） | TRAJECTORY |
| 35 | CROSS_DOMAIN | FUSION | — |

**规则**：Phase B 的 CROSS_DOMAIN 与 Phase C/E 无冲突；LEAP 在 {10,20,30} 覆盖 FUSION；TRAJECTORY 在 Phase E 独立运行（可与 LEAP/FUSION 在同轮共存）。

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `RAL` | 目标 venue |
| `DOMAIN` | `robotics` | 研究领域 |
| `PRIMARY_BASELINE` | （必填） | 基线名称（如 DAgger, RRT*, PointNet++） |
| `TARGET_SCORE` | `8` | 目标评审分数 |
| `MAX_ROUNDS` | `50` | 最大轮数 |
| `human checkpoint` | `false` | 诊断后暂停 |

**输出文件：**
- `innovation-logs/EVOLUTION_LOG.md` — 40+ 轮进化历史
- `innovation-logs/TECHNIQUE_LIBRARY.md` — 累积技术库

---

### 工作流 3：论文写作（`/paper-writing`）

```bash
/paper-writing "NARRATIVE_REPORT.md" — venue: ICRA
```

自动串联 5 个子技能 + 3 个验证门：

**Phase 0.5（前置，如果 `research-wiki/` 存在）** — 从 wiki 收集 positioning 素材：本方法体现的 principles + 避开/解决的 failure-patterns，写入 `NARRATIVE_REPORT.md` 的 `## Wiki-Sourced Positioning` 段落，作为 Related Work 与 Limitations 章节的先验素材。

1. **`/paper-plan`** — 生成大纲 + claims-evidence 矩阵
2. **`/paper-figure`** — 生成论文图表（matplotlib / AI 生成）
3. **`/paper-write`** — 逐章生成 LaTeX
   - 5-pass 科学写作审查（去废话 → 主动语态 → 句式优化 → 关键词一致性 → 数值引用完整性）
   - 定理一致性检查（主体 vs 附录的定理表述一致性）
   - DBLP/CrossRef 引用验证（杜绝幻觉引用）
4. **`/paper-compile`** — 编译 PDF + 自动修复格式
5. **`/auto-paper-improvement-loop`** — GPT-5.4 评审 ×2 轮
   - 偏见防护（每轮全新评审，不带前轮上下文）
   - **每轮强制 Feedback Verification**（v2 新加）：评审返回后对每条 finding 逐条给 verdict，必要时走结构化多轮争议；防止 Round 1 盲目实施所有意见引入回归（如 April 2026 NeurIPS 事件中的定理陈述漂移）
   - **跨轮自动升级**：Round 1 被 `Disputed → Rebuttal accepted` 的 finding 若在 Round 2 再次出现，自动切 `collaborative` 模式
   - 定理重述回归测试
   - Kill Argument Exercise（理论论文的对抗性攻防）
   - 位置感知格式检查（正文/附录/参考文献不同阈值）

**验证门（自动触发）：**
- Phase 4.5 — 如果有定理 → `/proof-checker` 验证（20 类问题分类法）
- Phase 4.7 — 如果有实验 → `/paper-claim-audit` 零上下文数字核对
- Phase 5.5 — **强制**最终 claim 审计（提交前必须通过）

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICLR` | 目标 venue（决定 LaTeX 模板和页数限制） |
| `effort` | `balanced` | 工作强度 |
| `illustration` | `gemini` | AI 作图模式：`gemini`/`mermaid`/`false` |
| `DBLP_BIBTEX` | `true` | 从 DBLP/CrossRef 获取真实 BibTeX |
| `human checkpoint` | `false` | 每轮审稿后暂停 |

**支持的 venue 模板：**

| Venue | 页数限制 | 参考文献算页数？ | 匿名？ |
|-------|---------|----------------|--------|
| ICLR / NeurIPS / ICML | 8-9 页 | 否 | 是 |
| CVPR / ICCV / ECCV | 8 页 | 否 | 是 |
| RAL | 8 页（6+2 超页费） | 是 | 否 |
| ICRA | 8 页 | 否 | 是 |
| IEEE Transactions | 12-14 页 | 是 | 否 |
| IEEE Conference | 5-8 页 | 是 | 否 |

**输入文件：** `NARRATIVE_REPORT.md`（[模板](templates/NARRATIVE_REPORT_TEMPLATE.md)），写清核心故事、声明、实验结果、图表描述。

**输出文件：** `paper/main.pdf` + 全部 LaTeX 源文件

---

### 工作流 4：Rebuttal（`/rebuttal`）

```bash
/rebuttal "paper/ + reviews.txt" — venue: ICML, character limit: 5000
```

**阶段：**
1. 解析审稿意见 → 原子化每个 concern
2. 制定回复策略（哪些接受、哪些反驳、哪些承认局限）
3. 起草 rebuttal（遵守字数限制）
4. 生成 `REVISION_PLAN.md`（每个修改承诺的追踪清单）
5. 三道安全检查 + GPT-5.4 压力测试
6. 定稿

**三道安全门：**
- **来源门** — 每句话有出处（论文/审稿意见/用户确认的结果），无出处则阻断
- **承诺门** — 每个修改承诺有状态（已完成/批准执行/仅标注未来工作），未批准则阻断
- **覆盖门** — 每个审稿意见都有回应，不允许遗漏

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICML` | 目标会议 |
| `character limit` | — | **必填。** 字符限制 |
| `quick mode` | `false` | 仅解析 + 策略（不起草，先看审稿人要什么） |
| `auto experiment` | `true` | 自动跑补充实验 |
| `max stress test rounds` | `1` | GPT-5.4 压力测试轮数 |

**输出文件：**
- `PASTE_READY.txt` — 精确字数，直接粘贴到投稿系统
- `REBUTTAL_DRAFT_rich.md` — 详细版，自己微调用
- `REVISION_PLAN.md` — 修改承诺追踪清单（逐条打勾）

---

### 全流程（`/research-pipeline`）

```bash
/research-pipeline "tactile feedback for robotic manipulation" — effort: max
```

串联工作流 1 → 1.5 → 2 → 3，一键从研究方向到投稿论文。

**参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `AUTO_PROCEED` | `true` | 自动继续。设 `false` 在 idea 选择关卡暂停 |
| `DEEP_INNOVATION` | `false` | 用深度创新循环（40+ 轮）替代标准评审循环 |
| `effort` | `balanced` | 工作强度（传递给所有子 skill） |
| `venue` | `ICLR` | 目标 venue |
| `ref paper` | — | 参考论文 URL |
| `base repo` | — | 基础代码 URL |

---

### Effort 工作强度

所有 skill 都支持 `— effort: lite | balanced | max | beast`：

| 维度 | lite (~0.4x) | balanced (1x) | max (~2.5x) | beast (~5-8x) |
|------|-------------|---------------|-------------|----------------|
| 文献检索 | 6-8 篇 | 10-15 篇 | 18-25 篇 | 40-50 篇 |
| Idea 生成 | 4-6 个 | 8-12 个 | 12-16 个 | 20-30 个 |
| Pilot 实验 | 1-2 个 | 2-3 个 | 3-4 个 | 5-6 个 |
| Review 轮数 | 2 轮 | 3-4 轮 | 6 轮 | 8+ 轮 |
| 论文写作 | 1 版摘要 | 标准 | 2 版摘要 + 深度 related work | 3 版摘要 + 穷尽 related work |

**不受 effort 影响的硬约束：** Codex 推理深度始终 xhigh、DBLP 引用验证始终开启、评审独立性始终开启、实验完整性审计始终开启。

---

### 参数总表

所有 skill 均支持内联参数 `— key: value`，多个参数逗号分隔：

```bash
/skill-name "args" — key1: value1, key2: value2
```

| 参数 | 默认 | 适用 skill | 说明 |
|------|------|-----------|------|
| `AUTO_PROCEED` | `true` | 全局 | 决策点自动继续 |
| `human checkpoint` | `false` | 全局 | 每轮评审后暂停 |
| `effort` | `balanced` | 全局 | 工作强度：lite / balanced / max / beast |
| `venue` | `ICLR` | 全局 | 目标 venue |
| `compact` | `false` | 全局 | 精简日志模式 |
| `ref paper` | — | idea-discovery, research-pipeline | 参考论文（PDF 或 arXiv URL） |
| `base repo` | — | experiment-bridge, research-pipeline | 基础代码 GitHub URL |
| `DBLP_BIBTEX` | `true` | paper-write | 从 DBLP/CrossRef 获取真实 BibTeX |
| `code review` | `true` | experiment-bridge | GPT-5.4 部署前代码审查 |
| `arxiv download` | `false` | research-lit, idea-discovery | 下载 arXiv PDF |
| `sources` | `all` | research-lit | 搜索源：zotero / local / web / semantic-scholar / all |
| `max rounds` | `4` | auto-review-loop | 最大评审轮数 |
| `illustration` | `gemini` | paper-writing | AI 作图：gemini / mermaid / false |
| `character limit` | — | rebuttal | **必填。** rebuttal 字符限制 |
| `quick mode` | `false` | rebuttal | 仅分析不起草 |
| `DEEP_INNOVATION` | `false` | research-pipeline | 用深度创新循环替代标准评审 |
| `PRIMARY_BASELINE` | — | deep-innovation-loop | **必填。** 基线名称 |
| `wandb` | `false` | experiment-bridge, run-experiment | W&B 日志 |
| `reviewer` | `codex` | 全评审类 | 评审通道：`codex` / `rescue` / `adversarial` / `oracle-pro` |
| `reviewer-role` | `adversarial` | 全评审类 | 评审角色（正交于通道）：`adversarial` / `collaborative` / `lateral` |
| `assurance` | 由 `effort` 推导 | paper-writing, 3 审计 skill | 审计严格度（正交于 `effort`）：`draft`（允许静默跳过）/ `submission`（每个审计必须发 verdict） |

---

### v2.1 正交参数轴速查

4 个**互相正交**的参数，可自由组合：

| 轴 | 取值 | 控制什么 | 默认 | 示例 |
|----|------|----------|------|------|
| `effort` | lite / balanced / max / beast | 深度 & 成本（文献数、轮数、idea 数） | `balanced` | `— effort: beast` |
| `assurance` | draft / submission | 审计严格度（`submission` 时每个审计必须发 verdict） | 由 `effort` 推导 | `— assurance: submission` |
| `reviewer` | codex / rescue / adversarial / oracle-pro | 评审**通道**（哪个 backend） | `codex` | `— reviewer: oracle-pro` |
| `reviewer-role` | adversarial / collaborative / lateral | 评审**角色**（prompt 模板） | `adversarial` | `— reviewer-role: lateral` |

**组合示例**：
```bash
/auto-review-loop "topic" — effort: max, reviewer: oracle-pro, reviewer-role: lateral, assurance: submission
```
= 最深度 + GPT-5.4 Pro 作为 reviewer + 侧向重构模式 + 强制审计发 verdict。

**`effort → assurance` 默认映射**：
| `effort` | 推导出的 `assurance` |
|----------|---------------------|
| `lite` | `draft` |
| `balanced`（默认） | `draft` |
| `max` | **`submission`** |
| `beast` | **`submission`** |

### research-wiki 节点类型速查

`research-wiki/` 是 6 种实体组成的图谱：

| 实体 | 目录 | Node ID 格式 | 由谁填充 |
|------|------|-------------|----------|
| paper | `papers/` | `paper:<slug>` | `/research-lit` Step 2；每个 paper-reading skill 通过 `ingest_paper` 委托 |
| idea | `ideas/` | `idea:<id>` | `/idea-creator` Phase 7 |
| experiment | `experiments/` | `exp:<id>` | `/run-experiment` + `/result-to-claim` |
| claim | `claims/` | `claim:<id>` | `/result-to-claim` |
| **principle** (v2) | `principles/` | `principle:<slug>` | `/research-lit` Step 2 强制 5 层原理提取；`deep-innovation-loop` Phase B |
| **failure-pattern** (v2) | `failures/` | `failure-pattern:<slug>` | `/research-lit` Step 2 同步抽取；`experiment-bridge` / `result-to-claim` 负面结果回写 |

**关系边类型**（`graph/edges.jsonl`）：

- v1：`extends`, `contradicts`, `addresses_gap`, `inspired_by`, `tested_by`, `supports`, `invalidates`, `supersedes`
- v2 原理：`embodies_principle`（paper→principle）, `shares_principle_with`（principle↔principle）
- v2 失败：`failure_mode_of`（failure→principle）, `manifested_as`（idea/exp→failure）, `resolved_by`（principle→failure）

---

### 模板文件

放在 [`templates/`](templates/) 目录，每个工作流都有对应的输入模板：

| 模板 | 用途 | 对应工作流 |
|------|------|-----------|
| [`RESEARCH_BRIEF_TEMPLATE.md`](templates/RESEARCH_BRIEF_TEMPLATE.md) | 研究背景、约束条件、已尝试方法 | 工作流 1 |
| [`EXPERIMENT_PLAN_TEMPLATE.md`](templates/EXPERIMENT_PLAN_TEMPLATE.md) | Claim-driven 实验计划 | 工作流 1.5 |
| [`NARRATIVE_REPORT_TEMPLATE.md`](templates/NARRATIVE_REPORT_TEMPLATE.md) | 核心故事、声明、实验结果 | 工作流 3 |
| [`PAPER_PLAN_TEMPLATE.md`](templates/PAPER_PLAN_TEMPLATE.md) | 论文大纲结构 | 工作流 3 |

> 将模板复制到项目根目录，填写后对应 skill 会自动检测。

---

### 项目文件结构

ARIS 运行后会在项目目录生成以下文件：

```
project/
├── CLAUDE.md                          # 项目配置（GPU 服务器、Pipeline 状态）
├── RESEARCH_BRIEF.md                  # 研究简报（可选输入）
├── IDEA_REPORT.md                     # Idea 排名报告
├── AUTO_REVIEW.md                     # 评审循环日志
├── REVIEW_STATE.json                  # 断点续跑状态
├── MANIFEST.md                        # 产出文件追踪清单
│
├── refine-logs/
│   ├── FINAL_PROPOSAL.md              # 精炼后的方案
│   ├── EXPERIMENT_PLAN.md             # 实验路线图
│   └── REFINE_STATE.json              # 方案精炼状态
│
├── innovation-logs/                   # 深度创新循环产出
│   ├── EVOLUTION_LOG.md               # 进化历史
│   └── TECHNIQUE_LIBRARY.md           # 累积技术库
│
├── paper/                             # 论文产出
│   ├── main.tex                       # LaTeX 主文件
│   ├── sections/                      # 各章节 .tex
│   ├── figures/                       # 图表
│   ├── references.bib                 # 参考文献
│   ├── main.pdf                       # 编译后的 PDF
│   ├── PROOF_AUDIT.{md,json}          # proof-checker 审计产物（v2.1 双格式）
│   ├── PAPER_CLAIM_AUDIT.{md,json}    # paper-claim-audit 审计产物
│   ├── CITATION_AUDIT.{md,json}       # citation-audit 审计产物
│   └── .aris/
│       ├── assurance.txt              # draft | submission
│       └── audit-verifier-report.json # verify_paper_audits.sh 输出
│
├── rebuttal/                          # Rebuttal 产出
│   ├── PASTE_READY.txt                # 直接粘贴版
│   ├── REBUTTAL_DRAFT_rich.md         # 详细版
│   └── REVISION_PLAN.md              # 修改承诺清单
│
├── research-wiki/                     # 持久化知识图谱（跨项目记忆）
│   ├── papers/                        # 论文（node: paper:<slug>）
│   ├── ideas/                         # idea（node: idea:<id>）
│   ├── experiments/                   # 实验（node: exp:<id>）
│   ├── claims/                        # 科学声明（node: claim:<id>）
│   ├── principles/                    # 可迁移原理（node: principle:<slug>，v2）
│   ├── failures/                      # 失败反模式（node: failure-pattern:<slug>，v2）
│   ├── graph/edges.jsonl              # 类型化关系图（含 embodies_principle / failure_mode_of / resolved_by / manifested_as 等）
│   ├── query_pack.md                  # 压缩 landscape 总结（8000 字符预算）
│   └── AUDIT_REPORT.md                # audit 输出：矛盾 / 趋势 / 原理覆盖 / 未解决失败
│
└── .aris/                             # ARIS 内部数据（审计与争议留痕）
    ├── traces/<skill>/<date>_run<NN>/ # 每次评审的完整 prompt + 响应存档
    ├── disputes/                      # 多轮争议仲裁 JSON（v2）
    │   └── round-<N>-F<id>-round-<R>.json  # 每轮仲裁一条，可查询到每条 finding 的完整讨论链
    └── meta/events.jsonl              # 使用事件日志
```

---

### 工具 CLI 用法

ARIS 的工具脚本也可以独立使用：

**arXiv 搜索与下载：**
```bash
python3 tools/arxiv_fetch.py search "robot manipulation" --max 20
python3 tools/arxiv_fetch.py search "tactile sensing" --category cs.RO --sort-by submittedDate
python3 tools/arxiv_fetch.py download 2401.12345 --dir papers/
```

**Semantic Scholar 搜索：**
```bash
python3 tools/semantic_scholar_fetch.py search "tactile grasping" --max 15 --min-citations 10
python3 tools/semantic_scholar_fetch.py citations "ARXIV:2401.12345" --max 20
python3 tools/semantic_scholar_fetch.py references "ARXIV:2401.12345"
```

**Exa 网络搜索：**
```bash
python3 tools/exa_search.py search "robot learning from demonstration" --max 10
python3 tools/exa_search.py search "sim2real transfer" --include-domains "arxiv.org,openreview.net"
python3 tools/exa_search.py find-similar "https://arxiv.org/abs/2401.12345" --max 5
```

**审计验证器（v2.1）：**
```bash
# 外部审计验证器（paper-writing Phase 6 自动调用，也可手动）
bash tools/verify_paper_audits.sh paper/ --assurance submission \
    --json-out paper/.aris/audit-verifier-report.json
# exit 0 = 3 个审计 JSON 齐全、schema 有效、hash 新鲜、无 FAIL/BLOCKED/ERROR
# exit 1 = 任何阻断项（细节在 --json-out 指定的报告中）

# wiki 覆盖诊断（非阻断 · 只报告）
bash tools/verify_wiki_coverage.sh research-wiki/ --json-out coverage.json
# 扫 .aris/traces/、paper/、references.bib 找出被引用但未 ingest 的 arXiv ID
```

**research-wiki 规范助手（v2.1）：**
```bash
# 规范 paper ingest（每个 paper-reading skill 统一调用）
python3 tools/research_wiki.py ingest_paper research-wiki/ --arxiv-id 2501.12345
# 手动 fallback（无 arXiv 元数据时）
python3 tools/research_wiki.py ingest_paper research-wiki/ \
    --title "..." --authors "A, B" --year 2025 --venue ICLR

# 批量回填
python3 tools/research_wiki.py sync research-wiki/ --arxiv-ids id1,id2,id3
python3 tools/research_wiki.py sync research-wiki/ --from-file ids.txt

# 持久化 v2 实体
python3 tools/research_wiki.py upsert_principle research-wiki/ <slug> \
    --from paper:<slug> --name "..." --generalized "..."
python3 tools/research_wiki.py upsert_failure_pattern research-wiki/ <slug> \
    --from paper:<slug> --name "..." --generalized "..."
```

**安装/卸载（v2.1）：**
```bash
bash tools/install_aris.sh                 # 全局安装（默认 ~/.claude/skills/）
bash tools/install_aris.sh --project PATH  # 项目级安装
bash tools/install_aris.sh --dry-run       # 预览
bash tools/install_aris.sh --reconcile     # 跟上仓库新增/删除
bash tools/uninstall_aris.sh               # 卸载全局
bash tools/uninstall_aris.sh --archive-copy # 旧 cp-r 安装迁移
```

---

### 审计产物 JSON Schema（v2.1）

所有强制审计（`/proof-checker`, `/paper-claim-audit`, `/citation-audit`）都 emit 符合下面 schema 的 JSON 产物。`verify_paper_audits.sh` 读这些 JSON 并根据 6-verdict 状态机决定是否阻断 Final Report。

**10 个必要字段：**

| 字段 | 类型 | 含义 |
|------|------|------|
| `audit_skill` | string | skill 名：`proof-checker` / `paper-claim-audit` / `citation-audit` |
| `verdict` | enum | `PASS \| WARN \| FAIL \| NOT_APPLICABLE \| BLOCKED \| ERROR`（见 assurance-contract.md） |
| `reason_code` | string | skill 特定短字符串（e.g. `all_numbers_match`、`wrong_context`） |
| `summary` | string | 一行人类可读摘要 |
| `audited_input_hashes` | object | 每个被审文件的 SHA256（verifier 重算以检测 STALE） |
| `trace_path` | string | 完整 prompt/response 存档目录（`.aris/traces/<skill>/<date>_run<NN>/`） |
| `thread_id` | string | Codex 线程 ID |
| `reviewer_model` | string | 如 `gpt-5.4` |
| `reviewer_reasoning` | string | 如 `xhigh` |
| `generated_at` | string | UTC ISO-8601 |
| `details` | object | skill 特定的结构化数据（审计结果明细） |

**STALE 检测**：用户编辑被审文件后 `audited_input_hashes` 不符 → verifier 标 `STALE` → exit 1 → Final Report 拒绝。完整规格见 `skills/shared-references/assurance-contract.md`。

---

### 断点续跑

长时间运行时 Claude Code 可能会 compact 上下文。ARIS 自动保存状态：

- `REVIEW_STATE.json` — 评审循环的轮次、分数、状态
- `REFINE_STATE.json` — 方案精炼的阶段和分数
- `PAPER_IMPROVEMENT_STATE.json` — 论文改进的轮次

恢复时，新 session 读取状态文件自动从断点继续。如果状态文件超过 24 小时则从头开始。

建议在 `CLAUDE.md` 中维护 Pipeline Status：

```markdown
## Pipeline Status
stage: auto-review-loop
idea: "tactile-enhanced grasping with proprioceptive feedback"
current_branch: feature/tactile-grasp
baseline: "DAgger (73.2% success rate)"
training_status: running on server-X, GPU 0-3
next: Round 3 review after training completes
```

---

## 用例展示

### 用例 1：从零开始的完整科研流程

**场景：** 你有一个模糊的研究方向，想从文献调研一路做到论文初稿。

```bash
/research-pipeline "tactile feedback for robotic manipulation" — effort: max, venue: ICRA
```

**ARIS 执行过程：**

| 阶段 | 做了什么 | 耗时（估计） | 产出 |
|------|---------|-------------|------|
| Stage 1 | 搜索 100+ 篇文献（arXiv + Semantic Scholar + Exa + WebSearch 并行），整理 gap 分析 | 10-20 分钟 | 文献全景图 |
| Stage 2 | 头脑风暴 12 个 idea，查新验证，GPT-5.4 批判性评审 | 15-30 分钟 | `IDEA_REPORT.md` |
| Stage 3 | Top 3 idea 上 GPU 做 pilot（每个 30 分钟 - 2 小时） | 1-6 小时 | pilot 实验结果 |
| Stage 4 | 精炼最佳方案，GPT-5.4 迭代 review 直到 9/10 | 20-40 分钟 | `FINAL_PROPOSAL.md` |
| Stage 5 | 实现完整实验代码 → GPT-5.4 代码审查 → 部署到 GPU | 2-8 小时 | 实验结果 |
| Stage 6 | 4 轮评审循环（每轮：打分 → 找弱点 → 文献驱动修复 → 重跑实验） | 4-12 小时 | `AUTO_REVIEW.md` |
| Stage 7 | 生成论文（大纲 → 图表 → LaTeX → 编译 → 评审润色 ×2） | 1-3 小时 | `paper/main.pdf` |

**总计：** 约 8-24 小时（取决于实验规模和 GPU 速度）。一觉醒来查看结果。

---

### 用例 2：已有实验结果，迭代改进到投稿水平

**场景：** 你已经有实验代码和初步结果，但还不到投稿水平。

```bash
/auto-review-loop "tactile grasping with proprioceptive feedback" — venue: RAL, human checkpoint: true
```

**典型分数进展（含 v2 争议流程）：**

| 轮次 | 分数 | 评审 findings | 争议（raised → 结果） | 发生了什么 |
|------|------|---------------|---------------------|-----------|
| 初始 | 5.0/10 | 7 blocking | — | Borderline reject — 缺标准 baseline、统计不充分 |
| 第 1 轮 | 6.5/10 | 5 blocking | 1 → 采纳 rebuttal（reviewer 误读 ablation） | 补了 3 个 baseline；1 条异议经 `/codex:rescue` 仲裁后判定 reviewer 误读，执行者证据获采纳 |
| 第 2 轮 | 6.8/10 | 4 blocking | 2 → 1 采纳 rebuttal + 1 妥协（换 Wilcoxon） | 核心声明不可复现；1 条"统计检验错"经 2 轮仲裁达成妥协方案 |
| 第 3 轮 | 7.0/10 | 2 blocking | 0 → 直接修复 | 大规模 seed 研究，重建统计可信度 |
| 第 4 轮 | **7.5/10** | 0 blocking | — | 诊断证据完整确立，narrative 重写，**可以投 RAL** |

> **每轮 Feedback Verification 表**存在 `AUTO_REVIEW.md` 中；争议仲裁 JSON 在 `.aris/disputes/` 下可逐条追溯。
> 
> 设置 `human checkpoint: true` 后，每轮审稿完成后会暂停，你可以查看分数、弱点、已采纳/已反驳的 finding 列表，给出修改方向或跳过某些修复。

---

### 用例 3：论文写作全流程

**场景：** 实验已完成，需要从研究叙事生成一篇投稿论文。

**Step 1：** 准备 `NARRATIVE_REPORT.md`（[模板](templates/NARRATIVE_REPORT_TEMPLATE.md)），写清：
- 核心故事（2-3 段）
- 声明列表（每个声明对应什么实验证据）
- 实验结果摘要（哪些指标、什么 baseline）
- 图表描述（需要什么图和表）

**Step 2：**
```bash
/paper-writing "NARRATIVE_REPORT.md" — venue: ICRA, effort: max
```

**ARIS 自动执行：**
1. 生成大纲 — claims-evidence 矩阵，每个声明映射到实验和图表
2. 生成图表 — 从实验数据画 matplotlib 图 + 生成 LaTeX 表格
3. 逐章写 LaTeX — 摘要、引言、相关工作、方法、实验、结论
4. 5-pass 写作审查 — 去废话、主动语态、句式优化、关键词一致性、数值完整性
5. 编译 PDF — 自动修复 LaTeX 错误和格式问题
6. GPT-5.4 评审 ×2 轮 — 偏见防护模式，每轮全新评审
7. 定理验证 — 如果有定理，自动用 `/proof-checker` 验证
8. 数字核对 — `/paper-claim-audit` 确认论文中的数字与原始数据一致
9. 最终格式检查 — 位置感知（正文任何 overfull 都修复，附录 >10pt 才修复）

**最终产出：** `paper/main.pdf`（投稿就绪）+ 全部 LaTeX 源文件 + 改进日志

---

### 用例 4：投稿后回复审稿意见

**场景：** 收到审稿意见，需要写 rebuttal。

```bash
/rebuttal "paper/ + reviews.txt" — venue: NeurIPS, character limit: 5800
```

**ARIS 自动执行：**
1. 解析每位审稿人的每个 concern，标记严重程度
2. 制定策略 — 哪些接受并改进、哪些用数据反驳、哪些承认为局限
3. 起草回复 — 严格遵守字数限制
4. 生成 `REVISION_PLAN.md` — 每个修改承诺一条，可打勾追踪
5. 安全检查 — 确保没有编造事实、没有过度承诺、每个意见都回复了
6. GPT-5.4 压力测试 — 模拟审稿人追问
7. 输出 `PASTE_READY.txt`（精确字数，直接复制粘贴）

---

### 用例 5：深度方法创新

**场景：** 已有 baseline 实现，想在 40+ 轮进化中找到有创新性的改进方法。

```bash
/deep-innovation-loop "improve DAgger for contact-rich manipulation" — venue: CoRL, baseline: DAgger, effort: beast
```

**与普通 review 循环的区别：**
- 不是修补症状（"加个 baseline"），而是诊断根因（"为什么在接触力估计上差？"）
- 搜索文献找**原理**，不是照搬方法（五层原理提炼协议）
- 默认对抗模式，卡住时自动切换合作模式（联合 GPT-5.4 读取原始文件）
- 持续积累技术库，避免重复尝试失败的方向

---

### 用例 6：改进一篇已有论文

**场景：** 看到一篇有缺陷的论文，想基于它的代码做改进。

```bash
/research-pipeline "improve tactile representation for manipulation" \
  — ref paper: https://arxiv.org/abs/2406.04329 \
  — base repo: https://github.com/org/tactile-project \
  — venue: RAL
```

ARIS 会：
1. 读论文 → 总结方法、分析优缺点
2. 克隆代码 → 理解项目结构
3. 针对论文的弱点生成改进 idea
4. 在论文的代码基础上实现改进
5. 跑对比实验 → 自动评审循环 → 写论文

> `ref paper` 单独 = "这篇论文哪里能改进？"；`base repo` 单独 = "这个代码能做什么？"；两个都给 = "用这个代码改进这篇论文。"

---

## 替代模型组合

ARIS 默认使用 Claude Code + GPT-5.4，也支持其他组合：

| 方案 | 执行者 | 审稿者 | 指南 |
|------|--------|--------|------|
| 默认 | Claude Code | GPT-5.4 (Codex CLI) | 本 README |
| Codex + Claude | Codex CLI | Claude (MCP bridge) | [指南](docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md) |
| Codex + Gemini | Codex CLI | Gemini (MCP bridge) | [指南](docs/CODEX_GEMINI_REVIEW_GUIDE_CN.md) |
| MiniMax + GLM | MiniMax | GLM-5 | [指南](docs/MiniMax-GLM-Configuration.md) |
| 纯 Codex | Codex CLI | Codex CLI | [skills-codex/](skills/skills-codex/) |
| ModelScope 免费 | — | — | [指南](docs/MODELSCOPE_GUIDE.md) |

其他 IDE 适配：[Cursor](docs/CURSOR_ADAPTATION.md) | [Trae](docs/TRAE_ARIS_RUNBOOK_CN.md) | [Antigravity](docs/ANTIGRAVITY_ADAPTATION_CN.md) | [OpenClaw](docs/OPENCLAW_ADAPTATION.md)

---

## 全部技能一览

<details>
<summary><b>66 个技能（点击展开）</b></summary>

**核心工作流：**

| 技能 | 说明 |
|------|------|
| `research-pipeline` | 全流程：工作流 1→1.5→2→3 |
| `idea-discovery` | 工作流 1：Idea 发现全流程 |
| `idea-discovery-robot` | 工作流 1 机器人/具身智能版 |
| `experiment-bridge` | 工作流 1.5：实现代码 → 部署 → 收结果 |
| `auto-review-loop` | 工作流 2：自动多轮评审循环 |
| `deep-innovation-loop` | 工作流 2+：40+ 轮深度方法进化 |
| `paper-writing` | 工作流 3：论文写作全流程 |
| `rebuttal` | 工作流 4：投稿 rebuttal |

**文献与 Idea：**

| 技能 | 说明 |
|------|------|
| `research-lit` | 多源文献检索（arXiv + Semantic Scholar + Exa + WebSearch） |
| `arxiv` | arXiv 搜索与下载 |
| `semantic-scholar` | 正式发表论文搜索（IEEE、ACM 等） |
| `exa-search` | Exa AI 广域网络搜索 |
| `deepxiv` | DeepXiv 渐进式论文阅读（search → brief → section） |
| `alphaxiv` | AlphaXiv 单篇论文快速查看（LLM 优化摘要） |
| `idea-creator` | 生成并排名研究 idea |
| `novelty-check` | 查新验证 |
| `research-review` | GPT-5.4 深度批判性评审 |
| `research-refine` | 模糊方向 → 具体方案 |
| `research-refine-pipeline` | research-refine → experiment-plan |

**实验管理：**

| 技能 | 说明 |
|------|------|
| `experiment-plan` | Claim-driven 实验路线图 |
| `run-experiment` | 部署 GPU 实验 |
| `monitor-experiment` | 监控实验进度 |
| `training-check` | WandB 指标监控 |
| `result-to-claim` | 实验结果 → 可支撑的声明 |
| `ablation-planner` | 消融实验规划 |
| `analyze-results` | 统计分析 |
| `experiment-audit` | 跨模型实验完整性审计 |

**论文工具：**

| 技能 | 说明 |
|------|------|
| `paper-plan` | 论文大纲 |
| `paper-figure` | 发表级图表 |
| `paper-write` | 逐章 LaTeX |
| `paper-compile` | PDF 编译 |
| `auto-paper-improvement-loop` | GPT-5.4 评审 ×2 + 格式检查 |
| `paper-illustration` | AI 架构图（Gemini） |
| `paper-slides` | 会议演讲幻灯片 |
| `paper-poster` | 会议海报 |

**验证工具：**

| 技能 | 说明 |
|------|------|
| `proof-checker` | 数学证明验证（20 类问题分类法，v2.1 emit submission JSON artifact） |
| `paper-claim-audit` | 零上下文论文数字核对（v2.1 emit submission JSON artifact） |
| `citation-audit`（**v2.1 新**） | 参考文献三轴验证（存在 / 元数据 / 上下文）；抓"错误上下文引用" |
| `proof-writer` | 定理证明撰写 |
| `formula-derivation` | 公式推导 |

**知识管理与优化：**

| 技能 | 说明 |
|------|------|
| `research-wiki` | 持久化知识图谱（6 种实体：paper/idea/exp/claim/principle/failure-pattern） |
| `meta-optimize` | ARIS 自身技能优化 |

**Shared-References 协议（跨 skill 复用）：**

| 协议文件 | 说明 | 被调用于 |
|---------|------|---------|
| `principle-extraction.md` | 5 层原理提取协议 | research-lit, deep-innovation-loop, auto-review-loop |
| `failure-extraction.md`（**v2**） | 5 层失败反模式提取 | research-lit, experiment-bridge, result-to-claim, deep-innovation-loop |
| `divergent-techniques.md`（**v2**） | 5 算子发散思维（SCAMPER/形态矩阵/反转/跨域/约束放松） | idea-creator, deep-innovation-loop, research-refine, reviewer-routing |
| `hypothesis-sparring.md`（**v2**） | ≥3 竞争性根因 + 最便宜证伪 | idea-creator, deep-innovation-loop, auto-review-loop |
| `reframing-triggers.md`（**v2**） | 假设攻击 / 问题重构 / 轨迹重审 | deep-innovation-loop, auto-review-loop, research-refine |
| `collaborative-protocol.md` | 对抗 → 协作升级（stuck 时切换） | deep-innovation-loop, auto-review-loop |
| `reviewer-routing.md` | 评审通道 + 评审角色路由 | 全评审类 skill |
| `post-coding-verification.md` | 3 层编码后验证（模块/集成/回归） | auto-review-loop, experiment-bridge, deep-innovation-loop |
| `codex-context-integrity.md` | Codex 调用的防误导协议 + **Review Feedback Verification Protocol** + **Execution Enforcement Gates**（v2 强化） | 全评审类 skill |
| `review-tracing.md` | 评审调用的完整 prompt/response 审计 | 全评审类 skill |
| `integration-contract.md`（**v2.1**） | 6 组件架构契约（激活谓词 / 规范助手 / 产物 / 清单 / 补救 / 验证） | 每个跨 skill 集成 |
| `assurance-contract.md`（**v2.1**） | 正交 `assurance` 轴 + 6-verdict 状态机 + 审计 JSON schema | paper-writing, 3 审计 skill, verify_paper_audits.sh |

> **v2 强化**：`codex-context-integrity.md` 现在定义了 5 条 HALT-IF-MISSING 门规则（review 输出消费门 / 验证表门 / 争议 JSON 门 / trace 追踪门 / 争议预算状态门），确保 review 调用和多轮争议协议不会被静默跳过。详见前面的"执行强制性与审计"章节。

**其他：**

| 技能 | 说明 |
|------|------|
| `grant-proposal` | 基金申请书（科研费/NSF/国自然/ERC 等 9 个机构） |
| `comm-lit-review` | 通信领域文献检索 |
| `dse-loop` | 设计空间探索（体系结构/EDA） |
| `vast-gpu` | Vast.ai GPU 租用 |
| `system-profile` | 系统性能分析 |
| `feishu-notify` | 飞书/Lark 通知 |
| `mermaid-diagram` | Mermaid 图表 |
| `pixel-art` | 像素风 SVG |
| `auto-review-loop-llm` | 任意 LLM 评审 |
| `auto-review-loop-minimax` | MiniMax 评审 |

</details>

---

## C++ 研究项目支持（v2.2+）

ARIS v2.2 的目标是让全自动科研工作流**兼容用 C++（以及相邻的 C/Rust/CUDA）实现的科研项目**——无论具体研究题目是什么。典型场景包括但不限于：

- **机器人 / SLAM / 运动规划 / 控制**（colcon workspace、ROS2 节点、实时约束）
- **计算机视觉 / 感知**（OpenCV、PCL、原生 CUDA 算子）
- **自然语言处理 / 大模型推理**（GGML、llama.cpp、vLLM、TensorRT-LLM 之类的 C++/CUDA 栈）
- **图形学 / 物理仿真**（Taichi、Mitsuba、自定义渲染器）
- **HPC / 数值计算**（MPI、OpenMP、自定义 CUDA kernel）
- **系统 / 数据库 / 编译器**（LLVM pass、运行时、存储引擎）
- **（若用户需要）理论算法论文**（复用 `/complexity-claim-audit`、`/proof-checker` 算法分类扩展）

重点在**验证自动化科研流水线的机制**对这些项目可用——从 idea-discovery 到 paper-writing 到 submission audit 整个环节。ARIS **不要求**特定版本的编译器、CUDA 工具包、ROS2 发行版或 GPU 架构；所有版本字段都从 `CLAUDE.md` `## Project` 段（或 `.aris/project.yaml`，或环境）中读取，skill 本身保持版本无关。

**运行环境完全由用户自选**——ARIS 不假设任何特定部署，也不自带任何容器。用户可以选择本地工作站、远程 SSH 服务器（复用 `run-experiment` 的 vast.ai 模板）、自己的 Docker/Podman 容器、Kubernetes pod 等。`tests/container/` 是 ARIS 自己的 CI 自检，跑在用户通过 `$ARIS_TEST_CONTAINER` 或 `.aris/container.yaml` 指向的临时测试容器里，不是部署要求。

| 运行环境 | CLAUDE.md `## Container`（或 `.aris/container.yaml`） | skill 行为 |
|---|---|---|
| 本地已装工具链 | 无 | 直接在宿主机执行 |
| 远程 SSH（参照 `run-experiment` vast.ai 流） | 无 | SSH 派发 |
| 用户自己的容器 | 有，`name:` 为用户容器名 | 经 `container_run.sh` 派发 |
| K8s pod / CI runner | skill 已在 pod 内运行 | 直接执行 |
| ARIS 仓库 CI 自检 | `$ARIS_TEST_CONTAINER` 指向一个用户提供的临时容器 | 仅 `tests/container/` 使用，不影响 skill 运行时 |

### 架构要点 —— CLAUDE.md 是单一入口

延续 ARIS 既有约定（`## Remote Server` / `## Vast.ai` / `## Local Environment` 都写在 `CLAUDE.md` 里），v2.2 也通过 CLAUDE.md 配置项目和执行环境。在你已有的 CLAUDE.md 里追加两段就够了：

```markdown
## Project
- language: cpp
- venue_family: robotics
- frameworks: ros2, cuda
- build_system: colcon
- cuda_arch: sm_86            # 你的 GPU 架构（sm_75/sm_80/sm_86/sm_89/sm_90，按硬件填）
- ros2_distro: jazzy          # 或 humble / iron / rolling
- bench_harness: google-benchmark
- bench_iterations: 10
- sanitizers_cpu: address, undefined, thread
- sanitizers_gpu: memcheck, racecheck, synccheck, initcheck
- profile_cpu_tool: perf
- profile_gpu_tool: nsight-compute

## Container                  # 可选——仅当你想用自己的容器隔离执行
- runtime: docker             # auto / docker / podman / distrobox / toolbox
- name: my-cpp-dev            # ← 你自己的容器名；ARIS 不自带容器
- workdir: /workspace
- pre_exec: source /opt/ros/jazzy/setup.bash
- pre_exec: export PATH=/usr/local/cuda/bin:$PATH
```

一键 scaffold（追加到现有 CLAUDE.md）：

```bash
python3 tools/project_contract.py init --target claude-md --language cpp --frameworks ros2,cuda
```

读取优先级：**CLAUDE.md `## Project` / `## Container`** > `.aris/project.yaml` + `.aris/container.yaml`（高级 / CI 程序化路径）> 自动检测（看 `pyproject.toml` / `CMakeLists.txt` / `package.xml` / `.cu` 文件）。

两个主 helper：

- `tools/project_contract.py` —— 解析配置，提供 `validate` / `get-language` / `get-frameworks` / `get-build-cmd` / `get-run-cmd` / `get-bench-cmd` / `get-metrics` / `get-container` / `source` / `init` 子命令。
- `tools/container_run.sh` —— 当 `## Container` 段存在时启用；自动检测 docker/podman/distrobox/toolbox 运行时，进入用户指定的容器，应用 `pre_exec` 后执行命令并透传退出码。支持 `--probe`、`--dry-run`。

<details>
<summary>YAML 形态（高级 / 程序化用户）</summary>

如果你需要程序化生成、CI 模板化、或不想动 CLAUDE.md，可以直接写 `.aris/project.yaml` + `.aris/container.yaml`：

```yaml
# .aris/project.yaml
language: cpp
venue_family: robotics
frameworks: [ros2, cuda]
build:
  system: colcon
  cuda_arch: sm_86
  ros2_distro: jazzy
sanitizers:
  cpu: [address, undefined, thread]
  gpu: [memcheck, racecheck, synccheck, initcheck]
profile:
  cpu_tool: perf
  gpu_tool: nsight-compute
```

```yaml
# .aris/container.yaml
runtime: docker
name: my-cpp-dev
workdir: /workspace
pre_exec:
  - "source /opt/ros/jazzy/setup.bash"
  - "export PATH=/usr/local/cuda/bin:$PATH"
```

CLAUDE.md 里的同名段落优先级更高，所以两套并存时以 CLAUDE.md 为准。
</details>

### 新增的 14 个 domain-specific 技能

按代码形态分组——和具体研究题目（SLAM / NLP / LLM / 感知 / 渲染 / 数据库 …）解耦。skill 看到 CLAUDE.md `## Project` 段（或 `.aris/project.yaml`）中相应的 `language` / `frameworks` 时自动启用。

**C++ 通用（5 个）**——任何 C++ 实现的科研项目（SLAM、感知、LLM 推理、图形、HPC、系统、编译器……）都用这一套：
- `/cpp-build` —— 检测 CMake/Make、执行 `$(project_contract.py get-build-cmd)`、捕获编译警告、产出 `BUILD_ARTIFACT.json`
- `/cpp-sanitize` —— ASan/UBSan/TSan/MSan runtime 审计；`assurance: submission` 下任一发现都会阻塞
- `/cpp-bench` —— Google Benchmark / Catch2 median-of-N + 95% CI + 离群点检测 + baseline 对比
- `/cpp-profile` —— perf / valgrind / cachegrind 热点定位 + 分支/缓存失败率
- `/complexity-claim-audit` —— **可选**——只有论文里真的写了 $\mathcal{O}$/$\Theta$/$\Omega$ 声明时才触发；多数 SLAM/感知/NLP 论文不需要

**ROS2（4 个）**——当 `frameworks` 包含 `ros2` 时启用：
- `/ros2-build`（colcon）、`/ros2-launch-test`（launch_testing + QoS + TF）、`/ros2-bag-replay`（rosbag 回放与黄金对比）、`/ros2-realtime-audit`（p99 latency + 控制环频率审计）

**CUDA（5 个）**——当 `frameworks` 包含 `cuda` 或工程含 `.cu`/`.cuh` 时启用：
- `/cuda-build`（nvcc + 寄存器/shared-mem/PTX）、`/cuda-sanitize`（compute-sanitizer 四工具）、`/cuda-profile`（Nsight Compute + Systems + Roofline）、`/cuda-correctness-audit`（GPU vs CPU 数值等价 + 多运行确定性）、`/tensorrt-engine-audit`（TRT 引擎 INT8 校准 + 每类精度回退）

另有 `/proof-checker` 扩展（v2.2）：amortized / loop invariant / recurrence / adversarial / entropy / cache-oblivious 算法证明分类——同样是 **可选**，仅理论方向论文用得上。

### venue 家族扩展（+7 个）

`shared-references/venue-checklists.md` 新增 Theory（SODA/STOC/FOCS/ICALP/SPAA/PODC）、Programming Languages（PLDI/OOPSLA/POPL/CGO/ICFP）、Systems（OSDI/SOSP/NSDI/EuroSys/ASPLOS/SC/HPCA）、Database（VLDB/SIGMOD/ICDE/CIDR）、Graphics（SIGGRAPH/EG/HPG/I3D）、HPC（SC/PPoPP/IPDPS）、Robotics（ICRA/IROS/RSS/RA-L/T-RO/HRI/CoRL）。

### 审计流水线扩展

`tools/verify_paper_audits.sh` 在 `assurance: submission` 下按 CLAUDE.md `## Project` 段（或 `.aris/project.yaml`）自动附加必需审计；与此对应，`/paper-writing` Phase 6 会**自动 fan-out 触发产生这些 JSON 的 skill**——用户只需 `/paper-writing — assurance: submission` 一条命令：

| 条件 | 新增必需审计 |
|---|---|
| `language: cpp` | `COMPLEXITY_AUDIT.json` + `SANITIZER_AUDIT.json` + `BENCHMARK_RESULT.json` |
| `frameworks` 含 `ros2` | + `ROS2_LAUNCH_TEST_AUDIT.json` + `ROS2_REALTIME_AUDIT.json` |
| `frameworks` 含 `cuda` | + `CUDA_SANITIZER_AUDIT.json` + `CUDA_PROFILE_REPORT.json` + `CUDA_CORRECTNESS_AUDIT.json` |
| `frameworks` 含 `tensorrt` | + `TRT_ENGINE_AUDIT.json` |

三个一体化验证脚本各自输出 `*_INTEGRITY_REPORT.json`：`tools/verify_cpp_project.sh`、`tools/verify_ros2_project.sh`、`tools/verify_cuda_project.sh`。

### 15 个领域失败反模式（失败库种子）

```bash
bash tools/seed_cpp_ros2_cuda_failure_patterns.sh <wiki-root>
```

一次性把下列 15 个失败反模式种入 `research-wiki/failures/`：

- **C++（6）**：`ub-exploit-compiler-optimization`、`hidden-asymptotic-constant`、`cache-thrash-false-sharing`、`numerical-instability-catastrophic-cancellation`、`race-condition-data-race`、`memory-fragmentation-allocator-pressure`
- **ROS2（4）**：`ros2-qos-profile-mismatch`、`ros2-callback-group-deadlock`、`ros2-tf-tree-race`、`ros2-dds-discovery-failure`
- **CUDA（5）**：`cuda-warp-divergence-perf`、`cuda-shared-memory-bank-conflict`、`cuda-unaligned-global-access`、`cuda-register-pressure-spill`、`cuda-async-copy-race`

每条记录含 `generalized_form`、`tags`、`status=active`，并通过 `paper:aris-v22-seeds` 挂接到 wiki 图中。

### 容器测试套件（ARIS 仓库 CI 自检，用户无需关心）

`tests/container/` 下 6 个 smoke 测试把 ARIS 自身的 v2.2 skill 试跑到一个**用户临时提供**的测试容器里（通过 `$ARIS_TEST_CONTAINER` 环境变量或 `.aris/container.yaml` 指定）。这只是 ARIS 仓库 CI 的自检——用户跑自己的 C++/ROS2/CUDA 项目时并不需要这个容器。没有配置时整套测试会自动 SKIP：

| 测试 | 覆盖 |
|---|---|
| `smoke_cuda_build.sh` | nvcc 为 sm_86 编译最小 SAXPY 内核 + 解析寄存器数 |
| `smoke_cuda_sanitize.sh` | compute-sanitizer --version + memcheck（驱动可用时） |
| `smoke_cuda_profile.sh` | ncu + nsys 存在 + GPU 设备节点可见 |
| `smoke_ros2_build.sh` | colcon build 最小 rclcpp hello world |
| `smoke_ros2_launch_test.sh` | launch / launch_testing 可导入 + pytest 存在 |
| `smoke_tensorrt_presence.sh` | libnvinfer-dev + trtexec + cuDNN（任何版本） |

使用方式：

```bash
bash tests/run_all.sh                   # 仅宿主机（默认，兼容 ML 用户）
bash tests/run_all.sh --with-container  # 宿主机 + 容器
bash tests/run_all.sh --container-only  # 仅容器
bash tests/ci.sh                        # 一键入口，自动检测
```

当前状态：宿主机 13/13 全绿 + 容器 6/6 全绿。

### 新增 HALT 消息（v2.2）

| HALT 消息 | 触发条件 | 修复 |
|---|---|---|
| `SANITIZER_AUDIT blocking (findings_present)` | `/cpp-sanitize` 在 submission 级发现任何 ASan/UBSan/TSan/MSan 告警 | 修复 UB/race，重新运行；不应在 audit JSON 中伪造 PASS |
| `CUDA_SANITIZER_AUDIT blocking` | compute-sanitizer 在 submission 级有任何违规 | 定位 kernel/line，修复 race/unaligned/init，重新审计 |
| `ROS2_REALTIME_AUDIT deadline_missed` | p99 超过 `.aris/deadlines.yaml` 预算 | 降负载 / 改 executor / 换 callback group，重跑 |
| `COMPLEXITY_AUDIT unproven` | 论文中 $\mathcal{O}$ 声明在附录找不到对应证明 | 补证明 or 修正 claim；重新运行 `/complexity-claim-audit` |
| `BENCHMARK_RESULT missing at submission` | cpp 项目 submission 缺 `BENCHMARK_RESULT.json` | 运行 `/cpp-bench` |
| `container runtime not found` | `container_run.sh --probe` 未发现 docker/podman/distrobox/toolbox | 安装其一或改为 host-only |
| `GPU driver version insufficient` | `compute-sanitizer` / `ncu` 运行期报驱动不足 | 重启容器时加 `--gpus all`；或升级主机驱动；或 CI 跳过 GPU-runtime 块 |

### 端到端示例 1：C++ SLAM 研究 → IROS / ICRA 投稿（主线）

一个典型的 C++ 研究项目：视觉-惯性 SLAM 系统，实现使用 C++17 + Eigen + Ceres + OpenCV，用 ROS2 封装，需要在真实数据集（EuRoC / TUM-VI）和自己采集的 bag 上评估。

**Step 1 — 在 CLAUDE.md 里追加项目段（一次性）**：

```markdown
## Project
- language: cpp
- venue_family: robotics
- frameworks: ros2
- build_system: colcon
- ros2_distro: humble        # 你的 ROS2 distro
- bench_harness: rosbag-replay
- sanitizers_cpu: address, undefined, thread

## Container                 # 可选——如果你已经在装好 ROS2 的本地/远程，这段可省
- runtime: docker
- name: my-ros2-dev          # 你自己启动的容器名
- workdir: /workspace
- pre_exec: source /opt/ros/humble/setup.bash
```

或一键生成（追加到现有 CLAUDE.md）：
```bash
python3 tools/project_contract.py init --target claude-md --language cpp --frameworks ros2
# 然后手动改 ros2_distro / cuda_arch / 容器名等以匹配实际环境
```

**Step 2 — 一键完成 idea → submission**：

```bash
# 走主流程，全自动
/idea-discovery --domain "loop closure reliability in dynamic scenes"
/research-lit   --focus "recent VI-SLAM + learned-descriptor closures 2024-2026"
/experiment-plan — domain: cpp-generic
/run-experiment              # Step 0 polyglot 派发——按 CLAUDE.md 走 colcon build + 测试

# 论文 + 一键 submission 审计
/paper-writing — effort: max, assurance: submission — venue: IROS
# Phase 6 在 frameworks 含 ros2 时自动 fan-out 到：
#   /ros2-build, /ros2-launch-test, /ros2-realtime-audit
# + 通用三件套 /proof-checker /paper-claim-audit /citation-audit
# 然后 bash tools/verify_paper_audits.sh paper/ --assurance submission
# 全部 PASS / NOT_APPLICABLE → submission-ready
```

工作流里**没有一步**需要 ARIS 知道你的 ROS2 发行版、编译器版本、或 GPU 架构——版本字段全部在 CLAUDE.md 里由用户声明，skill 从中读取。ML 用户完全不受影响：没有 `## Project` 段时自动检测 → `language: python`，走原 PyTorch/W&B/vast.ai 路径。

### 端到端示例 2：LLM 推理优化 → MLSys / ASPLOS 投稿

C++/CUDA 栈的研究项目（llama.cpp 分叉、自定义 attention kernel、量化方案），重点在 throughput / latency / memory-footprint 提升：

```markdown
## Project
- language: cpp
- venue_family: gpu
- frameworks: cuda, cudnn
- build_system: cmake
- cuda_arch: sm_89           # 比如 RTX 4090；按你的卡填 sm_75/sm_80/sm_86/sm_90
- bench_harness: cuda-eventtimer
- sanitizers_cpu: address, undefined
- sanitizers_gpu: memcheck, racecheck
- profile_gpu_tool: nsight-compute

## Container                 # 视需要——若本地已装 CUDA 工具链可省
- runtime: docker
- name: my-cuda-dev
- pre_exec: export PATH=/usr/local/cuda/bin:$PATH
```

```bash
/run-experiment
/paper-writing — effort: max, assurance: submission — venue: MLSys
# 自动 fan-out：cuda-build, cuda-sanitize, cuda-profile, cuda-correctness-audit
# /paper-claim-audit Phase C.6 核对 "2.3× throughput, occupancy 87%" 等声明
```

### 端到端示例 3：感知 / 计算机视觉 → CVPR / ECCV

传统 C++ 感知 pipeline（OpenCV + PCL + 自定义 CUDA ops），评估在 KITTI / Waymo 上：

```markdown
## Project
- language: cpp
- venue_family: graphics
- frameworks: cuda
- build_system: cmake
- cuda_arch: sm_86
- sanitizers_cpu: address, undefined
- sanitizers_gpu: memcheck, racecheck
```

```bash
/paper-writing — venue: CVPR, assurance: submission
# 自动 fan-out：cpp-build, cpp-sanitize, cpp-bench + cuda-build, cuda-sanitize, cuda-correctness-audit
```

三个示例共用一条流水线，差别只在 CLAUDE.md `## Project` 段的 `frameworks` 和 `venue_family`。ARIS 不预设你的研究题目——**你的项目长什么样，workflow 就怎么配合**。一键启动跟之前 ML 工作流完全一致：`/research-pipeline` 或 `/paper-writing` 即可。

### 对 ML 用户的影响

**零。** `.aris/project.yaml` 和 `.aris/container.yaml` 都是可选的；缺省时 `project_contract.py` 自动检测（pyproject.toml / requirements.txt → python），继承原有 PyTorch/WandB/vast.ai 工作流；`run-experiment` 的 Step 0 只在 `language ≠ python` 时才走 polyglot 分支。

## 许可证与引用

[LICENSE](LICENSE)

```bibtex
@software{aris2026,
  title  = {ARIS: Auto-claude-code-research-in-sleep},
  author = {wanshuiyin},
  url    = {https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep},
  year   = {2026}
}
```
