# Codex + Claude 主线维护指南

这份文档只服务当前公开主线：

- `Codex` 负责执行
- `Claude Code CLI` 负责审稿
- 本地 `claude-review` MCP bridge 负责传输 reviewer 请求

如果你只是使用主线，优先阅读 [`README.md`](../README.md)。
如果你要维护 overlay、bridge、安装器或主线技能，再看这份文档。

---

## 1. 架构分层

当前主线路径固定拆成三层：

- 基础执行技能包：`skills/skills-codex/`
- Claude 审稿覆盖层：`skills/skills-codex-claude-review/`
- 审稿 bridge：`mcp-servers/claude-review/`

安装顺序必须保持：

1. 先安装 `skills/skills-codex/*`
2. 再安装 `skills/skills-codex-claude-review/*`
3. 最后注册 `claude-review` MCP

这一点不能回退成“单包混写 reviewer 实现”，也不能回退成“Claude 重新承担主线编排器”。

主线角色边界固定为：

- `Codex`：实现、改代码、跑实验、维护状态、串联工作流
- `Claude Code`：承担 reviewer-aware 技能中的外部审稿角色
- `claude-review`：只做 reviewer transport，不做主线编排

所有会改代码的执行型 workflow 现在还共享四层硬合同：

- **Mandatory Test Gate**：每次写完代码后，先过模块测试和 workflow smoke test，再允许部署或进入下一轮 review
- **Reviewer Resolution Protocol**：每条 reviewer 反馈都必须分类并在有争议时回到同一 thread 讨论，直到收敛到 fix / analysis / experiment / claim change
- **Unattended Runtime Protocol**：`CODEX.md -> ## Autonomy Profile`、`AUTONOMY_STATE.json`、watchdog、W&B 和宿主机 health check 组成无人值守主线控制层；`review_fallback_mode: retry_then_local_critic` 只允许临时本地批判性审查，最终 claim freeze / paper polish 仍要 replay 外部 reviewer
- **Execution Profile**：`CODEX.md -> ## Execution Profile` 现在也是主线合同的一部分。默认仍是 `python_ml`，但已经支持把同一条主线切换到 `cpp_algorithm + cmake + cpu_benchmark`、`cpp_algorithm + cmake + cpu_cuda_mixed`、以及 `robotics_slam + (cmake | cmake_ros2) + slam_offline`，而不是再维护平行 workflow

---

## 2. 安装与运行

推荐直接使用仓库里的安装脚本：

```bash
bash scripts/install_codex_claude_mainline.sh
```

如果你当前 shell 已经设置了代理环境变量，安装器会默认把这些代理变量一并写入 `claude-review` 的 MCP 配置。需要禁用这个行为时，显式加：

```bash
bash scripts/install_codex_claude_mainline.sh --no-inherit-proxy-env
```

如果你的 Claude 登录依赖 wrapper：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --use-aws-wrapper
```

如果你要固定主 reviewer 模型，并保留默认回退链：

```bash
bash scripts/install_codex_claude_mainline.sh \
  --reinstall \
  --review-model 'claude-opus-4-7[1m]' \
  --review-fallback-model 'claude-opus-4-6'
```

卸载优先使用安装时复制到本地状态目录的脚本：

```bash
bash ~/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh
```

这个本地脚本会按 manifest 精确回滚安装器接管过的路径，而不是粗暴删除整目录。

安装后最小验证：

```bash
codex mcp list
codex mcp get claude-review --json
claude -p "Reply with exactly READY" --output-format json --tools ""
```

运行时健康检查：

```bash
bash scripts/check_claude_review_runtime.sh
bash scripts/check_unattended_mainline.sh /path/to/project
```

这个脚本现在会同时检查：

- `claude -p` 直连
- 直接启动 `server.py`
- 已安装的 `claude-review` MCP
- 宿主机 `Codex -> mcp__claude_review__review`

`check_unattended_mainline.sh` 还会继续读取 `## Execution Profile`、`## CUDA Profile` 和 `## Robotics Profile`。如果项目是 `cpp_algorithm`，它会额外检查 `cmake`、编译器、`ctest`、`ninja/make`，并在 `cpu_cuda_mixed` 下继续检查 `nvcc`、`nvidia-smi`、`nsys/ncu/perf`；如果项目是 `robotics_slam`，它还会检查 `cmake`/`cmake_ros2`、`colcon`/`ros2`（如需要）、trajectory/rosbag backend 配置，以及 `results/trajectory_summary.json`、`results/perception_summary.json`、`monitoring/last_robotics_summary.json` 这类 artifact 合同。

如果当前 shell 有代理变量，但已安装的 MCP 配置里缺少这些变量，脚本会明确提示重新执行：

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

---

## 3. Overlay 覆盖范围

Claude reviewer overlay 的覆盖范围以：

- `tools/generate_codex_claude_review_overrides.py`

中的 `TARGET_SKILLS` 为唯一来源。

当前覆盖的 reviewer-aware 技能是：

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

维护规则：

- 主线 skill 负责表达 reviewer 意图
- overlay 负责把 reviewer 调用改写到 `claude-review`
- overlay 不应该长期手工分叉；改完上游主线 skill 后，应重新生成 overlay

重生命令：

```bash
python3 tools/generate_codex_claude_review_overrides.py
```

---

## 4. Workflow 嵌入方式

这条主线不是“Claude 审所有东西”，而是分层协作。

主线实际链路是：

```text
/idea-discovery
-> /research-refine-pipeline
-> implement
-> /run-experiment
-> innovation gate
-> /deep-innovation-loop?
-> /auto-review-loop
-> /result-to-claim
-> /paper-writing
```

三个容易被误解的能力必须单独说明：

`research-wiki`

- 是长期研究记忆层
- 推荐让 `/research-lit`、`/idea-creator`、`/result-to-claim` 持续回写
- 它不是 reviewer transport 的一部分

`deep-innovation-loop`

- 已经进入默认 `/research-pipeline`
- 它不是边缘功能，也不是 out-of-band 小插件
- 其中外部诊断、设计审查和实现审查这些 reviewer checkpoint 统一走 Claude overlay

`meta-optimize`

- 是里程碑后的维护环
- 它分析 `AUTO_REVIEW.md`、`innovation-logs/`、`refine-logs/`、`paper/`、`rebuttal/` 等工件
- 它不应该插在脆弱实验执行中间

所以边界必须保持清楚：

- Claude 负责 reviewer role
- Codex 负责主线执行、记忆层与维护层的调用和编排

---

## 5. Reviewer 传输细节

`claude-review` bridge 提供两类接口：

同步：

- `review`
- `review_reply`

异步：

- `review_start`
- `review_reply_start`
- `review_status`

遇到长论文、长项目审稿或大 prompt 时，优先走异步接口：

```text
Codex -> claude-review MCP -> 本地 Claude CLI -> Claude 后端
```

之所以要有异步接口，是因为本地 CLI 这一跳会让长同步调用更容易撞上宿主超时。

bridge 还支持可选的 `jsonSchema` / `json_schema`，并透传给 Claude CLI 的 `--json-schema`。某个 skill 需要结构化 reviewer 输出时，直接复用这条能力即可。

默认 reviewer 模型链是：

- 首选 `claude-opus-4-7[1m]`
- 回退 `claude-opus-4-6`

这个回退只在 MCP 调用**没有显式传 `model`**时生效；如果某个 skill 或手工调用显式传了 `model`，bridge 会按该值直连，不自动回退。

如果你所在环境需要代理，`claude-review` 能否通过 Codex 托管路径成功，取决于这些代理变量是否被注册进 MCP 配置；仅仅 direct CLI 可用还不够。

---

## 6. 维护者回归流程

修改主线 skill、overlay、安装器或 bridge 后，至少跑这五条：

```bash
python3 tools/check_codex_mainline_parity.py
python3 tools/generate_codex_claude_review_overrides.py
git diff --check
bash scripts/smoke_test_codex_claude_mainline.sh
bash scripts/check_claude_review_runtime.sh
```

推荐顺序：

1. 先跑 `tools/check_codex_mainline_parity.py`
2. 再重生 overlay
3. 再看 `git diff --check`
4. 先跑安装链 smoke test
5. 最后跑真实 runtime 健康检查

如果修改涉及 reviewer-aware skill，还要同时看：

- `skills/skills-codex-claude-review/`
- [`README.md`](../README.md)
- [`docs/CODEX_MAINLINE_PARITY_RULES_CN.md`](CODEX_MAINLINE_PARITY_RULES_CN.md)

不要只改 skill，不改主线文档。
