# `skills-codex-claude-review` 说明

这是 ARIS 当前主线使用的 reviewer overlay：

- `Codex` 作为主执行者
- `Claude Code CLI` 作为审稿人
- `claude-review` MCP bridge 作为 reviewer transport

它不是新的完整技能包，而是叠加在 `skills/skills-codex/` 之上的薄覆盖层。

## 这个包负责什么

- 只覆盖 reviewer-aware 的 Codex 技能
- 不重复打包模板和共享引用目录
- 不替代基础包 `skills/skills-codex/`

安装顺序固定为：

1. 先安装 `skills/skills-codex/*`
2. 再覆盖安装 `skills/skills-codex-claude-review/*`
3. 最后注册 `claude-review` MCP

## 当前覆盖范围

覆盖范围以 `tools/generate_codex_claude_review_overrides.py` 中的 `TARGET_SKILLS` 为准。

当前覆盖的技能是：

```text
ablation-planner
experiment-bridge
deep-innovation-loop
idea-creator
idea-discovery
idea-discovery-robot
research-review
novelty-check
research-refine
auto-review-loop
grant-proposal
paper-plan
paper-figure
paper-poster
paper-slides
paper-write
paper-writing
auto-paper-improvement-loop
result-to-claim
rebuttal
training-check
```

## 安装方式

先安装基础包：

```bash
mkdir -p ~/.codex/skills
cp -a skills/skills-codex/* ~/.codex/skills/
```

再安装这个 overlay：

```bash
cp -a skills/skills-codex-claude-review/* ~/.codex/skills/
```

最后注册 bridge：

```bash
mkdir -p ~/.codex/mcp-servers/claude-review
cp mcp-servers/claude-review/server.py ~/.codex/mcp-servers/claude-review/server.py
codex mcp add claude-review \
  --env CLAUDE_REVIEW_MODEL='claude-opus-4-7[1m]' \
  --env CLAUDE_REVIEW_FALLBACK_MODEL='claude-opus-4-6' \
  -- python3 ~/.codex/mcp-servers/claude-review/server.py
```

如果你的 Claude 访问依赖代理，优先直接运行仓库安装器：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

安装器会默认把当前 shell 里的常见代理环境变量写进 `claude-review` MCP。手工 `codex mcp add` 时也需要把相同代理变量通过 `--env` 传进去，否则 direct CLI 可能成功，但 `mcp__claude_review__review` 仍会失败。

如果你的 Claude 登录依赖 wrapper，再补：

```bash
cp mcp-servers/claude-review/run_with_claude_aws.sh ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
chmod +x ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
codex mcp add claude-review \
  --env CLAUDE_REVIEW_MODEL='claude-opus-4-7[1m]' \
  --env CLAUDE_REVIEW_FALLBACK_MODEL='claude-opus-4-6' \
  -- ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
```

默认 reviewer 模型链是：

- 首选 `claude-opus-4-7[1m]`
- 回退 `claude-opus-4-6`

这个回退只在 MCP 调用没有显式传 `model` 时生效。

## 为什么需要这个包

`skills/skills-codex/` 负责主线执行语义。

这个 overlay 负责把 reviewer-aware 技能中的 reviewer 调用改写到：

- `mcp__claude-review__review_start`
- `mcp__claude-review__review_reply_start`
- `mcp__claude-review__review_status`

也就是说：

- 基础包表达“这里需要外部 reviewer”
- overlay 决定 reviewer 通过 Claude bridge 落地

## 维护方式

不要把这个目录长期当作手工分叉来源。

上游 `skills/skills-codex/` 更新后，重新生成：

```bash
python3 tools/generate_codex_claude_review_overrides.py
```

然后再跑：

```bash
python3 tools/check_codex_mainline_parity.py
git diff --check
bash scripts/smoke_test_codex_claude_mainline.sh
bash scripts/check_claude_review_runtime.sh
```
