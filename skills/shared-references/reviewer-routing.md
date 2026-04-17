# Reviewer Routing

## Default (NEVER changes without explicit user request)

All review calls use **Codex CLI** (`codex exec --sandbox read-only -m gpt-5.4`) with reasoning effort xhigh.

This is the default for ALL skills. No parameter, no config, no effort level changes this.

## Three Review Channels

ARIS routes reviews through three channels based on the `-- reviewer:` parameter. See `codex-context-integrity.md` for the full three-tool decision tree and prompt construction rules.

### Channel 1: Default — `codex exec` (no parameter needed)

Standard structured review via Codex CLI. Used when no `-- reviewer:` parameter is specified, or when `-- reviewer: codex` is explicitly passed.

```bash
codex exec --sandbox read-only -m gpt-5.4 "Read the project files directly. [REVIEW TASK]"
```

- GPT-5.4 reads files directly from the repo
- Supports `--output-schema` for structured evaluations
- Supports `-i image.pdf` for visual review
- Supports `review --base main` for git diff review
- Supports `resume --last` for multi-turn follow-up

### Channel 2: Rescue — `-- reviewer: rescue`

Deep investigation via the `/codex:rescue` skill. Used when standard review is insufficient — the reviewer needs autonomy to explore, investigate, or brainstorm collaboratively.

```
/codex:rescue --effort xhigh "[REVIEW TASK]

Read these files directly:
- [list specific files]

[Additional context]"
```

- GPT-5.4 autonomously explores the codebase
- Best for: stuck points, deep investigation, collaborative problem-solving
- Deeper than standard `codex exec` — the rescue subagent can run multiple rounds

### Channel 3: Adversarial — `-- reviewer: adversarial`

Code-focused adversarial review via the `/codex:adversarial-review` skill. Used for rigorous code diff review at implementation checkpoints.

```
/codex:adversarial-review --scope working-tree
```

- GPT-5.4 reads git diff and source code directly
- Best for: post-fix validation, pre-deployment audit, code quality gates
- Every code change triggers this automatically (see `codex-context-integrity.md`, Mandatory Code Review Rule)

## GPT-5.4 Pro via Oracle

When `— reviewer: oracle-pro` is passed, route the review through Oracle MCP to use GPT-5.4 Pro — the strongest available reviewer. If Oracle MCP is not installed, falls back to `codex exec` with a warning.

### Channel 4: Oracle Pro — `— reviewer: oracle-pro`

**Browser mode (default):**
```
mcp__oracle__consult:
  prompt: |
    [role + task + output schema]
    Read all listed files directly.
  model: "gpt-5.4-pro"
  engine: "browser"
  files:
    - /absolute/path/to/file1
    - /absolute/path/to/file2
```

**API mode (optional, faster):**
```
mcp__oracle__consult:
  prompt: |
    [role + task + output schema]
    Read all listed files directly.
  model: "gpt-5.4-pro"
  engine: "api"
  files:
    - /absolute/path/to/file1
    - /absolute/path/to/file2
```

**Key parameters:**
- `engine: "browser"` — **default**，通过 Chrome 中的 ChatGPT Pro 自动化调用，无需 API Key
- `engine: "api"` — 通过 OpenAI API 调用，需要 `OPENAI_API_KEY`
- `files` — 项目文件路径列表，Oracle 会将其内容附加到 prompt 中
- `browserModelLabel` — （可选）强制指定 ChatGPT UI 中的模型标签（如 "GPT-5.4 Pro"）
- `browserAttachments: "always"` — （可选）通过 ChatGPT 文件上传功能传递文件（适合 PDF/图片）
- `slug` — （可选）会话标识，用于后续 `mcp__oracle__sessions` 查看历史

**Two modes (default: Browser mode):**

| Mode | Speed | Requirements | When to use |
|------|-------|-------------|-------------|
| **Browser mode (default)** | ~1-2 min/call | Chrome + ChatGPT Pro login | Default for all reviews. Free, no API key needed. |
| **API mode** | ~20-30s/call | `OPENAI_API_KEY` with GPT-5.4 Pro access | When speed matters (multi-round loops, batch reviews) |

- Best for: final stress test, deep mathematical reasoning, complex theory papers, strongest possible critique
- Browser mode is the **recommended default** — GPT-5.4 Pro through ChatGPT provides the deepest reasoning
- For multi-round loops (e.g., `/auto-review-loop` with `— reviewer: oracle-pro`), consider API mode for faster iteration
- **NOT installed = ZERO impact.** Graceful fallback to `codex exec` with warning.

**查看历史会话：**
```
mcp__oracle__sessions:
  hours: 24
  limit: 10
```

### Oracle Setup

```bash
# 1. Install Oracle CLI + MCP
npm install -g @steipete/oracle

# 2. Add Oracle MCP to Claude Code
claude mcp add oracle -s user -- oracle-mcp

# 3. Restart Claude Code session (full restart, not just /mcp reconnect)

# Browser mode (default, recommended):
# - Log in to ChatGPT Pro in Chrome (https://chatgpt.com)
# - Keep Chrome running with ChatGPT logged in
# - No API key needed
```

**Linux 注意事项：** 在 Linux 上，Chrome 运行时 cookie DB 会被锁定，导致 Oracle 无法自动读取 cookie。使用 Oracle CLI 时需要添加 `--browser-manual-login` 参数。MCP 调用格式不受影响（Oracle MCP 内部会自动处理）。

**典型耗时：** Browser mode 下每次调用约 2-4 分钟（GPT-5.4 Pro 思考时间较长）。确保调用超时设置足够长（建议 >= 10 分钟）。

### When to Use Oracle Pro

| Scenario | Recommendation |
|----------|---------------|
| Final stress test before submission | `— reviewer: oracle-pro` (browser mode) |
| Deep mathematical proof verification | `— reviewer: oracle-pro` (browser mode) |
| Theory-heavy paper review | `— reviewer: oracle-pro` (browser mode) |
| Multi-round auto-review with max quality | `— reviewer: oracle-pro` + API mode |
| Quick iterative fixes | Standard `codex exec` (faster) |
| Code review | `/codex:adversarial-review` (specialized for code) |

## Reviewer Roles (Orthogonal Axis to Channel)

The `-- reviewer-role` axis is **orthogonal** to `-- reviewer:` (channel) and `-- effort:` (intensity). It controls what the reviewer DOES, not which model/backend provides the review.

### The three roles

| Role | When | What the reviewer produces |
|------|------|---------------------------|
| `adversarial` (default) | Default for all review calls | Scores + blocking weaknesses + concrete fix suggestions. Current behavior unchanged. |
| `collaborative` | Escalation after stuck rounds (auto-triggered by `collaborative-protocol.md`) | Joint design: theoretical analysis + co-designed solution. No scoring. |
| `lateral` | Plateau with 2+ unchanged scores, OR manually for idea-refresh | Propose 2 lateral reframings + 1 cross-domain analogy. No critique, no scoring. Uses `divergent-techniques.md` Operator 4. |

### Role composition

`reviewer-role` composes freely with `reviewer` (channel) and `effort`:

```
/auto-review-loop "topic" — reviewer: codex                                         # default: adversarial
/auto-review-loop "topic" — reviewer: codex — reviewer-role: lateral                # lateral via codex exec
/auto-review-loop "topic" — reviewer: oracle-pro — reviewer-role: lateral           # lateral via GPT-5.4 Pro
/research-review "topic" — reviewer-role: collaborative                             # collaborative via default channel
```

### Lateral role prompt stanza

When `-- reviewer-role: lateral` is set, the review prompt's scoring / critique template is replaced with:

```
Read the work directly (files, diff, or project state as specified).

Do NOT score this work. Do NOT list weaknesses. Do NOT propose fixes.

Instead:
1. Read shared-references/divergent-techniques.md.
2. Pick ONE cross-domain source field (Operator 4 rotating pool). Prefer a field whose vocabulary does not appear in the current work.
3. Propose TWO lateral reframings of the problem this work addresses — each must change either the metric, the decomposition, or the method family (see reframing-triggers.md Trigger 2 for definitions).
4. Propose ONE cross-domain analogy from the selected source field: the principle that makes that field's solution work, translated into this problem's vocabulary (Layer 3 of principle-extraction.md).

Output format:
- Reframing 1: [tag] [statement] [why it is motivated]
- Reframing 2: [tag] [statement] [why it is motivated]
- Cross-domain analogy: [source field] [principle] [concrete proposal in our vocabulary]
```

### Auto-trigger rules

| Skill | When lateral mode fires automatically |
|-------|--------------------------------------|
| `/auto-review-loop` | 2 consecutive rounds with unchanged overall score AND no reframing has been proposed in those rounds |
| `/deep-innovation-loop` | Explicitly at LEAP_ROUNDS = {10, 20, 30} via Phase C Leap Round (different mechanism but same underlying operator) |
| Others | Manual only — user passes `-- reviewer-role: lateral` |

### What does NOT change

- `collaborative` role is the existing behavior defined in `collaborative-protocol.md` — this section just names it explicitly for orthogonality.
- The three reviewer channels (codex / rescue / adversarial) and Oracle Pro remain the backends; `reviewer-role` changes the prompt template, not the backend.
- Scoring dimensions (when `adversarial` mode is active) remain venue-specific as before.

## Routing Logic (add to any reviewer-invoking skill)

```
Parse $ARGUMENTS for `-- reviewer:` directive (selects CHANNEL — which backend).
Parse $ARGUMENTS for `-- reviewer-role:` directive (selects ROLE — what the reviewer does).

If `-- reviewer:` not specified OR `-- reviewer: codex`:
    -> Use codex exec --sandbox read-only -m gpt-5.4 with reasoning effort xhigh
    -> This is the DEFAULT. No change from current behavior.

If `-- reviewer: rescue`:
    -> Route through /codex:rescue --effort xhigh
    -> Passes the review prompt and file list to the rescue subagent
    -> Used for deep investigation, collaborative sessions, or when stuck

If `-- reviewer: adversarial`:
    -> Route through /codex:adversarial-review
    -> Reads git diff + source code for code-focused review
    -> Used for post-fix validation, pre-deployment audit

If `— reviewer: oracle-pro`:
    -> Check if mcp__oracle__consult tool is available
    -> If available: use Oracle MCP with model "gpt-5.4-pro", pass file paths
    -> If NOT available: print "Oracle MCP not installed. Falling back to Codex xhigh.", use codex exec

After channel resolution, resolve ROLE:

If `-- reviewer-role:` not specified OR `-- reviewer-role: adversarial`:
    -> Use the default scoring + weakness-list prompt for the invoking skill
    -> This is the DEFAULT. No change from current behavior.

If `-- reviewer-role: collaborative`:
    -> Replace the standard prompt with the collaborative template from collaborative-protocol.md
    -> Same channel, different prompt
    -> Typically auto-triggered on escalation, not manually

If `-- reviewer-role: lateral`:
    -> Replace the standard prompt with the lateral template above (no scoring; 2 reframings + 1 cross-domain analogy)
    -> Same channel, different prompt
    -> Auto-triggered by auto-review-loop on 2 consecutive unchanged scores; manually available in research-review
```

## Invariants

- **Reviewer independence** — GPT-5.4 always reads files directly; Claude never summarizes on GPT-5.4's behalf
- **Effort orthogonality** — `effort` and `difficulty` parameters do not change the reviewer backend or reasoning effort (always xhigh)
- **Role orthogonality** — `reviewer-role` changes the prompt template, NOT the backend or reasoning effort. All roles compose freely with all channels and all effort levels.
- **`beast` mode** — may RECOMMEND `-- reviewer: rescue` for deeper analysis but never requires it
- **Anti-framing** — before every review call, Claude must run the Anti-Framing Self-Check from `codex-context-integrity.md`
- **Review Feedback Verification** — after receiving review results, Claude must follow the Review Feedback Verification Protocol from `codex-context-integrity.md` (evaluate, dispute with evidence if needed, log all decisions)
- **Three-tool default** — all reviewer interactions go through the three Codex CLI channels by default; Oracle is the only optional fourth channel
- **Oracle optional** — `— reviewer: oracle-pro` only works when Oracle MCP is installed; zero impact otherwise; graceful fallback to codex exec

## Skills That Support `-- reviewer:` Parameter

| Skill | Default channel | When to use `rescue` | When to use `adversarial` | When to use `oracle-pro` |
|-------|----------------|---------------------|--------------------------|--------------------------|
| `/research-review` | codex exec | Deeper critique, second opinion | N/A (no code) | Deepest critique on theory papers |
| `/auto-review-loop` | codex exec | Stuck after 3+ rounds | After implementing fixes (automatic) | Final stress test (last round) |
| `/experiment-audit` | codex exec | Line-by-line eval code audit | After fixing eval code | Line-by-line audit on complex eval |
| `/proof-checker` | codex exec | Deep mathematical reasoning | N/A (no code) | Strongest mathematical reasoning |
| `/paper-claim-audit` | codex exec | Evidence chain investigation | N/A (no code) | N/A (zero-context by design) |
| `/rebuttal` | codex exec | Stress test before submission | N/A (no code) | Final stress test before submit |
| `/idea-creator` | codex exec | Idea evaluation depth | After pilot implementation | Deepest idea evaluation |
| `/research-lit` | codex exec | Literature analysis depth | N/A (no code) | Deep literature analysis |
| `/deep-innovation-loop` | codex exec | Plateau diagnosis (3+ rounds stuck) | After implementing variant (automatic) | N/A (too slow for loops) |
| `/experiment-bridge` | codex exec | Independent result interpretation | After implementing experiment code (automatic) | N/A (too slow for loops) |

## Channel Selection Guide

```
Standard review (structured, fast)    -> no parameter (codex exec)
Need deeper investigation?            -> -- reviewer: rescue
Need code diff review?                -> -- reviewer: adversarial
Stuck after multiple rounds?          -> -- reviewer: rescue
Post-fix validation?                  -> -- reviewer: adversarial (automatic)
Pre-submission final audit?           -> -- reviewer: rescue
Need the strongest reviewer?          -> — reviewer: oracle-pro (if installed)
```

## Role Selection Guide

```
Default scoring + weakness list       -> no parameter (adversarial)
Joint design with reviewer            -> -- reviewer-role: collaborative (auto on escalation)
Lateral reframing + cross-domain      -> -- reviewer-role: lateral (auto on plateau)
```

Role and channel compose. Example: `-- reviewer: oracle-pro — reviewer-role: lateral` = GPT-5.4 Pro in lateral mode.

## Reference

For the complete three-tool decision tree, prompt construction rules, anti-framing checklist, mandatory code review rule, and review feedback verification protocol, see `codex-context-integrity.md`.
