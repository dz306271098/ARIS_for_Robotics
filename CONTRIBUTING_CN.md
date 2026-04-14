# 为 Auto-claude-code-research-in-sleep (ARIS) 做贡献

[English](CONTRIBUTING.md) | 中文版

感谢你对 ARIS 项目的关注！本文档提供了参与贡献的指南和说明。

## 贡献方式

- 报告 Bug 或问题
- 建议新功能或 Skill
- 改进文档
- 添加翻译
- 分享你的使用案例和反馈

## 开始之前

1. Fork 本仓库
2. 克隆你的 Fork：
   ```bash
   git clone https://github.com/你的用户名/Auto-claude-code-research-in-sleep.git
   cd Auto-claude-code-research-in-sleep
   ```
3. 为你的更改创建分支：
   ```bash
   git checkout -b 你的功能名称
   ```

## 开发

### Skill 开发

当前仓库以 Codex 主线为中心。大多数技能修改应落在：

- `skills/skills-codex/`
- `skills/skills-codex-claude-review/`
- `skills/skills-codex-gemini-review/`（仅当你在维护保留的 Gemini reviewer 支路）

每个 Skill 包含：

- **Frontmatter**：YAML 元数据（name、description、allowed-tools）
- **内容**：Skill 的指令说明

Skill 结构示例：
```markdown
---
name: my-skill
description: 这个 Skill 的功能
argument-hint: [可选参数提示]
allowed-tools: Read, Write, Bash(*)
---

# Skill 标题

指令内容...
```

### 测试你的更改

提交前请：
1. 将你修改的技能安装到 `~/.codex/skills/`
2. 如果改动默认主线 reviewer 逻辑，重生 overlay：`python3 tools/generate_codex_claude_review_overrides.py`
3. 运行主线检查：`python3 tools/check_codex_mainline_parity.py`
4. 运行安装链冒烟测试：`bash scripts/smoke_test_codex_claude_mainline.sh`
5. 验证技能按预期工作

## Pull Request 流程

1. 确保你的更改有完善的文档说明
2. 如果添加了新的 Skill 或功能，请更新 `README.md` 和相关主线说明
3. 保持 PR 聚焦于单一更改
4. 编写清晰的提交信息

### PR 检查清单

- [ ] 代码符合项目风格
- [ ] 文档已更新（如适用）
- [ ] 更改已在本地测试

## 行为准则

- 保持尊重和包容
- 专注于建设性反馈
- 帮助他人学习和成长

## 有问题？

欢迎提交 Issue 提问。

## 许可证

通过提交贡献，你同意将你的贡献以 MIT 许可证授权。
