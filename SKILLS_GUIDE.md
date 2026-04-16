# ARIS 技能详细使用指南

本文档详细介绍 ARIS 中每个技能的功能、参数、输入输出和使用方法。

---

## 目录

- [一、核心工作流编排](#一核心工作流编排)
- [二、文献检索与 Idea 生成](#二文献检索与-idea-生成)
- [三、方案精炼与实验规划](#三方案精炼与实验规划)
- [四、实验执行与监控](#四实验执行与监控)
- [五、结果分析与声明验证](#五结果分析与声明验证)
- [六、自动评审与深度创新](#六自动评审与深度创新)
- [七、论文写作](#七论文写作)
- [八、论文验证与审计](#八论文验证与审计)
- [九、展示与传播](#九展示与传播)
- [十、Rebuttal](#十rebuttal)
- [十一、知识管理与自优化](#十一知识管理与自优化)
- [十二、基础设施与工具](#十二基础设施与工具)
- [十三、领域专用技能](#十三领域专用技能)
- [十四、工具脚本 CLI](#十四工具脚本-cli)

---

## 一、核心工作流编排

### `/research-pipeline` — 全流程编排

一键串联工作流 1 → 1.5 → 2 → 3，从研究方向到投稿论文。

```bash
/research-pipeline "tactile feedback for robotic manipulation"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `AUTO_PROCEED` | `true` | 自动选择 top idea。设 `false` 在 idea 选择关卡暂停 |
| `DEEP_INNOVATION` | `false` | 用深度创新循环（40+ 轮）替代标准 4 轮评审循环 |
| `HUMAN_CHECKPOINT` | `false` | 每轮评审后暂停等待用户输入 |
| `ARXIV_DOWNLOAD` | `false` | 文献调研时下载 arXiv PDF |
| `effort` | `balanced` | 工作强度（lite / balanced / max / beast），传递给所有子 skill |
| `venue` | `ICLR` | 目标 venue |
| `ref paper` | — | 参考论文（arXiv URL 或本地 PDF 路径） |
| `base repo` | — | 基础代码 GitHub URL |

**执行流程：**
1. **Stage 1** — `/idea-discovery`：文献调研 → 生成 idea → 查新 → pilot 实验 → 排名
2. **Stage 2** — 实现代码（用 pilot 中最佳 idea 的代码为基础）
3. **Stage 3** — `/run-experiment`：部署完整实验到 GPU
4. **Stage 4** — `/auto-review-loop` 或 `/deep-innovation-loop`（取决于 `DEEP_INNOVATION`）
5. **Stage 5** — `/paper-writing`：生成投稿论文（如果 Stage 4 通过）

**输出文件：** `IDEA_REPORT.md` → `refine-logs/EXPERIMENT_PLAN.md` → `AUTO_REVIEW.md` → `paper/main.pdf`

**示例：**
```bash
# 基础用法
/research-pipeline "robot learning from demonstration"

# 精准模式（基于已有论文和代码）
/research-pipeline "improve tactile representation" — ref paper: https://arxiv.org/abs/2406.04329, base repo: https://github.com/org/project

# 最大强度 + 手动审批
/research-pipeline "sim2real transfer for manipulation" — effort: beast, AUTO_PROCEED: false, human checkpoint: true

# 深度创新模式
/research-pipeline "improve DAgger for contact-rich tasks" — DEEP_INNOVATION: true, venue: CoRL
```

---

### `/idea-discovery` — 工作流 1：Idea 发现

从研究方向出发，自动完成文献调研 → idea 生成 → 查新验证 → pilot 实验 → 方案精炼。

```bash
/idea-discovery "tactile feedback for robotic manipulation"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `AUTO_PROCEED` | `true` | 自动选择 top idea |
| `ref paper` | — | 参考论文，基于它的弱点生成改进 idea |
| `base repo` | — | 基础代码 URL |
| `effort` | `balanced` | 工作强度 |
| `PILOT_MAX_HOURS` | `2` | 跳过预估 > 2 小时的 pilot |
| `PILOT_TIMEOUT_HOURS` | `3` | pilot 硬超时 |
| `MAX_PILOT_IDEAS` | `3` | 最多并行 pilot 几个 idea |
| `MAX_TOTAL_GPU_HOURS` | `8` | 所有 pilot 的 GPU 总预算 |
| `arxiv download` | `false` | 下载 arXiv PDF |
| `compact` | `false` | 精简输出模式 |

**执行阶段：**
1. **Phase 0** — 读取 Research Wiki（如果存在），加载已知 gap 和失败 idea
2. **Phase 0.5** — 总结参考论文（如果指定了 `ref paper`）
3. **Phase 1** — 文献全景调研（调用 `/research-lit`）
4. **Phase 2** — GPT-5.4 头脑风暴 8-12 个 idea
5. **Phase 3** — 查新验证（调用 `/novelty-check`）
6. **Phase 4** — 批判性评审（调用 `/research-review`）
7. **Phase 5** — Pilot 实验（top 2-3 idea 并行上 GPU）+ 失败 idea 深度分析
8. **Phase 6** — 排名输出
9. **Phase 7** — 写入 Research Wiki（包括失败的 idea）

**输入文件（可选）：** `RESEARCH_BRIEF.md`（[模板](templates/RESEARCH_BRIEF_TEMPLATE.md)）

**输出文件：**
- `IDEA_REPORT.md` — 所有 idea 排名 + pilot 结果
- `IDEA_CANDIDATES.md` — 精简版（compact 模式）
- `refine-logs/FINAL_PROPOSAL.md` — 精炼后的方案
- `refine-logs/EXPERIMENT_PLAN.md` — 实验路线图

**示例：**
```bash
# 基础用法
/idea-discovery "visual language models for robotics"

# 基于已有论文找改进点
/idea-discovery "improve this paper" — ref paper: https://arxiv.org/abs/2401.12345

# 限制 GPU 预算
/idea-discovery "sim2real transfer" — PILOT_MAX_HOURS: 1, MAX_TOTAL_GPU_HOURS: 4

# 不自动选择，手动挑 idea
/idea-discovery "graph neural networks for molecular design" — AUTO_PROCEED: false
```

---

## 二、文献检索与 Idea 生成

### `/research-lit` — 多源文献检索

搜索和分析研究论文，整理相关工作全景。支持 5 大数据源并行检索。

```bash
/research-lit "tactile sensing for robotic manipulation"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `sources` | `all` | 搜索源：`zotero` / `obsidian` / `local` / `web` / `semantic-scholar` / `all` |
| `paper library` | 自动检测 | 本地 PDF 目录（检查 `papers/`、`literature/`、CLAUDE.md 中配置的路径） |
| `arxiv download` | `false` | 下载最相关的 arXiv PDF |
| `max download` | `500` | 最大下载 PDF 数量 |
| `snowball` | `true` | 引用图谱展开（正向 + 反向引用追踪） |
| `no-s2` | — | 排除 Semantic Scholar |

**内部常量：**
- `API_MAX_PER_QUERY = 100` — 每个查询变体的最大 API 结果数
- `MAX_TOTAL_PAPERS = 500` — 所有来源的论文总上限
- `WEB_SEARCH_ALWAYS = true` — 无论选择什么源，WebSearch 始终运行
- `CROSS_DOMAIN = true` — 生成跨领域查询变体（数学、信号处理、物理、相邻 ML）
- `MAX_LOCAL_PAPERS = 20` — 最大本地 PDF 扫描数（每篇读前 3 页）

**搜索源优先级：**
1. **Zotero**（通过 MCP）— 收藏、标签、PDF 高亮、BibTeX
2. **Obsidian**（通过 MCP）— 研究笔记、论文摘要
3. **本地 PDF** — 直接读取 PDF 内容（前 3 页）
4. **arXiv API** — `python tools/arxiv_fetch.py`
5. **Semantic Scholar API** — `python tools/semantic_scholar_fetch.py`
6. **Exa AI** — `python tools/exa_search.py`（广域网络搜索）
7. **WebSearch / WebFetch** — Google Scholar 等

**搜索流程：**
1. **Step 0.5** — 查询扩展：生成 8-10 个查询变体（5 领域内 + 3-5 跨领域）
2. **Step 1** — 多源并行搜索（API 工具和 WebSearch 同等优先级，都要用）
3. **Step 1.1** — 跨领域深度搜索（数学、信号处理、物理基础）
4. **Step 1.5** — 引用图谱展开（top 论文的正向/反向引用 + 作者其他论文）
5. **Step 2** — 去重 + 相关性排序
6. **Step 2.5** — Gap 驱动扩展（基于发现的术语 gap 再搜索 1 轮）
7. **Step 3-5** — 分析、总结、输出

**示例：**
```bash
# 仅搜索 Zotero + 网络
/research-lit "attention mechanisms" — sources: zotero, web

# 下载 arXiv PDF
/research-lit "robot learning" — arxiv download: true, max download: 10

# 排除 Semantic Scholar
/research-lit "graph neural networks" — no-s2

# 指定本地论文目录
/research-lit "reinforcement learning" — paper library: ~/papers/rl/
```

---

### `/arxiv` — arXiv 搜索与下载

```bash
/arxiv "tactile sensing robot"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `max` | `10` | 最大结果数 |
| `category` | — | arXiv 类别（如 `cs.RO`, `cs.LG`, `cs.CV`） |
| `download` | `false` | 下载 PDF 到 `papers/` 目录 |

**示例：**
```bash
/arxiv "sim2real transfer" — max: 30, category: cs.RO
/arxiv "2401.12345" — download: true     # 按 ID 下载
```

---

### `/semantic-scholar` — 正式发表论文搜索

搜索 IEEE、ACM、Springer 等正式发表的论文，带引用数和 venue 元数据。

```bash
/semantic-scholar "tactile grasping"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `max` | `10` | 最大结果数 |
| `min-citations` | — | 最低引用数过滤 |
| `year` | — | 年份过滤（如 `2024-2026`） |
| `venue` | — | venue 过滤 |

**示例：**
```bash
/semantic-scholar "robotic manipulation" — max: 20, min-citations: 50
/semantic-scholar "SLAM" — year: 2024-2026, venue: RAL
```

---

### `/exa-search` — Exa AI 网络搜索

广域网络搜索（博客、文档、新闻、公司、论文），带内容提取。需要 `EXA_API_KEY`。

```bash
/exa-search "latest advances in robot manipulation 2026"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `max` | `10` | 最大结果数 |
| `category` | — | 类别：`research paper` / `news` / `company` / `personal site` |
| `content` | `highlights` | 内容模式：`text` / `summary` / `highlights` / `none` |
| `type` | `auto` | 搜索类型：`auto` / `neural` / `fast` / `instant` |
| `domains` | — | 限定域名（如 `arxiv.org,huggingface.co`） |
| `start-date` | — | 起始日期（ISO 8601） |
| `end-date` | — | 结束日期 |
| `similar` | — | 找与给定 URL 相似的页面 |

**示例：**
```bash
/exa-search "transformer for robotics" — category: research paper, start-date: 2025-01-01
/exa-search "https://arxiv.org/abs/2401.12345" — similar, max: 5
/exa-search "robot learning blog" — domains: openai.com,deepmind.google
```

---

### `/deepxiv` — DeepXiv 渐进式论文阅读

通过 DeepXiv 渐进式读取论文：search → brief → head → section，避免一次性加载全文。

```bash
/deepxiv "agent memory"                        # 搜索论文
/deepxiv "2409.05591" - brief                   # 快速摘要
/deepxiv "2409.05591" - head                    # 元数据 + 章节概览
/deepxiv "2409.05591" - section: Introduction   # 读取单个章节
/deepxiv "trending" - days: 14 - max: 10        # 最近热门论文
/deepxiv "karpathy" - web                       # DeepXiv 网络搜索
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `max` | `10` | 最大结果数 |
| `brief` | — | 获取论文简要摘要 |
| `head` | — | 获取元数据 + 章节地图 |
| `section` | — | 读取指定章节（如 `section: Methods`） |
| `trending` | — | 获取热门论文（配合 `days: 7/14/30`） |
| `web` | — | DeepXiv 网络搜索 |
| `sc` | — | 通过 Semantic Scholar ID 获取元数据 |

**安装：** `pip install deepxiv-sdk`（可选，未安装时建议用 `/arxiv` 或 `/research-lit`）

**渐进式读取策略：** search → paper-brief → paper-head → paper-section → 全文（仅在必要时）

---

### `/alphaxiv` — AlphaXiv 单篇论文快速查看

通过 AlphaXiv 获取 LLM 优化的论文摘要，支持三级 fallback（概览 → 全文 markdown → LaTeX 源码）。

```bash
/alphaxiv 2401.12345                            # 快速概览
/alphaxiv "https://arxiv.org/abs/2401.12345"    # 从 URL 自动提取 ID
/alphaxiv 2401.12345 - depth: abs               # 强制全文 markdown
/alphaxiv 2401.12345 - depth: src               # 强制 LaTeX 源码
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `depth` | 自动 | 强制指定深度：`overview` / `abs` / `src` |

**支持的输入格式：**
- `https://arxiv.org/abs/2401.12345[v2]`
- `https://arxiv.org/pdf/2401.12345`
- `https://alphaxiv.org/overview/2401.12345`
- `2401.12345` 或 `2401.12345v2`（裸 ID）

**三级 Fallback：**
1. **Tier 1 (Overview)** — alphaxiv.org/overview/ 结构化 LLM 优化报告（最快）
2. **Tier 2 (Full Markdown)** — alphaxiv.org/abs/ 完整论文 markdown
3. **Tier 3 (LaTeX Source)** — arxiv.org/src/ LaTeX 源码（方程、证明、附录）

**无需安装，** 通过 WebFetch 直接获取。

---

### `/idea-creator` — 生成并排名研究 Idea

给定研究方向，生成 8-12 个具体 idea，筛选排序，可选 pilot 实验验证。

```bash
/idea-creator "tactile representation learning"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `PILOT_MAX_HOURS` | `2` | 跳过预估超时的 pilot |
| `PILOT_TIMEOUT_HOURS` | `3` | pilot 硬超时 |
| `MAX_PILOT_IDEAS` | `3` | 最多并行 pilot 数 |
| `MAX_TOTAL_GPU_HOURS` | `8` | GPU 总预算 |

**执行阶段：**
1. 读取 Research Wiki（避免重复已知失败方向）
2. 文献全景调研
3. GPT-5.4 头脑风暴 8-12 个 idea
4. 可行性评估 + 查新初筛
5. Top 2-3 idea 做 pilot 实验
6. 失败 pilot 深度分析（`/codex:rescue`）
7. 排名输出 + 写入 Wiki

**输出文件：** `IDEA_REPORT.md`

---

### `/novelty-check` — 查新验证

验证研究 idea 是否已被发表。提取 3-5 个核心技术声明，多源搜索验证。

```bash
/novelty-check "use graph attention for tactile feature aggregation"
```

**执行阶段：**
1. **Phase A** — 提取 3-5 个核心技术声明
2. **Phase B** — 多源搜索（WebSearch + venue 论文 + arXiv 2024-2026）
3. **Phase C** — GPT-5.4 交叉验证（输出结构化 JSON：`novelty-verdict.schema.json`）

**输出：** 每个声明的新颖性判定（novel / partially novel / already published）

---

### `/research-review` — GPT-5.4 深度批判性评审

让 GPT-5.4 独立阅读项目文件，提供深度批判性反馈。

```bash
/research-review "my tactile manipulation approach"
```

**执行阶段：**
1. 编译关键文件列表（让 GPT-5.4 直接读取，不是 Claude 总结后转发）
2. `/codex:rescue --effort xhigh` 第一轮评审
3. 迭代对话（最多 5 轮）
4. 独立文件审计（Round 3 后，GPT-5.4 重新读取文件独立判断）
5. 达成一致 / 协作妥协

**输出：** 批判性评审报告 + 改进建议

---

## 三、方案精炼与实验规划

### `/research-refine` — 模糊方向 → 具体方案

通过 GPT-5.4 迭代 review，将模糊的研究方向打磨为问题锚点明确、可实现的方案。

```bash
/research-refine "use tactile feedback to improve grasping"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `max rounds` | `5` | 最大 review-revise 轮数 |
| `threshold` | `9` | 目标分数（达到即停） |

**内部常量：**
- `MAX_LOCAL_PAPERS = 15` — 方案锚定用的文献数
- `MAX_CORE_EXPERIMENTS = 3` — 核心验证实验上限
- `MAX_PRIMARY_CLAIMS = 2` — 一个主声明 + 一个辅助声明
- `MAX_NEW_TRAINABLE_COMPONENTS = 2` — 新增可训练组件上限

**执行阶段：**
1. **Phase 0** — 冻结问题锚点（不可变）
2. **Phase 1** — 扫描文献、识别 gap、选择最锐利的路线、写初版方案
3. **Phase 2** — GPT-5.4 评审（保真度、具体性、前沿对齐度）
4. **Phase 3** — 锚点检查 + 简洁性检查 → 修改方案
5. **Phase 4** — GPT-5.4 重新评估
6. 重复 Phase 3-4 直到分数 >= 9 或达到 max rounds

**状态恢复：** `refine-logs/REFINE_STATE.json`

**输出文件：** `refine-logs/FINAL_PROPOSAL.md`

---

### `/experiment-plan` — Claim-Driven 实验路线图

将精炼后的方案转化为具体的实验计划。每个实验 block 映射到一个声明。

```bash
/experiment-plan
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `HPARAM_SEARCH` | `true` | 规划超参数敏感性分析 |

**内部常量：**
- `MAX_PRIMARY_CLAIMS = 2` — 一个主 + 一个辅
- `MAX_CORE_BLOCKS = 5` — 核心实验 block 上限
- `MAX_BASELINE_FAMILIES = 3` — 少而强的 baseline
- `DEFAULT_SEEDS = 3` — 默认 3 seeds，报告 mean ± std

**执行阶段：**
1. 加载方案上下文（`FINAL_PROPOSAL.md`、review 记录）
2. 冻结论文声明（primary + supporting + anti-claim）
3. 设计实验 block（每个 block 1:1 映射到声明）
4. 规划执行顺序（M0→M3 里程碑）
5. GPT-5.4 评审实验结构

**输入文件：** `refine-logs/FINAL_PROPOSAL.md`

**输出文件：** `refine-logs/EXPERIMENT_PLAN.md`（[模板](templates/EXPERIMENT_PLAN_TEMPLATE.md)）

---

### `/research-refine-pipeline` — 一键精炼 + 规划

串联 `/research-refine` → `/experiment-plan`。

```bash
/research-refine-pipeline "use tactile feedback to improve grasping"
```

---

## 四、实验执行与监控

### `/experiment-bridge` — 工作流 1.5：实现 + 部署

解析实验计划 → 实现代码 → GPT-5.4 代码审查 → 完整性审计 → 部署 GPU → 收集结果。

```bash
/experiment-bridge
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `code review` | `true` | GPT-5.4 部署前代码审查 |
| `base repo` | — | GitHub URL，克隆作为基础代码 |
| `BASELINE_COMPARISON` | — | 基线名称，自动生成 delta 对比表 |
| `ITERATIVE_VARIANTS` | `false` | 同一 session 测试多个方法变体 |

**执行阶段：**
1. **Phase 1** — 解析实验计划
2. **Phase 2** — 实现实验代码
3. **Phase 2.3** — **强制代码审查**（`/codex:adversarial-review`，不可跳过）
4. **Phase 2.5** — 基线公平性审计 + 统计严谨性检查
5. **Phase 3** — Sanity check（最小实验）
6. **Phase 4** — 部署完整实验（`/run-experiment`）
7. **Phase 5** — 收集结果
8. **Phase 5.45** — GPT-5.4 独立结果解读
9. **Phase 5.47** — 实验完整性审计（`/experiment-audit`）
10. **Phase 5.7** — 如果结果为负 → 原理驱动的失败诊断

**输入文件：** `refine-logs/EXPERIMENT_PLAN.md`（最佳）或上下文自动推断

---

### `/run-experiment` — 部署 GPU 实验

自动检测 GPU 环境（本地/远程/Vast.ai），同步代码，启动训练。

```bash
/run-experiment "train tactile encoder on server-X"
```

**GPU 环境配置（CLAUDE.md）：**

```markdown
## GPU Server
- host: server-x            # SSH 别名
- user: username
- gpu_dir: /data/experiments
- conda_env: myenv
- gpu_ids: 0,1
```

**执行流程：**
1. 读取 CLAUDE.md 中的 `gpu:` 设置（local / remote / vast）
2. Pre-flight check（`nvidia-smi` 检测可用 GPU，空闲 < 500 MiB）
3. 同步代码（rsync 或 git push→pull）
4. 在 screen session 中启动实验
5. 返回 screen name 和日志路径

**代码同步选项：**
- `rsync`（默认）— 直接同步
- `git`（设置 `code_sync: git`）— `git push` → SSH `git pull`

---

### `/monitor-experiment` — 监控实验

```bash
/monitor-experiment "server-x"
```

**执行：**
1. SSH 到服务器，`screen -ls` 列出运行中的 session
2. 从每个 screen 提取最近输出
3. 检查 JSON 结果文件
4. 汇报进度

---

### `/training-check` — WandB 指标监控

定期检查训练指标，捕获 NaN、loss 发散、GPU 空闲等问题。

```bash
/training-check "entity/project/run_id"
```

**内部常量：**
- `CHECK_INTERVAL` — 自适应间隔：10 → 20 → 30 → 60 分钟（健康时逐渐增加）

**检测项：**
- Loss 是否为 NaN 或 Inf
- Loss 是否发散（连续上升）
- GPU 利用率是否骤降
- 学习率是否异常
- 梯度是否爆炸或消失

---

### `/vast-gpu` — Vast.ai GPU 租用

按需租、管理、销毁 Vast.ai GPU 实例。

```bash
/vast-gpu "rent 1x A100 80GB for 4 hours"
```

**前置条件：**
```bash
pip install vastai
vastai set api-key YOUR_KEY
# SSH 公钥上传到 https://cloud.vast.ai/manage-keys/
```

**状态文件：** `vast-instances.json`（项目根目录），追踪所有活跃实例

**操作：** provision（租用）、status（状态）、destroy（销毁）

---

## 五、结果分析与声明验证

### `/result-to-claim` — 实验结果 → 可支撑的声明

实验完成后，判断结果能支撑什么声明、不能支撑什么、还缺什么证据。

```bash
/result-to-claim "tactile grasping experiments"
```

**执行阶段：**
1. **Step 1** — 收集结果（W&B、EXPERIMENT_LOG.md、日志文件）
2. **Step 1.5** — 检查实验审计（如果没有 `EXPERIMENT_AUDIT.json` → 先调用 `/experiment-audit`）
3. **Step 2** — GPT-5.4 评估（输出 `claim-assessment.schema.json` 结构化 JSON）
4. **Step 3** — 路由决策：
   - `yes` → 进入 `/ablation-planner` + 论文写作
   - `partial` → 补充实验
   - `no` → 深度失败分析（`/codex:rescue` 5 层诊断）→ 修复 → 重试
5. **Step 5** — 更新 Research Wiki

---

### `/ablation-planner` — 消融实验规划

以审稿人视角设计消融实验，验证每个组件的贡献。

```bash
/ablation-planner "our tactile encoding method"
```

**使用时机：** 主结果通过 `/result-to-claim`（`claim_supported = yes/partial`）后。

**执行：** GPT-5.4 设计消融方案 → Claude Code 评估可行性 → 实现并运行。

---

### `/analyze-results` — 统计分析

```bash
/analyze-results "results/"
```

**执行：**
1. 定位结果文件（JSON/CSV）
2. 构建对比表（自变量 × 因变量 × baseline delta）
3. 统计分析（mean ± std、趋势、异常值）
4. 生成洞察（观察 → 解读 → 含义 → 下一步）

---

## 六、自动评审与深度创新

### `/auto-review-loop` — 工作流 2：自动评审循环

GPT-5.4 打分 → 修复 → 再审，循环直到通过。

```bash
/auto-review-loop "tactile grasping" — venue: RAL
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICLR` | 目标 venue（决定评分标准和阈值） |
| `max rounds` | `4` | 最大循环轮数 |
| `human checkpoint` | `false` | 每轮后暂停 |
| `RESEARCH_DRIVEN_FIX` | `true` | 文献驱动修复 |
| `effort` | `balanced` | 工作强度 |
| `compact` | `false` | 精简日志 |
| `reviewer` | `codex` | 评审后端：`codex`（默认 GPT-5.4）/ `oracle-pro`（GPT-5.4 Pro，需安装 Oracle MCP）/ `rescue`（深度诊断）/ `adversarial`（代码审查） |

> **GPT-5.4 Pro：** 添加 `— reviewer: oracle-pro` 使用 GPT-5.4 Pro 做评审（默认浏览器模式，需 Chrome 登录 ChatGPT Pro）。适合最终压力测试、深度数学推理、复杂理论论文评审。详见 `shared-references/reviewer-routing.md`。

**Venue 阈值：**

| Venue | 通过分数 | 维度要求 |
|-------|---------|---------|
| RAL / TRO | >= 7/10 | Experimental Rigor >= 7 |
| ICRA | >= 7/10 | Technical Soundness >= 7 |
| CVPR / ICCV | >= 7/10 | Novelty >= 7 |
| NeurIPS / ICML / ICLR | >= 7/10 | 无 BLOCKING 弱点 |

**每轮执行：**
1. **Phase A** — GPT-5.4 独立评审（读取文件，5 维度打分）
   - A.0 — 独立文件审计（`/codex:adversarial-review`）
2. **Phase B** — 解析弱点 + Review Feedback 验证（不盲目接受评审意见）
3. **Phase B.5** — 文献驱动修复设计：
   - 分类根因 vs 症状
   - 搜索文献找解决原理（五层原理提炼协议）
   - 设计 2-3 个修复策略
4. **Phase C** — 实现修复
   - C.1.5 — **强制代码审查**（不可跳过）
   - C.2 — 超参数敏感性快速测试
   - C.3 — 多 seed 评估
5. **Phase C.5** — 修复验证（统计显著性 + 根因确认 + 独立验证）
6. **Phase C.6** — 协作升级（如果 2-3 个策略都失败 → 切换合作模式联合 GPT-5.4 解题）
7. **Phase D** — 下一轮评审
8. **Phase E** — 反思文档

**状态恢复：** `REVIEW_STATE.json`（轮次、分数、状态、时间戳）

**输出文件：** `AUTO_REVIEW.md`（累积评审日志）

---

### `/deep-innovation-loop` — 40+ 轮深度方法进化

与 `/auto-review-loop` 的核心区别：不是修补症状，而是从文献中提炼原理来驱动方法进化。

```bash
/deep-innovation-loop "improve manipulation baseline" — venue: RAL, baseline: DAgger
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `RAL` | 目标 venue |
| `DOMAIN` | `robotics` | 研究领域 |
| `PRIMARY_BASELINE` | **必填** | 基线名称 |
| `TARGET_SCORE` | `8` | 目标 GPT-5.4 评审分数 |
| `MAX_ROUNDS` | `50` | 最大轮数 |
| `human checkpoint` | `false` | 诊断后暂停 |
| `compact` | `false` | 精简日志 |

**三阶段策略：**
- **探索期**（1-15 轮）— 大胆尝试，宽搜索。5 轮无进步 → 转精炼
- **精炼期**（16-30 轮）— 优化最佳变体。4 轮无进步 → 转打磨
- **打磨期**（31+ 轮）— 消融 + 鲁棒性。3 轮无进步 → 终止

**每轮循环（Phase A-E）：**
- A: 诊断根因（对抗模式，卡住 3+ 轮自动切合作模式）
- B: 搜索文献（冷却期 3 轮，避免重复搜索同一主题）
- C: 设计创新变体（最多 3 个活跃变体）
- D: 实现 + 评估（强制代码审查 + 多 seed + 消融）
- E: 反思 + 学习（每 5 轮做融合优化）

**输出文件：**
- `innovation-logs/EVOLUTION_LOG.md` — 进化历史
- `innovation-logs/TECHNIQUE_LIBRARY.md` — 累积技术库

---

### `/auto-review-loop-llm` — 任意 LLM 评审

使用任意 OpenAI 兼容 API 做评审（替代默认的 Codex CLI）。

```bash
/auto-review-loop-llm "topic" — model: deepseek-v3
```

### `/auto-review-loop-minimax` — MiniMax 评审

```bash
/auto-review-loop-minimax "topic"
```

---

## 七、论文写作

### `/paper-writing` — 工作流 3：论文写作全流程

串联 `/paper-plan` → `/paper-figure` → `/paper-write` → `/paper-compile` → `/auto-paper-improvement-loop` + 验证门。

```bash
/paper-writing "NARRATIVE_REPORT.md" — venue: ICRA
```

（参数和流程详见 README.md 工作流 3 部分）

---

### `/paper-plan` — 论文大纲

```bash
/paper-plan "tactile manipulation paper"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICLR` | 目标 venue |

**输入：** `NARRATIVE_REPORT.md` 或项目中的 review 结论和实验结果

**输出：** `PAPER_PLAN.md`（大纲 + claims-evidence 矩阵 + 图表计划 + 页数分配）

---

### `/paper-figure` — 发表级图表

```bash
/paper-figure "paper/"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `STYLE` | `publication` | 风格：publication / poster / slide |
| `DPI` | `300` | 分辨率 |
| `FORMAT` | `pdf` | 输出格式 |
| `COLOR_PALETTE` | `tab10` | 配色方案：tab10 / Set2 / colorblind |

**自动生成：** 折线图、柱状图、散点图、热力图、箱线图、LaTeX 表格

**需要手动创建：** 架构图、生成图像网格、照片

**输出：** `figures/` 目录 + `figures/latex_includes.tex`

---

### `/paper-write` — 逐章 LaTeX 生成

```bash
/paper-write "ICRA"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `ICLR` | 目标 venue |
| `ANONYMOUS` | `true` | 匿名模式（IEEE 设为 `false`） |
| `MAX_PAGES` | `9` | 正文页数限制 |
| `DBLP_BIBTEX` | `true` | 真实 BibTeX 获取 |

**特色功能：**
- **Step 3.5** — 定理论文一致性检查（主体 vs 附录的定理表述）
- **Step 4** — 强制 BibTeX 卫生验证（DBLP/CrossRef 核对 + 死条目检测）
- **Step 5** — 5-pass 科学写作审查：
  1. 去废话（"In order to" → "To"）
  2. 主动语态
  3. 句式优化
  4. 关键词一致性（"Banana Rule"）
  5. 数值/引用完整性
- **Step 6** — GPT-5.4 交叉审查

---

### `/paper-compile` — LaTeX 编译

```bash
/paper-compile "paper/"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `ENGINE` | `pdflatex` | 引擎：pdflatex / xelatex（CJK 文字）/ lualatex |
| `MAX_COMPILE_ATTEMPTS` | `3` | 最大修复重编译次数 |

**自动修复：** 未定义引用、缺失包、BibTeX 错误、overfull hbox

---

### `/auto-paper-improvement-loop` — GPT-5.4 评审 ×2

```bash
/auto-paper-improvement-loop "paper/"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `human checkpoint` | `false` | 每轮后暂停 |
| `REVIEWER_BIAS_GUARD` | `true` | 每轮使用全新评审（不带前轮上下文） |

**特色功能：**
- **偏见防护** — 每轮评审都是全新 `codex exec`，不用 `resume --last`
- **Step 4.5** — 定理重述回归测试（防止修复引入表述漂移）
- **Step 5.5** — Kill Argument Exercise（理论论文的对抗性攻防）
- **Step 8** — 位置感知格式检查（正文/附录/参考文献不同阈值）

---

### `/paper-illustration` — AI 架构图

```bash
/paper-illustration "method architecture diagram"
```

使用 Gemini 生成架构图、方法示意图，Claude 监督迭代修改。需要 `GEMINI_API_KEY`。

---

## 八、论文验证与审计

### `/proof-checker` — 数学证明验证

20 类问题分类法，两轴严重度评估，多轮验证 + 反例红队。

```bash
/proof-checker "paper/sections/appendix_proofs.tex"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `MAX_REVIEW_ROUNDS` | `3` | 最大验证轮数 |

**20 类问题分类法（4 组）：**
- **Group A: 逻辑与证明结构**（7 类）— 无依据断言、未证子声明、量词错误等
- **Group B: 分析与测度论**（6 类）— 非法交换、非一致收敛等
- **Group C: 模型与参数追踪**（6 类）— 缺失推导、隐藏假设等
- **Group D: 范围与声明**（2 类）— 过度声明、引用不匹配

**严重度评估：**
- Axis A（证明状态）：INVALID / UNJUSTIFIED / UNDERSTATED / OVERSTATED / UNCLEAR
- Axis B（影响范围）：GLOBAL / LOCAL / COSMETIC
- 组合标签：FATAL / CRITICAL / MAJOR / MINOR

**执行阶段：**
1. Phase 0 — 定位证明文件，构建章节地图
2. Phase 0.5 — 创建证明义务账本（依赖 DAG、假设账本、符号表）
3. Phase 1 — GPT-5.4 第一轮审查
4. Phase 1.5 — 反例红队
5. Phase 2 — 修复实现
6. Phase 3 — GPT-5.4 重新审查
7. Phase 3.5 — 独立验证（对 FATAL/CRITICAL 修复）

**输出文件：** `PROOF_AUDIT.md`、`PROOF_SKELETON.md`

---

### `/paper-claim-audit` — 零上下文数字核对

**核心原则：** 全新的 GPT-5.4 评审（零上下文），只看论文 .tex 和原始结果文件，验证每个数字是否匹配。

```bash
/paper-claim-audit "paper/"
```

**检测项：**
- 数字膨胀（85.3% vs 84.7%）
- 最佳 seed 挑选（best vs mean）
- 配置不匹配
- 聚合不匹配（声称 vs 实际 run 数）
- Delta 错误（相对改进计算错误）
- Caption-表格不匹配

**输出文件：** `PAPER_CLAIM_AUDIT.md` + `PAPER_CLAIM_AUDIT.json`

---

### `/experiment-audit` — 跨模型实验完整性审计

检测实验中的常见造假/错误模式。

```bash
/experiment-audit "results/"
```

**检测项（6 项）：**
1. Ground Truth 来源验证
2. 分数归一化审计
3. 结果文件存在性验证
4. 死代码检测
5. 范围评估
6. 评估类型分类

**执行原则：** Claude 收集文件路径（不解读），GPT-5.4 独立读取并判断。

**输出文件：** `EXPERIMENT_AUDIT.md` + `EXPERIMENT_AUDIT.json`

---

### `/proof-writer` — 定理证明撰写

```bash
/proof-writer "Theorem: convergence of algorithm X under conditions Y"
```

**输出状态：**
- `PROVABLE AS STATED` — 完整证明
- `PROVABLE AFTER WEAKENING` — 修正声明 + 证明
- `NOT CURRENTLY JUSTIFIED` — 障碍报告

**输出文件：** `PROOF_PACKAGE.md`

---

### `/formula-derivation` — 公式推导

```bash
/formula-derivation "derive the loss function for our tactile encoder"
```

**输出状态：**
- `COHERENT AS STATED` — 连贯推导包
- `COHERENT AFTER REFRAMING` — 修正假设后的推导包
- `NOT YET COHERENT` — 障碍报告

**输出文件：** `DERIVATION_PACKAGE.md`

---

## 九、展示与传播

### `/paper-slides` — 会议演讲幻灯片

```bash
/paper-slides "paper/" — talk type: oral, talk minutes: 20
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `NeurIPS` | 会议（决定配色） |
| `TALK_TYPE` | `spotlight` | 类型：oral / spotlight / poster-talk / invited |
| `TALK_MINUTES` | `15` | 演讲时长 |
| `ASPECT_RATIO` | `16:9` | 幻灯片比例 |
| `SPEAKER_NOTES` | `true` | 生成演讲稿 |

**幻灯片数量：**
- poster-talk（3-5 分钟）→ 5-8 张
- spotlight（5-8 分钟）→ 8-12 张
- oral（15-20 分钟）→ 15-22 张
- invited（30-45 分钟）→ 25-40 张

**输出：** `slides/` — Beamer PDF + 可编辑 PPTX + 演讲稿 + Q&A 预案

---

### `/paper-poster` — 会议海报

```bash
/paper-poster "paper/" — venue: ICRA, poster size: A0
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `venue` | `NeurIPS` | 会议（决定配色） |
| `POSTER_SIZE` | `A0` | 尺寸：A0 / A1 |
| `ORIENTATION` | `landscape` | 方向：landscape / portrait |
| `COLUMNS` | `4` | 列数 |

**输出：** `poster/` — tcbposter PDF + 可编辑 PPTX + SVG

---

### `/mermaid-diagram` — Mermaid 图表

```bash
/mermaid-diagram "system architecture of our tactile pipeline"
```

支持 20+ 种图表类型：流程图、时序图、类图、ER 图、甘特图等。

**输出：** `figures/` — `.mmd` + `.md` 文件

---

### `/pixel-art` — 像素风 SVG

```bash
/pixel-art "a robot holding a sensor"
```

**输出：** 像素风 SVG 插画（7px 像素，适用于 README 和文档）

---

## 十、Rebuttal

### `/rebuttal` — 工作流 4：Rebuttal

（详见 README.md 工作流 4 部分）

```bash
/rebuttal "paper/ + reviews.txt" — venue: ICML, character limit: 5000
```

**三道安全门 + 三版输出 + REVISION_PLAN.md 追踪。** 详细参数见 README.md。

---

## 十一、知识管理与自优化

### `/research-wiki` — 持久化知识图谱

跨整个研究生命周期积累论文、idea、实验、声明及其关系。

```bash
/research-wiki "ingest paper: https://arxiv.org/abs/2401.12345"
```

**子命令：**
- `init` — 初始化 wiki
- `ingest` — 添加论文/idea/实验/声明
- `query` — 查询知识库
- `update` — 更新实体
- `lint` — 检查一致性
- `stats` — 统计信息

**实体类型：**
- `paper:<slug>` — 论文（`research-wiki/papers/`）
- `idea:<id>` — 研究 idea（`research-wiki/ideas/`）
- `exp:<id>` — 实验（`research-wiki/experiments/`）
- `claim:<id>` — 声明（`research-wiki/claims/`）

**关键文件：**
- `index.md` — 自动生成的索引
- `log.md` — 时间线日志（追加模式）
- `gap_map.md` — 领域 gap 地图
- `query_pack.md` — 压缩摘要（< 8000 字符，供其他 skill 快速加载）
- `graph/edges.jsonl` — 类型化关系图

---

### `/meta-optimize` — ARIS 自优化

分析 ARIS 使用日志，提出 SKILL.md 参数优化建议。

```bash
/meta-optimize
```

**前置条件：** `.aris/meta/events.jsonl` 中至少 5 次 skill 调用记录。

**执行：** 分析使用模式 → GPT-5.4 评估 → 提出优化建议 → 用户审批后应用。

---

## 十二、基础设施与工具

### `/system-profile` — 系统性能分析

```bash
/system-profile "profile my training script"
```

**分析维度：** CPU 性能、内存使用、GPU 利用率、网络互联

**使用的工具：** cProfile、py-spy、line_profiler、tracemalloc、nvidia-smi、nvitop、torch.profiler

---

### `/feishu-notify` — 飞书/Lark 通知

```bash
/feishu-notify "实验完成，分数 7.5/10"
```

**配置：** `~/.claude/feishu.json`

```json
{
  "mode": "push",
  "webhook_url": "https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
}
```

**模式：**
- `off` 或文件不存在 — 关闭
- `push` — Webhook 推送通知
- `interactive` — 双向交互（私聊审批/回复）

---

### `/grant-proposal` — 基金申请书

```bash
/grant-proposal "tactile robot manipulation — NSF CAREER"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `GRANT_TYPE` | `KAKENHI` | 类型：KAKENHI / NSF / NSFC / ERC / DFG / SNSF / ARC / NWO / GENERIC |
| `GRANT_SUBTYPE` | `auto` | 子类型自动检测 |
| `OUTPUT_FORMAT` | `markdown` | 输出格式：markdown / latex |
| `LANGUAGE` | `auto` | 语言自动检测（KAKENHI→日语，NSFC→中文，其他→英语） |
| `AUTO_PROCEED` | `false` | 始终等待用户确认 |

**支持的基金类型：**
- **KAKENHI**（日本 JSPS）— 基盤 A/B/C、若手、スタート支援、DC1/DC2
- **NSF**（美国）— CAREER、CRII、Standard
- **NSFC**（中国国自然）— 面上、青年、优青、杰青、海外优青、重点
- **ERC**（欧盟）— Starting / Consolidator / Advanced
- **DFG / SNSF / ARC / NWO** — 各自格式

**输出：** `grant-proposal/GRANT_PROPOSAL.md`

---

## 十三、领域专用技能

### `/idea-discovery-robot` — 机器人/具身智能 Idea 发现

工作流 1 的机器人领域适配版，按 embodiment、sim2real、安全约束筛选 idea。

```bash
/idea-discovery-robot "dexterous manipulation with tactile sensing"
```

---

### `/comm-lit-review` — 通信领域文献检索

通信/无线/网络专用文献检索，优先搜索 IEEE Xplore、ScienceDirect、ACM DL。

```bash
/comm-lit-review "semantic communication for 6G"
```

**搜索优先级：** Zotero → Obsidian → 本地 → IEEE Xplore → ScienceDirect → ACM DL → Web

---

### `/dse-loop` — 设计空间探索

自动设计空间探索循环（体系结构/EDA），迭代调参直到目标达成。

```bash
/dse-loop "optimize gem5 cache parameters for latency"
```

| 参数 | 默认 | 说明 |
|------|------|------|
| `TIMEOUT` | `2h` | 总时间预算 |
| `MAX_ITERATIONS` | `50` | 最大迭代数 |
| `PATIENCE` | `10` | 无改进容忍轮数 |
| `OBJECTIVE` | `minimize` | 优化方向：minimize / maximize |

---

## 十四、工具脚本 CLI

ARIS 的 Python/Shell 工具脚本也可以独立在命令行使用。

### `tools/arxiv_fetch.py`

```bash
# 搜索论文
python3 tools/arxiv_fetch.py search "robot manipulation" --max 20
python3 tools/arxiv_fetch.py search "tactile sensing" --category cs.RO --sort-by submittedDate --sort-order descending

# 按 ID 下载
python3 tools/arxiv_fetch.py download 2401.12345 --dir papers/

# 高级搜索
python3 tools/arxiv_fetch.py search "attention" --title --abstract --max 50
python3 tools/arxiv_fetch.py search "John Smith" --author --max 10
```

| 参数 | 说明 |
|------|------|
| `--max N` | 最大结果数 |
| `--category CAT` | arXiv 类别（cs.RO, cs.LG, cs.CV 等） |
| `--title` | 仅搜索标题 |
| `--abstract` | 仅搜索摘要 |
| `--author` | 搜索作者 |
| `--sort-by` | 排序字段：relevance / submittedDate / lastUpdatedDate |
| `--sort-order` | 排序方向：ascending / descending |
| `--dir DIR` | 下载目录 |

---

### `tools/semantic_scholar_fetch.py`

```bash
# 搜索论文
python3 tools/semantic_scholar_fetch.py search "tactile grasping" --max 15 --min-citations 10

# 获取论文详情
python3 tools/semantic_scholar_fetch.py paper "10.1109/TRO.2024.1234567"
python3 tools/semantic_scholar_fetch.py paper "ARXIV:2401.12345"

# 引用追踪
python3 tools/semantic_scholar_fetch.py citations "ARXIV:2401.12345" --max 20
python3 tools/semantic_scholar_fetch.py references "ARXIV:2401.12345"

# 作者论文
python3 tools/semantic_scholar_fetch.py author-papers "AuthorID" --max 30
```

| 参数 | 说明 |
|------|------|
| `--max N` | 最大结果数 |
| `--min-citations N` | 最低引用数 |
| `--year RANGE` | 年份过滤（如 2024-2026） |
| `--venue VENUE` | venue 过滤 |
| `--fields-of-study FIELD` | 领域过滤 |
| `--publication-types TYPE` | 类型过滤：JournalArticle / Conference 等 |
| `--open-access` | 仅开放获取 |

---

### `tools/exa_search.py`

```bash
# 搜索
python3 tools/exa_search.py search "robot learning from demonstration" --max 10
python3 tools/exa_search.py search "RAG pipeline" --include-domains "arxiv.org,huggingface.co"
python3 tools/exa_search.py search "sim2real" --category "research paper" --start-date 2025-01-01

# 找相似页面
python3 tools/exa_search.py find-similar "https://arxiv.org/abs/2401.12345" --max 5

# 获取指定 URL 内容
python3 tools/exa_search.py get-contents "https://example.com/paper" --content text
```

| 参数 | 说明 |
|------|------|
| `--max N` | 最大结果数 |
| `--type TYPE` | 搜索类型：auto / neural / fast / instant |
| `--category CAT` | 类别：research paper / news / company / personal site |
| `--content MODE` | 内容模式：highlights / text / summary / none |
| `--max-chars N` | 内容最大字符数 |
| `--include-domains` | 限定域名（逗号分隔） |
| `--exclude-domains` | 排除域名 |
| `--include-text` | 包含关键词 |
| `--exclude-text` | 排除关键词 |
| `--start-date` | 起始日期（ISO 8601） |
| `--end-date` | 结束日期 |

---

### `tools/research_wiki.py`

```bash
# 初始化
python3 tools/research_wiki.py init

# 添加实体
python3 tools/research_wiki.py slug "Paper Title Here"  # 生成 slug

# 添加关系
python3 tools/research_wiki.py add_edge "paper:attention-is-all" "inspires" "idea:cross-attention-for-tactile"

# 重建查询包
python3 tools/research_wiki.py rebuild_query_pack

# 统计
python3 tools/research_wiki.py stats

# 记录事件
python3 tools/research_wiki.py log "Added 3 new papers from ICRA 2026"
```

---

### `tools/figure_renderer.py`

JSON → SVG 发表级图表渲染器。

```bash
# 渲染
python3 tools/figure_renderer.py render spec.json --output figures/architecture.svg

# 验证规格
python3 tools/figure_renderer.py validate spec.json

# 查看 schema 文档
python3 tools/figure_renderer.py schema
```

支持：节点（矩形/圆形/菱形/椭圆）、边（直线/曲线/自环）、组、标签。确定性渲染（同输入 = 同输出）。

---

### `tools/smart_update.sh`

智能 skill 更新工具，比较本地 skill 与上游仓库的差异。

```bash
# 干跑（仅分析）
bash tools/smart_update.sh

# 应用更新
bash tools/smart_update.sh --apply

# 指定路径
bash tools/smart_update.sh --upstream /path/to/repo/skills --local ~/.claude/skills
```

检测类别：相同 / 新增 / 可安全更新 / 需要合并（有个人自定义）/ 仅本地

---

### `tools/save_trace.sh`

保存评审追踪日志。

```bash
bash tools/save_trace.sh \
  --skill "auto-review-loop" \
  --purpose "round-1-review" \
  --model "gpt-5.4" \
  --thread-id "019d8fe0-..." \
  --prompt-file /tmp/prompt.txt \
  --response-file /tmp/response.txt
```

追踪文件保存在 `.aris/traces/<skill>/<date>_run<NN>/`。
