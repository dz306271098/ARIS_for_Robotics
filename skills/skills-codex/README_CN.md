# `skills-codex` 说明

这是 ARIS 的 **Codex 原生执行技能包**。

## 这个包现在的定位

`skills/skills-codex/` 已经切成 ARIS 的 **Codex 主线基础包**。安装到 `~/.codex/skills/` 后，可作为以下三条路径的共同底座：

- 纯 Codex 执行
- Codex 执行 + Claude Code 审阅（`skills-codex-claude-review/`）
- Codex 执行 + Gemini 审阅（`skills-codex-gemini-review/`）

本次同步补齐了之前 Codex 包里缺失的能力面，包括：

- `deep-innovation-loop`
- `meta-optimize`
- `research-wiki`
- `semantic-scholar`
- `system-profile`
- `vast-gpu`
- `training-check`
- `result-to-claim`
- `ablation-planner`
- `rebuttal`

其中 `shared-references/` 是支持目录，不算可直接调用的 skill。

## 这些能力如何嵌入主线

这些补齐过来的能力现在不是边缘附加件，而是主线的一部分：

- `research-wiki` 是长期研究记忆层。建议在 `CODEX.md` 和 `RESEARCH_BRIEF.md` 基本稳定后初始化一次，然后让 `/research-lit`、`/idea-creator`、`/result-to-claim` 持续更新它。
- `deep-innovation-loop` 现在已经进入默认 `/research-pipeline` 主线，实际链路是：
  `/idea-discovery -> implement -> /run-experiment -> innovation gate -> /deep-innovation-loop? -> /auto-review-loop`
- `meta-optimize` 不放进脆弱的实验执行中间，而是在阶段性工件已经累计起来之后，作为维护环去优化 harness 本身。它读取的重点证据包括 `AUTO_REVIEW.md`、`innovation-logs/`、`refine-logs/`、`paper/`、`rebuttal/` 和 `CODEX.md`。

可以把三者简单理解为：

- `research-wiki` = 记忆层
- `deep-innovation-loop` = 主线进化阶段
- `meta-optimize` = 维护层

## 安装

```bash
mkdir -p ~/.codex/skills
cp -a skills/skills-codex/* ~/.codex/skills/
```

如果你还要叠加审稿 overlay，必须先装这个基础包，再覆盖安装 overlay。

## 项目配置命名

Codex 主线路径下，推荐把项目级配置和状态文件命名为 `CODEX.md`：

- `CODEX.md`：主线路径唯一配置名
- 本包内主线 skill、工具和文档都按读取 `CODEX.md` 设计

## 边界说明

这个包只负责迁移 **skill 文件和支持引用**，不负责你的完整运行环境。你仍然需要自行准备：

- Python / LaTeX / GPU / SSH 环境
- MCP server
- API key 或 CLI 登录态
- 项目自己的 `CODEX.md`、数据集和代码仓库
