# Codex 主线语义回填迁移说明

> 这份文档是“旧主线语义回填”的压缩基线。
>
> 它的用途不是替代 `README_CN.md`，而是给维护者一份**审查主线是否又回退**的固定对照表。
>
> 如果主线文档、skill、overlay、安装器之间出现冲突，优先以仓库当前实现和自动化校验为准，尤其是：
>
> - `skills/skills-codex/`
> - `skills/skills-codex-claude-review/`
> - `tools/check_codex_mainline_parity.py`
> - `scripts/smoke_test_codex_claude_mainline.sh`

---

## 1. 最终基线

### 1.1 主线角色边界

当前主线的固定分工是：

- **Codex** = 执行器
- **Claude Code CLI** = 审稿器
- **`claude-review` MCP bridge** = 审稿请求传输层

这条边界不能回退成“Codex 自己执行又自己做 reviewer”，也不能再把 Claude 写成主线编排器。

### 1.2 主配置文件规则

当前 Codex 主线路径只认：

- `CODEX.md`

主线 skill、工具和文档都应该围绕 `CODEX.md` 设计，不再保留以下旧主线兼容语义：

- `CLAUDE.md`
- `AGENTS.md`

### 1.3 技能包分层规则

当前主线路径固定拆成两层：

- `skills/skills-codex/` = Codex 主线基础包
- `skills/skills-codex-claude-review/` = Claude reviewer overlay

安装顺序固定为：

1. 先装 base pack
2. 再叠加 overlay
3. 最后注册 `claude-review` MCP

不能回退成“单包混写所有 reviewer 路径”，也不能把 overlay 重新写成手工长期分叉的主来源。

### 1.4 工作流嵌入规则

这三个能力现在都已经是主线的一部分，不是边缘附件：

- `research-wiki` = 长期研究记忆层
- `deep-innovation-loop` = 主线方法进化阶段
- `meta-optimize` = 里程碑后的维护层

具体约束：

- `deep-innovation-loop` 已经进入默认 `/research-pipeline`
- `research-wiki` 的推荐用法是让 `/research-lit`、`/idea-creator`、`/result-to-claim` 持续回写
- `meta-optimize` 不插入脆弱实验执行中间，而是在工件累积后作为维护环运行

如果 README、skill 说明或 guide 又把这三者写回“可选小插件”或“边缘实验能力”，那就是回退信号。

### 1.5 Reviewer-aware 语义规则

主线 skill 的 reviewer 语义必须保持为**可覆盖、可迁移、可自动检查**的表达方式。

当前约束是：

- 主线 skill 不再保留旧 `/codex:*` reviewer 命令
- 主线 frontmatter 不再保留：
  - `Skill(codex:rescue)`
  - `Skill(codex:adversarial-review)`
  - `Bash(codex*)`
- reviewer-aware 主线 skill 统一用 `spawn_agent` / `send_input` 表达 reviewer 语义
- Claude overlay 再把这些 reviewer 语义改写到 `claude-review` MCP

也就是说，**主线表达 reviewer 意图，overlay 决定 reviewer 传输实现**。

### 1.6 Overlay 生成规则

Claude reviewer overlay 的维护基线是：

- 用 `tools/generate_codex_claude_review_overrides.py` 生成和刷新
- overlay target 列表必须覆盖全部 reviewer-aware skills
- overlay frontmatter 必须是合法的 `SKILL.md`
- overlay `description` 必须和源 skill 的规范化描述保持一致

不能回退成：

- target 列表缺 skill
- overlay 说明和源 skill 语义漂移
- 安装后出现 invalid YAML 的 `SKILL.md`

### 1.7 安装与卸载规则

安装器必须继续保持 manifest 驱动的精确回滚，而不是粗暴覆盖或整目录删除。

当前约束：

- base pack 和 overlay 可以连续覆盖同一路径
- 卸载后仍然必须恢复安装前备份
- 本地卸载脚本必须从 manifest 回滚

如果安装器再次出现“overlay 覆盖后卸载恢复错层级内容”的问题，也属于主线回退。

---

## 2. 自动化守门

### 2.1 主要校验入口

维护主线时，至少要跑这四条：

```bash
python3 tools/check_codex_mainline_parity.py
python3 tools/generate_codex_claude_review_overrides.py
git diff --check
bash scripts/smoke_test_codex_claude_mainline.sh
```

### 2.2 这些命令分别守什么

- `tools/check_codex_mainline_parity.py`
  - 主线 frontmatter 是否完整
  - 主线 docs/tools 是否重新出现 `CLAUDE.md` / `AGENTS.md`
  - 主线 skill 是否重新出现旧 `/codex:*` reviewer 语义或旧 codex-specific tool 壳
  - overlay `description` 是否和主线规范化描述一致
  - overlay target 是否覆盖全部 reviewer-aware skills
- `tools/generate_codex_claude_review_overrides.py`
  - 重新生成 Claude overlay，验证生成链没有坏
- `git diff --check`
  - 防止文档、skill、生成结果里引入格式问题
- `scripts/smoke_test_codex_claude_mainline.sh`
  - 验证安装、重装、卸载和回滚链路

### 2.3 推荐的审查顺序

修改主线 skill、overlay、安装器、主线文档后，推荐按这个顺序审：

1. 先跑 `tools/check_codex_mainline_parity.py`
2. 再重生 overlay
3. 再看 `git diff --check`
4. 最后跑安装链 smoke test

如果修改涉及 reviewer-aware skill，必须同时看：

- 生成后的 `skills/skills-codex-claude-review/`
- `CODEX_CLAUDE_REVIEW_GUIDE*.md`
- `README_CN.md`

不要只改 skill，不改主线说明。

---

## 3. 常见回退信号

下面这些一旦出现，基本都说明主线在向旧语义回退：

- README、guide、tool 或 skill 又重新出现 `CLAUDE.md` / `AGENTS.md`
- 主线 skill 又出现 `/codex:rescue`、`/codex:adversarial-review`
- 主线 frontmatter 又出现 `Skill(codex:rescue)`、`Skill(codex:adversarial-review)`、`Bash(codex*)`
- `deep-innovation-loop` 又被写回“非主线能力”或“边缘实验能力”
- `research-wiki` 又被写回“额外笔记本”而不是主线记忆层
- `meta-optimize` 又被写成实验主线中的必经步骤
- overlay target 列表少了 reviewer-aware skill
- 安装后 Codex CLI 提示 `Skipped loading ... invalid SKILL.md files`
- 文档里把 reviewer 重新表述成“Codex 自审”或让 Claude 重新承担主线编排

遇到这些信号时，不要局部打补丁，而是回到本页“最终基线”逐条对照。

---

## 4. 最小人工复核清单

在自动化校验通过后，再人工确认这几条：

- `README_CN.md` 仍明确写着当前主线是 Codex 执行 + Claude 审稿
- `README_CN.md` 仍明确写着 `deep-innovation-loop` 在主线路径里
- `README_CN.md` 仍明确写着 `research-wiki` 是长期记忆层、`meta-optimize` 是维护环
- `docs/CODEX_CLAUDE_REVIEW_GUIDE_CN.md` 的覆盖范围仍和 overlay 实现一致
- `skills/skills-codex/README_CN.md` 没有把补齐能力重新降级为边缘附加件

如果这些人工叙述和自动化检查结论不一致，以实现和脚本为准，然后把文档补回一致。
