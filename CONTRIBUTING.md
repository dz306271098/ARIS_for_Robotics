# Contributing to Auto-claude-code-research-in-sleep (ARIS)

[English](CONTRIBUTING.md) | [中文版](CONTRIBUTING_CN.md)

Thank you for your interest in contributing to ARIS! This document provides guidelines and instructions for contributing.

## Ways to Contribute

- Report bugs or issues
- Suggest new features or skills
- Improve documentation
- Add translations
- Share your use cases and feedback

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Auto-claude-code-research-in-sleep.git
   cd Auto-claude-code-research-in-sleep
   ```
3. Create a branch for your changes:
   ```bash
   git checkout -b your-feature-name
   ```

## Development

### Skill Development

This repository is now centered on the Codex-first mainline. Most skill changes should target:

- `skills/skills-codex/`
- `skills/skills-codex-claude-review/`
- `skills/skills-codex-gemini-review/` only when you are maintaining the retained Gemini reviewer branch

Each skill has:

- **Frontmatter**: YAML metadata (name, description, allowed-tools)
- **Content**: The skill instructions

Example skill structure:
```markdown
---
name: my-skill
description: What this skill does
argument-hint: [optional-argument-hint]
allowed-tools: Read, Write, Bash(*)
---

# Skill Title

Instructions here...
```

### Testing Your Changes

Before submitting:
1. Install the modified skill into `~/.codex/skills/`
2. If you changed default reviewer behavior, regenerate the overlay: `python3 tools/generate_codex_claude_review_overrides.py`
3. Run the mainline check: `python3 tools/check_codex_mainline_parity.py`
4. Run the install-chain smoke test: `bash scripts/smoke_test_codex_claude_mainline.sh`
5. Verify the skill works as expected

## Pull Request Process

1. Make sure your changes are well-documented
2. Update `README_CN.md` and the relevant mainline guide if you add new skills or features
3. Keep PRs focused on a single change
4. Write clear commit messages

### PR Checklist

- [ ] Code follows the project style
- [ ] Documentation is updated (if applicable)
- [ ] Changes are tested locally

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## Questions?

Feel free to open an issue for any questions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
