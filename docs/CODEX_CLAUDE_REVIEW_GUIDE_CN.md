# Codex + Claude 审稿指南

这是 ARIS 当前的 **主线路径**：

- **Codex** 负责执行
- **Claude Code CLI** 负责审稿
- 通过本地 `claude-review` MCP bridge 传输审稿请求

如果你现在是第一次用 ARIS，优先走这条路径。

## 架构

- 基础执行技能包：`skills/skills-codex/`
- 审稿覆盖层：`skills/skills-codex-claude-review/`
- 审稿 bridge：`mcp-servers/claude-review/`

安装顺序必须保持：

1. 先安装 `skills/skills-codex/*`
2. 再安装 `skills/skills-codex-claude-review/*`
3. 最后注册 `claude-review` MCP

`scripts/install_codex_claude_mainline.sh` 会自动按这个顺序执行。

## 安装

```bash
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git
cd Auto-claude-code-research-in-sleep
bash scripts/install_codex_claude_mainline.sh
```

如果你的 Claude 登录依赖 `claude-aws` 之类的 wrapper，改用：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --use-aws-wrapper
```

如果你想固定 Claude 审稿模型：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --review-model claude-opus-4-1
```

卸载：

```bash
bash ~/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh
```

这个本地卸载脚本会在安装时自动复制过去，并且只回滚 ARIS 安装器实际接管过的路径。

## 验证

1. 检查 MCP 注册：

```bash
codex mcp list
```

2. 检查 Claude CLI 登录：

```bash
claude -p "Reply with exactly READY" --output-format json --tools ""
```

3. 在项目中启动 Codex：

```bash
codex -C /path/to/your/project
```

维护者冒烟测试：

```bash
bash scripts/smoke_test_codex_claude_mainline.sh
```

## 覆盖范围

当前 overlay 已覆盖 `skills/skills-codex/` 里所有预定义的 reviewer-aware Codex 技能，这些技能之前依赖二级 Codex reviewer 或直接 `mcp__codex__codex*` 审稿调用：

- `ablation-planner`
- `auto-paper-improvement-loop`
- `auto-review-loop`
- `deep-innovation-loop`
- `experiment-bridge`
- `grant-proposal`
- `idea-creator`
- `idea-discovery`
- `idea-discovery-robot`
- `novelty-check`
- `paper-figure`
- `paper-plan`
- `paper-poster`
- `paper-slides`
- `paper-write`
- `paper-writing`
- `rebuttal`
- `research-refine`
- `research-review`
- `result-to-claim`
- `training-check`

## 工作流嵌入方式

这条主线不是“Claude 审所有东西”，而是分层协作：

- `Codex` 负责执行、实现、实验启动、本地文件修改和状态维护。
- `Claude Code` 负责 reviewer-aware 技能里的外部审稿角色，这些调用都通过 `claude-review` bridge 进入。
- `research-wiki` 是长期研究记忆层。初始化一次之后，让 `/research-lit`、`/idea-creator`、`/result-to-claim` 持续同步即可。
- `deep-innovation-loop` 已经进入默认 `/research-pipeline` 路径。实际链路是：
  `/idea-discovery -> implement -> /run-experiment -> innovation gate -> /deep-innovation-loop? -> /auto-review-loop`
- 在 `deep-innovation-loop` 内，Codex 仍负责实现与实验执行，但其中外部诊断、设计审查、实现审查这些 reviewer checkpoint 现在也统一走 Claude overlay。
- `meta-optimize` 是里程碑后的维护环，不插在脆弱实验执行中间。等 `AUTO_REVIEW.md`、`innovation-logs/`、`refine-logs/`、`paper/`、`rebuttal/` 等工件积累起来后再跑。

所以边界要理解清楚：Claude 负责审稿，Codex 负责主线执行与维护层。

## 项目配置命名

这条 Codex 主线路径下，推荐使用项目级 `CODEX.md` 来存放：

- 执行器说明
- 环境说明
- `## Pipeline Status`

这条路径下，`CODEX.md` 是唯一主线项目配置名。

## 异步审稿流程

遇到长论文或长项目审稿时，优先使用：

- `review_start`
- `review_reply_start`
- `review_status`

实际链路是：

`Codex -> claude-review MCP -> 本地 Claude CLI -> Claude 后端`

多出来的本地 CLI hop，就是长同步调用更容易撞上宿主 MCP 超时的主要原因。

## 结构化输出

`claude-review` bridge 现在额外支持可选的 `jsonSchema` / `json_schema` 参数，并透传给 Claude CLI 的 `--json-schema`。当某个 skill 需要结构化 reviewer 输出时，直接走这条能力即可。

## 维护

上游 Codex skill 更新后，重新生成 overlay：

```bash
python3 tools/generate_codex_claude_review_overrides.py
```
