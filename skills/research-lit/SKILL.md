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
- **API_MAX_PER_QUERY = 100** — Maximum results per API query (arXiv, Semantic Scholar). Applies per query variant. Use `search-bulk` for S2 when requesting > 100.
- **MAX_TOTAL_PAPERS = 500** — Overall cap on unique papers collected across all sources, query variants, and snowball expansion. The search continues adding papers until this cap is reached or all queries are exhausted. Set lower (e.g., 100) for faster search.
- **WEB_SEARCH_ALWAYS = true** — WebSearch runs on EVERY literature search regardless of `— sources:` selection. Even if user specifies `— sources: zotero, local`, WebSearch still runs as a supplementary source. Set `false` to disable.
- **CROSS_DOMAIN = true** — Generate cross-domain query variants covering foundational fields (mathematics, signal processing, physics, adjacent ML subfields). Dramatically increases coverage of non-obvious related work from other disciplines.
- **ARXIV_DOWNLOAD = false** — When `true`, download top 3-5 most relevant arXiv PDFs to PAPER_LIBRARY after search. When `false` (default), only fetch metadata (title, abstract, authors) via arXiv API — no files are downloaded.
- **ARXIV_MAX_DOWNLOAD = 500** — Maximum number of PDFs to download when `ARXIV_DOWNLOAD = true`. Downloads all relevant papers found, up to this cap.
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

Before any external API call, generate **8-10 query variants** to maximize coverage across domains. Different papers — even in different fields — may address the same fundamental problem using completely different terminology.

**Domain-specific variants** (5):
1. **Original phrase**: The user's exact topic (e.g., "robot grasping")
2. **Synonym rephrasing**: Alternative terminology (e.g., "object manipulation", "grasp planning")
3. **Broader term**: Wider scope to catch related work (e.g., "learning-based robotics")
4. **Narrower/method-specific**: Core technique name (e.g., "transformer-based policy learning")
5. **Baseline/dataset name**: If domain-specific section below applies, include key baselines (e.g., "DAgger", "PPO")

**Cross-domain variants** (3-5, when `CROSS_DOMAIN = true`):
Identify the **fundamental mathematical/physical problem** underlying the research topic, then generate queries targeting foundational fields:

6. **Mathematics**: What mathematical structures or theories underpin this problem? (e.g., "Lie group integration SO(3)", "optimization on manifolds", "convex relaxation for motion planning", "optimal transport trajectory", "differential geometry rotation estimation")
7. **Signal processing**: What signal processing techniques address similar data characteristics? (e.g., "Kalman filter state estimation", "sensor fusion multi-modal", "adaptive filtering non-stationary signals", "spectral analysis periodic motion")
8. **ML/DL foundations**: What ML paradigms address the same structural challenge? (e.g., "state space models sequential data", "equivariant neural networks SE(3)", "imitation learning", "reinforcement learning exploration", "physics-informed neural networks dynamics")
9. **Physics/mechanics**: What physical laws or models constrain this problem? (e.g., "contact dynamics", "rigid body mechanics", "conservation laws motion estimation", "friction modeling manipulation")
10. **Adjacent application domains**: Where else is the same fundamental problem solved? (e.g., "autonomous driving perception", "drone navigation", "protein folding SE(3)" for rotation estimation, "surgical robotics" for fine manipulation)

**How to generate cross-domain variants**: Decompose the research problem into its fundamental components (e.g., "robot manipulation" = perception + grasp planning + force control + motion generation + sim2real transfer). For each component, ask: "What field has the deepest theory for this sub-problem?" Generate one query per field.

Store ALL variants as `QUERY_VARIANTS` — Step 1 will loop through each variant for every API source.

> 💡 This cross-domain approach is how breakthroughs happen — many advances in ML came from importing ideas from physics (diffusion models ← thermodynamics), information theory (VAEs ← coding theory), and optimal transport (Wasserstein GANs ← mathematics).

### Step 1: Search (external)
- Search arXiv API, Semantic Scholar API, and **WebSearch** using **each query variant**
- **WebSearch is MANDATORY** (`WEB_SEARCH_ALWAYS = true`): Even if user specifies `— sources: zotero`, WebSearch still runs as supplementary. WebSearch catches papers from Google Scholar, conference proceedings, personal pages, and repositories not indexed by arXiv/S2.
- Focus on papers from last 2 years unless studying foundational work or CROSS_DOMAIN queries (which may find older foundational papers)
- **De-duplicate**: Skip papers already found in Zotero, Obsidian, or local library. De-duplicate across query variants by arXiv ID / S2 paperId / title match
- **Accumulation**: Keep adding unique papers until `MAX_TOTAL_PAPERS` (default 500) is reached or all queries are exhausted. Track running count.

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
# For each QUERY_VARIANT (domain-specific):
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY

# If domain is known, add category filter to at least one variant:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --category cs.RO

# For one variant, use date-sorted to catch newest papers:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --sort-by submittedDate

# For cross-domain variants (math, signal processing, physics):
# Use broader categories or no category filter to avoid missing foundational work
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --category math.OC   # optimization
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --category eess.SP   # signal processing
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --category stat.ML   # statistical ML

# If a single query returns exactly API_MAX_PER_QUERY results, there may be more — paginate:
python3 "$SCRIPT" search "VARIANT" --max $API_MAX_PER_QUERY --start 100  # page 2
```

De-duplicate results across variants by arXiv ID. If `arxiv_fetch.py` is not found, fall back to WebSearch.
Stop accumulating when total unique papers reach MAX_TOTAL_PAPERS.

The arXiv API returns structured metadata (title, abstract, full author list, categories, dates) — richer than WebSearch snippets. Merge these results with WebSearch findings and de-duplicate.

**Semantic Scholar API search** (runs by default as part of `all`):

```bash
S2_SCRIPT=$(find tools/ -name "semantic_scholar_fetch.py" 2>/dev/null | head -1)
[ -z "$S2_SCRIPT" ] && S2_SCRIPT=$(find ~/.claude/skills/semantic-scholar/ -name "semantic_scholar_fetch.py" 2>/dev/null | head -1)
```

**Multi-query search** — run S2 API for **each query variant**:
```bash
# For each domain-specific QUERY_VARIANT:
python3 "$S2_SCRIPT" search-bulk "VARIANT" --max $API_MAX_PER_QUERY \
  --fields-of-study "Computer Science,Engineering" \
  --publication-types "JournalArticle,Conference"

# For one variant, also search recent papers sorted by date:
python3 "$S2_SCRIPT" search-bulk "VARIANT" --max $API_MAX_PER_QUERY \
  --sort publicationDate:desc --year "2024-"

# For CROSS-DOMAIN variants: remove field filter to catch math, physics, signal processing papers:
python3 "$S2_SCRIPT" search-bulk "VARIANT" --max $API_MAX_PER_QUERY \
  --publication-types "JournalArticle,Conference"
# (No --fields-of-study filter: allows Mathematics, Physics, Engineering, etc.)

# For high-impact foundational work: sort by citation count:
python3 "$S2_SCRIPT" search-bulk "VARIANT" --max 50 \
  --sort citationCount:desc
```

De-duplicate results across variants by S2 paperId. If `semantic_scholar_fetch.py` is not found, skip silently.
Stop accumulating when total unique papers reach MAX_TOTAL_PAPERS.

**Why use Semantic Scholar?** Many IEEE/ACM journal papers are NOT on arXiv. S2 fills the gap for published venue-only papers with citation counts and venue metadata.

**De-duplication between arXiv and S2**: Match by arXiv ID (S2 returns `externalIds.ArXiv`):
- If a paper appears in both: check S2's `venue`/`publicationVenue` — if it has been published in a journal/conference (e.g. IEEE TWC, JSAC), use S2's metadata (venue, citationCount, DOI) as the authoritative version, since the published version supersedes the preprint. Keep the arXiv PDF link for download.
- If the S2 match has no venue (still just a preprint indexed by S2): keep the arXiv version as-is.
- S2 results without `externalIds.ArXiv` are **venue-only papers** not on arXiv — these are the unique value of this source.

**WebSearch** (MANDATORY — runs for ALL query variants regardless of source selection):

For each query variant, also run WebSearch to catch:
- Google Scholar results not indexed by arXiv/S2
- Conference workshop papers and extended abstracts
- Technical reports and theses
- Papers from non-CS venues (math journals, physics journals, signal processing conferences)
- Pre-print servers other than arXiv (SSRN, HAL, bioRxiv for bio-inspired methods)

```
WebSearch: "VARIANT" site:scholar.google.com OR site:ieeexplore.ieee.org OR site:dl.acm.org
```

Batch 3-5 WebSearch queries at a time. If any hangs > 60 seconds, abandon and continue.

### Step 1.1: Cross-Domain Deep Search (when `CROSS_DOMAIN = true`)

**Skip if `CROSS_DOMAIN = false`.**

After the main domain search, run dedicated searches in foundational fields. The goal is to find theories, methods, and mathematical frameworks from OTHER disciplines that address the same fundamental problem structure.

**Identify fundamental sub-problems**: Decompose the research topic into its mathematical/physical components. For example, "robot manipulation" decomposes into:
- Perception → point cloud processing, 6-DoF pose estimation, scene understanding
- Grasp planning → contact mechanics, grasp quality metrics, optimization on SE(3)
- Force control → impedance/admittance control, contact dynamics, compliance modeling
- Motion generation → trajectory optimization, motion planning, collision avoidance
- Sim-to-real transfer → domain randomization, system identification, domain adaptation

For each sub-problem, search targeted foundational queries:

```bash
# Mathematics foundations:
python3 "$SCRIPT" search "MATH_QUERY" --max $API_MAX_PER_QUERY --category math.OC
python3 "$SCRIPT" search "MATH_QUERY" --max $API_MAX_PER_QUERY --category math.DG
python3 "$S2_SCRIPT" search-bulk "MATH_QUERY" --max $API_MAX_PER_QUERY --fields-of-study "Mathematics"

# Signal processing:
python3 "$SCRIPT" search "SP_QUERY" --max $API_MAX_PER_QUERY --category eess.SP
python3 "$S2_SCRIPT" search-bulk "SP_QUERY" --max $API_MAX_PER_QUERY --fields-of-study "Engineering"

# Statistical ML / theoretical ML:
python3 "$SCRIPT" search "ML_THEORY_QUERY" --max $API_MAX_PER_QUERY --category stat.ML
python3 "$S2_SCRIPT" search-bulk "ML_THEORY_QUERY" --max $API_MAX_PER_QUERY --fields-of-study "Computer Science,Mathematics"

# Physics / mechanics:
python3 "$SCRIPT" search "PHYSICS_QUERY" --max $API_MAX_PER_QUERY --category physics.data-an
python3 "$S2_SCRIPT" search-bulk "PHYSICS_QUERY" --max $API_MAX_PER_QUERY --fields-of-study "Physics"

# Adjacent application domains (where the same math is applied differently):
WebSearch: "ADJACENT_QUERY" — e.g., "protein structure prediction SE(3) equivariance" for rotation problems
```

De-duplicate against ALL previously collected papers. Add unique papers to the candidate pool.

**Cross-domain relevance filter**: Not all cross-domain papers are relevant. For each paper found, assess:
- Does the mathematical framework or core technique address a sub-problem we actually face?
- Is the theoretical insight transferable even if the application domain differs?
- Would the principle extraction protocol (`../shared-references/principle-extraction.md`) yield a useful principle?
Discard papers that are domain-relevant but principle-irrelevant.

Continue until MAX_TOTAL_PAPERS is reached or all cross-domain queries are exhausted.

### Domain-Specific Search: Robotics

When the research topic involves robotics or embodied AI:

**Priority Venues** (via Semantic Scholar):
- IEEE RA-L (Robotics and Automation Letters)
- ICRA (International Conference on Robotics and Automation)
- IROS (International Conference on Intelligent Robots and Systems)
- IEEE TRO (Transactions on Robotics)
- CoRL (Conference on Robot Learning)
- RSS (Robotics: Science and Systems)

**Key Search Terms** (combine and vary):
- Manipulation, grasping, dexterous manipulation, contact-rich manipulation
- Locomotion, legged robotics, quadruped, humanoid control
- Navigation, SLAM, visual navigation, exploration
- Perception, point cloud, 6-DoF pose estimation, scene understanding
- Planning, motion planning, task and motion planning (TAMP)
- Control, model predictive control, impedance control, whole-body control
- Sim-to-real, domain randomization, system identification
- Imitation learning, reinforcement learning for robotics, diffusion policy

**arXiv Categories**:
- cs.RO (Robotics)
- cs.AI (Artificial Intelligence)
- cs.LG (Machine Learning)
- cs.CV (when combined with vision-based robotics)

**Dataset/Benchmark-Specific Search**:
- RLBench, CALVIN, MetaWorld, Open X-Embodiment
- nuScenes, KITTI, Waymo Open Dataset
- Habitat, AI2-THOR, iGibson
- MuJoCo benchmarks, Isaac Gym

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

After analyzing the initial batch, check if the collected papers reveal **terminology, methods, or sub-topics** that were NOT in the original QUERY_VARIANTS. For example, if multiple papers mention "diffusion policy for manipulation" but that phrase was not in any original query, it represents a gap.

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

### Step 6: Research Wiki Integration (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

Ingest the top relevant papers into the wiki for cross-session knowledge accumulation:

```bash
for paper in top_relevant_papers (limit 8-12):
    SLUG=$(python3 tools/research_wiki.py slug "$TITLE" --author "$LAST" --year $YEAR)
    # Create papers/<slug>.md with structured schema
    # Add edges for relationships to existing wiki papers
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "paper:$SLUG" --to "<target>" --type "extends" \
      --evidence "Builds on..."
done
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
python3 tools/research_wiki.py log research-wiki/ "research-lit ingested N papers"
```

This enables `/idea-creator` to read the wiki and avoid re-discovering known work.

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
   python tools/arxiv_fetch.py search "robot manipulation"
   
   # Semantic Scholar — reliable, published venue papers
   python tools/semantic_scholar_fetch.py search "robot manipulation" --year 2024-2026
   ```

6. **Sub-agent timeout**: When launching an Agent for web research, keep the scope narrow (one specific query, not "search everything"). Broad agents are more likely to hang.

## Key Rules
- Always include paper citations (authors, year, venue)
- Distinguish between peer-reviewed and preprints
- Be honest about limitations of each paper
- Note if a paper directly competes with or supports our approach
- **Never fail because a MCP server is not configured** — always fall back gracefully to the next data source
- Zotero/Obsidian tools may have different names depending on how the user configured the MCP server (e.g., `mcp__zotero__search` or `mcp__zotero-mcp__search_items`). Try the most common patterns and adapt.
