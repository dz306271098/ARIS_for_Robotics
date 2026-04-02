---
name: research-lit
description: Search and analyze research papers, find related work, summarize key ideas. Use when user says "find papers", "related work", "literature review", "what does this paper say", or needs to understand academic papers.
argument-hint: [paper-topic-or-url]
allowed-tools: Bash(*), Read, Glob, Grep, WebSearch, WebFetch, Write, Agent, mcp__zotero__*, mcp__obsidian-vault__*
---

# Research Literature Review

Research topic: $ARGUMENTS

## Constants

- **PAPER_LIBRARY** — Local directory containing user's paper collection (PDFs). Check these paths in order:
  1. `papers/` in the current project directory
  2. `literature/` in the current project directory
  3. Custom path specified by user in `CLAUDE.md` under `## Paper Library`
- **MAX_LOCAL_PAPERS = 20** — Maximum number of local PDFs to scan (read first 3 pages each). If more are found, prioritize by filename relevance to the topic.
- **API_MAX_PER_QUERY = 30** — Maximum results per API query (arXiv, Semantic Scholar). Higher values catch papers that rank lower but are still relevant. Applies per query variant.
- **ARXIV_DOWNLOAD = false** — When `true`, download top 3-5 most relevant arXiv PDFs to PAPER_LIBRARY after search. When `false` (default), only fetch metadata (title, abstract, authors) via arXiv API — no files are downloaded.
- **ARXIV_MAX_DOWNLOAD = 5** — Maximum number of PDFs to download when `ARXIV_DOWNLOAD = true`.
- **SNOWBALL = true** — When `true`, perform citation graph traversal (forward + backward) on top 3-5 most relevant papers found. Catches papers using different terminology but in the same citation lineage. Set `false` to skip for faster search.

> 💡 Overrides:
> - `/research-lit "topic" — paper library: ~/my_papers/` — custom local PDF path
> - `/research-lit "topic" — sources: zotero, local` — only search Zotero + local PDFs
> - `/research-lit "topic" — sources: zotero` — only search Zotero
> - `/research-lit "topic" — sources: web` — only search the web (skip all local)
> - `/research-lit "topic" — no-s2` — exclude Semantic Scholar from default search
> - `/research-lit "topic" — snowball: false` — skip citation graph expansion for faster search
> - `/research-lit "topic" — arxiv download: true` — download top relevant arXiv PDFs
> - `/research-lit "topic" — arxiv download: true, max download: 10` — download up to 10 PDFs

## Data Sources

This skill checks multiple sources **in priority order**. All are optional — if a source is not configured or not requested, skip it silently.

### Source Selection

Parse `$ARGUMENTS` for a `— sources:` directive:
- **If `— sources:` is specified**: Only search the listed sources (comma-separated). Valid values: `zotero`, `obsidian`, `local`, `web`, `semantic-scholar`, `all`.
- **If not specified**: Default to `all` — search every available source in priority order, **including Semantic Scholar**.
- **To exclude Semantic Scholar**: Use `— no-s2` or `— sources: zotero, local, web`.

Examples:
```
/research-lit "diffusion models"                                    → all (includes S2)
/research-lit "diffusion models" — sources: all                     → all (includes S2)
/research-lit "diffusion models" — no-s2                            → all except Semantic Scholar
/research-lit "diffusion models" — sources: zotero                  → Zotero only
/research-lit "diffusion models" — sources: zotero, web             → Zotero + web
/research-lit "diffusion models" — sources: local                   → local PDFs only
/research-lit "topic" — sources: obsidian, local, web               → skip Zotero + S2
/research-lit "topic" — sources: web, semantic-scholar              → web + S2 API only
```

### Source Table

| Priority | Source | ID | How to detect | What it provides |
|----------|--------|----|---------------|-----------------|
| 1 | **Zotero** (via MCP) | `zotero` | Try calling any `mcp__zotero__*` tool — if unavailable, skip | Collections, tags, annotations, PDF highlights, BibTeX, semantic search |
| 2 | **Obsidian** (via MCP) | `obsidian` | Try calling any `mcp__obsidian-vault__*` tool — if unavailable, skip | Research notes, paper summaries, tagged references, wikilinks |
| 3 | **Local PDFs** | `local` | `Glob: papers/**/*.pdf, literature/**/*.pdf` | Raw PDF content (first 3 pages) |
| 4 | **Web search** | `web` | Always available (WebSearch) | arXiv, Semantic Scholar, Google Scholar |
| 5 | **Semantic Scholar API** | `semantic-scholar` | `tools/semantic_scholar_fetch.py` exists | Published venue papers (IEEE, ACM, Springer) with structured metadata: citation counts, venue info, TLDR. **Runs by default** as part of `all`. Skip with `— no-s2` |

> **Graceful degradation**: If no MCP servers are configured, the skill works exactly as before (local PDFs + web search). Zotero and Obsidian are pure additions.

## Workflow

### Step 0a: Search Zotero Library (if available)

**Skip this step entirely if Zotero MCP is not configured.**

Try calling a Zotero MCP tool (e.g., search). If it succeeds:

1. **Search by topic**: Use the Zotero search tool to find papers matching the research topic
2. **Read collections**: Check if the user has a relevant collection/folder for this topic
3. **Extract annotations**: For highly relevant papers, pull PDF highlights and notes — these represent what the user found important
4. **Export BibTeX**: Get citation data for relevant papers (useful for `/paper-write` later)
5. **Compile results**: For each relevant Zotero entry, extract:
   - Title, authors, year, venue
   - User's annotations/highlights (if any)
   - Tags the user assigned
   - Which collection it belongs to

> 📚 Zotero annotations are gold — they show what the user personally highlighted as important, which is far more valuable than generic summaries.

### Step 0b: Search Obsidian Vault (if available)

**Skip this step entirely if Obsidian MCP is not configured.**

Try calling an Obsidian MCP tool (e.g., search). If it succeeds:

1. **Search vault**: Search for notes related to the research topic
2. **Check tags**: Look for notes tagged with relevant topics (e.g., `#diffusion-models`, `#paper-review`)
3. **Read research notes**: For relevant notes, extract the user's own summaries and insights
4. **Follow links**: If notes link to other relevant notes (wikilinks), follow them for additional context
5. **Compile results**: For each relevant note:
   - Note title and path
   - User's summary/insights
   - Links to other notes (research graph)
   - Any frontmatter metadata (paper URL, status, rating)

> 📝 Obsidian notes represent the user's **processed understanding** — more valuable than raw paper content for understanding their perspective.

### Step 0c: Scan Local Paper Library

Before searching online, check if the user already has relevant papers locally:

1. **Locate library**: Check PAPER_LIBRARY paths for PDF files
   ```
   Glob: papers/**/*.pdf, literature/**/*.pdf
   ```

2. **De-duplicate against Zotero**: If Step 0a found papers, skip any local PDFs already covered by Zotero results (match by filename or title).

3. **Filter by relevance**: Match filenames and first-page content against the research topic. Skip clearly unrelated papers.

4. **Summarize relevant papers**: For each relevant local PDF (up to MAX_LOCAL_PAPERS):
   - Read first 3 pages (title, abstract, intro)
   - Extract: title, authors, year, core contribution, relevance to topic
   - Flag papers that are directly related vs tangentially related

5. **Build local knowledge base**: Compile summaries into a "papers you already have" section. This becomes the starting point — external search fills the gaps.

> 📚 If no local papers are found, skip to Step 1. If the user has a comprehensive local collection, the external search can be more targeted (focus on what's missing).

### Step 0.5: Query Expansion (generate search variants)

Before any external API call, generate **3-5 query variants** to maximize coverage. Different papers use different terminology for the same concept — a single query misses many relevant papers.

1. **Original phrase**: The user's exact topic (e.g., "inertial odometry")
2. **Synonym rephrasing**: Alternative terminology (e.g., "IMU-based positioning", "dead reckoning")
3. **Broader term**: Wider scope to catch related work (e.g., "learning-based navigation")
4. **Narrower/method-specific**: Core technique name (e.g., "transformer IMU trajectory estimation")
5. **Baseline/dataset name**: If domain-specific section below applies, include key baselines (e.g., "AIR-IO", "TLIO")

Store these as `QUERY_VARIANTS` — Step 1 will loop through each variant for every API source.

> 💡 This pattern is proven — `/novelty-check` uses 3-5 query formulations per claim for the same reason.

### Step 1: Search (external)
- Search arXiv API, Semantic Scholar API, and WebSearch using **each query variant**
- Focus on papers from last 2 years unless studying foundational work
- **De-duplicate**: Skip papers already found in Zotero, Obsidian, or local library. De-duplicate across query variants by arXiv ID / S2 paperId

**arXiv API search** (always runs, no download by default):

Locate the fetch script and search arXiv directly:
```bash
# Try to find arxiv_fetch.py
SCRIPT=$(find tools/ -name "arxiv_fetch.py" 2>/dev/null | head -1)
# If not found, check ARIS install
[ -z "$SCRIPT" ] && SCRIPT=$(find ~/.claude/skills/arxiv/ -name "arxiv_fetch.py" 2>/dev/null | head -1)
```

**Multi-query search** — run arXiv API for **each query variant** from Step 0.5:
```bash
# For each QUERY_VARIANT:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY

# If domain is known, add category filter to at least one variant:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --category cs.RO

# For one variant, use date-sorted to catch newest papers:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --sort-by submittedDate
```

De-duplicate results across variants by arXiv ID. If `arxiv_fetch.py` is not found, fall back to WebSearch.

The arXiv API returns structured metadata (title, abstract, full author list, categories, dates) — richer than WebSearch snippets. Merge these results with WebSearch findings and de-duplicate.

**Semantic Scholar API search** (runs by default as part of `all`):

```bash
S2_SCRIPT=$(find tools/ -name "semantic_scholar_fetch.py" 2>/dev/null | head -1)
[ -z "$S2_SCRIPT" ] && S2_SCRIPT=$(find ~/.claude/skills/semantic-scholar/ -name "semantic_scholar_fetch.py" 2>/dev/null | head -1)
```

**Multi-query search** — run S2 API for **each query variant**:
```bash
# For each QUERY_VARIANT:
python3 "$S2_SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY \
  --fields-of-study "Computer Science,Engineering" \
  --publication-types "JournalArticle,Conference"

# For one variant, also search recent papers sorted by date:
python3 "$S2_SCRIPT" search-bulk "VARIANT" --max $API_MAX_PER_QUERY \
  --sort publicationDate:desc --year "2024-"
```

De-duplicate results across variants by S2 paperId. If `semantic_scholar_fetch.py` is not found, skip silently.

**Why use Semantic Scholar?** Many IEEE/ACM journal papers are NOT on arXiv. S2 fills the gap for published venue-only papers with citation counts and venue metadata.

**De-duplication between arXiv and S2**: Match by arXiv ID (S2 returns `externalIds.ArXiv`):
- If a paper appears in both: check S2's `venue`/`publicationVenue` — if it has been published in a journal/conference (e.g. IEEE TWC, JSAC), use S2's metadata (venue, citationCount, DOI) as the authoritative version, since the published version supersedes the preprint. Keep the arXiv PDF link for download.
- If the S2 match has no venue (still just a preprint indexed by S2): keep the arXiv version as-is.
- S2 results without `externalIds.ArXiv` are **venue-only papers** not on arXiv — these are the unique value of this source.

### Domain-Specific Search: Robotics & Inertial Navigation

When the research topic involves robotics, inertial navigation, odometry, IMU, or sensor fusion:

**Priority Venues** (via Semantic Scholar):
- IEEE RA-L (Robotics and Automation Letters)
- ICRA (International Conference on Robotics and Automation)
- IROS (International Conference on Intelligent Robots and Systems)
- IEEE TRO (Transactions on Robotics)
- CoRL (Conference on Robot Learning)
- RSS (Robotics: Science and Systems)

**Key Search Terms** (combine and vary):
- Inertial odometry, neural inertial navigation, IMU odometry
- Pedestrian dead reckoning, inertial measurement unit
- Deep inertial odometry, learning-based inertial navigation
- IMU preintegration, inertial sensor fusion
- Attitude estimation, orientation tracking
- Specific baselines: AIR-IO, TLIO, RoNIN, RINS-W, IONet, MotionTransformer

**arXiv Categories**:
- cs.RO (Robotics)
- cs.CV (when combined with visual-inertial)
- eess.SP (Signal Processing, for IMU denoising)

**Dataset-Specific Search**:
- RIDI dataset, OxIOD, RoNIN dataset, KITTI IMU
- EuRoC MAV dataset (IMU component)
- TUM-VI dataset

When using Semantic Scholar, filter by venues:
`— sources: semantic-scholar, venues: "IEEE Robotics and Automation Letters,ICRA,IROS"`

**Optional PDF download** (only when `ARXIV_DOWNLOAD = true`):

After all sources are searched and papers are ranked by relevance:
```bash
# Download top N most relevant arXiv papers
python3 "$SCRIPT" download ARXIV_ID --dir papers/
```
- Only download papers ranked in the top ARXIV_MAX_DOWNLOAD by relevance
- Skip papers already in the local library
- 1-second delay between downloads (rate limiting)
- Verify each PDF > 10 KB

### Step 1.5: Citation Graph Expansion (snowball search)

**Skip this step if `SNOWBALL = false`.**

From all papers found in Step 1, select the **top 3-5 most relevant** papers (by title/abstract match to the research topic). For each seed paper:

```bash
# Forward citations — who cited this paper? (finds newer related work)
python3 "$S2_SCRIPT" citations "PAPER_ID_OR_ARXIV_ID" --max 20

# Backward references — what did this paper cite? (finds foundational work)
python3 "$S2_SCRIPT" references "PAPER_ID_OR_ARXIV_ID" --max 20
```

For paper IDs, use `ARXIV:XXXX.XXXXX` format if arXiv ID is available, otherwise use S2 paperId or DOI.

**De-duplicate** all newly found papers against the existing result pool (match by arXiv ID, S2 paperId, or title).

**Why snowball?** Papers using different terminology but in the same intellectual lineage are connected via citations. A paper that matches none of your keyword queries will still appear as a reference of, or citation to, a known-relevant paper. This is the single most effective technique for catching "unknown unknowns."

**Optional — Author expansion**: If the results so far reveal that 2-3 key researchers dominate the field (appear as authors on 3+ papers), fetch their recent work:
```bash
python3 "$S2_SCRIPT" author-papers "Author Name" --max 20
```
This catches papers where the title uses novel terminology that no keyword query would find.

### Step 2: Analyze Each Paper
For each relevant paper (from all sources), extract:
- **Problem**: What gap does it address?
- **Method**: Core technical contribution (1-2 sentences)
- **Results**: Key numbers/claims
- **Relevance**: How does it relate to our work?
- **Source**: Where we found it (Zotero/Obsidian/local/web) — helps user know what they already have vs what's new

### Step 2.5: Gap-Driven Expansion (one round)

After analyzing the initial batch, check if the collected papers reveal **terminology, methods, or sub-topics** that were NOT in the original QUERY_VARIANTS. For example, if multiple papers mention "equivariant neural networks for IMU" but that phrase was not in any original query, it represents a gap.

**If significant gaps are found** (distinct term clusters covering ≥3 papers not in your original variants):
1. Generate up to 3 new targeted queries from the discovered terminology
2. Run one additional round of arXiv + S2 search with these queries (`--max $API_MAX_PER_QUERY` each)
3. De-duplicate against all existing results
4. Add unique papers to the analysis pool

**Bounds** (to prevent runaway):
- Maximum 1 expansion round
- Maximum 3 new queries
- Only triggers if genuinely distinct terminology is found — do NOT repeat variants of existing queries

### Step 3: Synthesize
- Group papers by approach/theme
- Identify consensus vs disagreements in the field
- Find gaps that our work could fill
- If Obsidian notes exist, incorporate the user's own insights into the synthesis

### Step 4: Output
Present as a structured literature table:

```
| Paper | Venue | Method | Key Result | Relevance to Us | Source |
|-------|-------|--------|------------|-----------------|--------|
```

Plus a narrative summary of the landscape (3-5 paragraphs).

If Zotero BibTeX was exported, include a `references.bib` snippet for direct use in paper writing.

### Step 5: Save (if requested)
- Save paper PDFs to `literature/` or `papers/`
- Update related work notes in project memory
- If Obsidian is available, optionally create a literature review note in the vault

## Web Resilience Rules

Web operations (WebSearch, WebFetch) can hang indefinitely and block the entire pipeline. Apply these rules strictly:

1. **Prefer Bash `curl` with timeout over raw WebFetch for critical paths**:
   ```bash
   # Use curl with --max-time instead of WebFetch when fetching a known URL
   curl -sL --max-time 30 "https://arxiv.org/abs/XXXX.XXXXX" | head -200
   ```

2. **Batch web searches**: Do NOT launch many sequential WebSearch calls. Batch 3-5 queries, and if any individual search hangs for more than ~60 seconds, abandon it and move on to the next.

3. **Hard rule — never block on web**: If WebSearch or WebFetch appears stuck (no response within ~60 seconds), immediately:
   - Abandon the current fetch
   - Log: `"[SKIP] WebSearch/WebFetch timed out for query: [query]"`
   - Continue with whatever results have already been collected
   - Do NOT retry the same URL/query — try an alternative query formulation or skip

4. **Graceful degradation priority**: If all web searches fail, the skill MUST still produce output using:
   - Local papers in `papers/` and `literature/` directories
   - Zotero/Obsidian results (if available)
   - arXiv API via `python tools/arxiv_fetch.py` (more reliable than WebSearch)
   - Semantic Scholar API via `python tools/semantic_scholar_fetch.py` (more reliable than WebSearch)
   - State clearly in the output: "Web search was unavailable; results based on local/API sources only"

5. **Prefer API tools over web scraping**: For arXiv and Semantic Scholar, ALWAYS prefer the dedicated Python tools (`tools/arxiv_fetch.py`, `tools/semantic_scholar_fetch.py`) over WebSearch/WebFetch. These are faster, more reliable, and have built-in error handling:
   ```bash
   # arXiv — reliable, structured results
   python tools/arxiv_fetch.py search "inertial odometry"
   
   # Semantic Scholar — reliable, published venue papers
   python tools/semantic_scholar_fetch.py search "inertial odometry" --year 2024-2026
   ```

6. **Sub-agent timeout**: When launching an Agent for web research, keep the scope narrow (one specific query, not "search everything"). Broad agents are more likely to hang.

## Key Rules
- Always include paper citations (authors, year, venue)
- Distinguish between peer-reviewed and preprints
- Be honest about limitations of each paper
- Note if a paper directly competes with or supports our approach
- **Never fail because a MCP server is not configured** — always fall back gracefully to the next data source
- Zotero/Obsidian tools may have different names depending on how the user configured the MCP server (e.g., `mcp__zotero__search` or `mcp__zotero-mcp__search_items`). Try the most common patterns and adapt.
