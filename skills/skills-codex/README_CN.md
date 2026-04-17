# `skills-codex` 说明

这是 ARIS 当前的 **Codex 主线基础技能包**。

公开主线只围绕这一条路径说明：

- `Codex` 负责执行
- `Claude Code CLI` 通过 overlay 承担 reviewer 角色

也就是说，`skills/skills-codex/` 是主线底座，`skills/skills-codex-claude-review/` 是其上的 reviewer 覆盖层。

仓库还保留两个**非默认** reviewer 支路：

- `skills/skills-codex-gemini-review/`
- `skills/skills-codex/auto-review-loop-minimax/`

它们都不是当前公开主线的一部分，只作为可选 reviewer 分支保留。

## 这个包现在的定位

`skills/skills-codex/` 负责提供：

- 主工作流编排
- 项目状态与工件约定
- 实验、论文、rebuttal 等执行阶段
- reviewer-aware 技能的基础表达

当前主线里，以下能力已经是底座的一部分，不再是边缘附加件：

- `research-wiki`
- `deep-innovation-loop`
- `meta-optimize`
- `result-to-claim`
- `training-check`
- `ablation-planner`
- `rebuttal`

其中 `shared-references/` 是支持目录，不算可直接调用的 skill。

所有会改代码的执行型 workflow 还共享两条硬协议：

- `Mandatory Test Gate`：写完代码后必须先过模块测试和 workflow smoke test
- `Reviewer Resolution Protocol`：reviewer 反馈有争议时必须回 thread 讨论到收敛
- `Unattended Runtime Protocol`：`CODEX.md -> ## Autonomy Profile`、`AUTONOMY_STATE.json`、watchdog 和 W&B 共同约束无人值守长跑

## 主线嵌入方式

当前默认主链路是：

```text
/idea-discovery
-> /research-refine-pipeline
-> /experiment-bridge
-> /monitor-experiment + /training-check
-> /result-to-claim
-> /deep-innovation-loop?
-> /auto-review-loop
-> /result-to-claim
-> /paper-writing
```

三个需要明确的层：

- `research-wiki` = 长期记忆层
- `deep-innovation-loop` = 主线方法进化阶段
- `meta-optimize` = 里程碑后的维护环

## 安装

```bash
mkdir -p ~/.codex/skills
cp -a skills/skills-codex/* ~/.codex/skills/
```

如果你要走当前公开主线，接下来再安装：

```bash
cp -a skills/skills-codex-claude-review/* ~/.codex/skills/
```

## 项目配置命名

当前主线路径下，项目级配置和状态文件统一使用：

- `CODEX.md`

本包内主线 skill、工具和说明都围绕 `CODEX.md` 设计，不再以其他项目级配置文件名作为公开入口。

## 边界说明

这个包只负责技能文件与支持引用，不负责你的完整运行环境。你仍然需要自行准备：

- Python / LaTeX / GPU / SSH 环境
- Claude CLI 登录态
- `claude-review` MCP 注册
- 项目自己的 `CODEX.md`、数据集和代码仓库
