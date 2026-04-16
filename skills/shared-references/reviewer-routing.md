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

```
mcp__oracle__consult:
  prompt: |
    [role + task + output schema]
    Read all listed files directly.
  model: "gpt-5.4-pro"
  files:
    - /absolute/path/to/file1
    - /absolute/path/to/file2
```

**Two modes (default: Browser mode):**

| Mode | Speed | Requirements | When to use |
|------|-------|-------------|-------------|
| **Browser mode (default)** | ~1-2 min/call | Chrome + ChatGPT Pro login | Default for all reviews. Free, no API key needed. |
| **API mode** | ~20-30s/call | `OPENAI_API_KEY` with GPT-5.4 Pro access | When speed matters (multi-round loops, batch reviews) |

- Best for: final stress test, deep mathematical reasoning, complex theory papers, strongest possible critique
- Browser mode is the **recommended default** — GPT-5.4 Pro through ChatGPT provides the deepest reasoning
- For multi-round loops (e.g., `/auto-review-loop` with `— reviewer: oracle-pro`), consider API mode for faster iteration
- **NOT installed = ZERO impact.** Graceful fallback to `codex exec` with warning.

### Oracle Setup

```bash
# 1. Install Oracle CLI + MCP
npm install -g @steipete/oracle

# 2. Add Oracle MCP to Claude Code
claude mcp add oracle -s user -- oracle-mcp

# 3. Restart Claude Code session to load the new MCP server

# Browser mode (default, recommended):
# Log in to ChatGPT Pro in Chrome — Oracle will use the browser session automatically.
# No API key needed. Chrome must be running with ChatGPT logged in.

# API mode (optional, faster):
# export OPENAI_API_KEY="your-key"  # Must have GPT-5.4 Pro API access
```

### When to Use Oracle Pro

| Scenario | Recommendation |
|----------|---------------|
| Final stress test before submission | `— reviewer: oracle-pro` (browser mode) |
| Deep mathematical proof verification | `— reviewer: oracle-pro` (browser mode) |
| Theory-heavy paper review | `— reviewer: oracle-pro` (browser mode) |
| Multi-round auto-review with max quality | `— reviewer: oracle-pro` + API mode |
| Quick iterative fixes | Standard `codex exec` (faster) |
| Code review | `/codex:adversarial-review` (specialized for code) |

## Routing Logic (add to any reviewer-invoking skill)

```
Parse $ARGUMENTS for `-- reviewer:` directive.

If not specified OR `-- reviewer: codex`:
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
```

## Invariants

- **Reviewer independence** — GPT-5.4 always reads files directly; Claude never summarizes on GPT-5.4's behalf
- **Effort orthogonality** — `effort` and `difficulty` parameters do not change the reviewer backend or reasoning effort (always xhigh)
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

## Reference

For the complete three-tool decision tree, prompt construction rules, anti-framing checklist, mandatory code review rule, and review feedback verification protocol, see `codex-context-integrity.md`.
