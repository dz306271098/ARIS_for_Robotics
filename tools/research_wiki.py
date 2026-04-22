#!/usr/bin/env python3
"""
ARIS Research Wiki — Helper utilities.

Canonical helper for the /research-wiki skill and integration hooks in other
skills. The SKILL.md prose for paper-reading skills (research-lit, arxiv,
alphaxiv, deepxiv, semantic-scholar, exa-search) delegates ingest to this
script; no skill duplicates the page-creation schema.

See shared-references/integration-contract.md §2 (canonical helper rule).

Usage:
    python3 research_wiki.py init <wiki_root>
    python3 research_wiki.py slug "<paper title>" --author "<last name>" --year 2025
    python3 research_wiki.py add_edge <wiki_root> --from <node_id> --to <node_id> --type <edge_type> --evidence "<text>"
    python3 research_wiki.py rebuild_query_pack <wiki_root> [--max-chars 8000]
    python3 research_wiki.py rebuild_index <wiki_root>
    python3 research_wiki.py stats <wiki_root>
    python3 research_wiki.py log <wiki_root> "<message>"

    # Canonical paper ingest (preferred by integration hooks):
    python3 research_wiki.py ingest_paper <wiki_root> --arxiv-id <id> \
        [--thesis "<one-line>"] [--tags tag1,tag2] [--update-on-exist]

    # Manual ingest when arXiv metadata is not available:
    python3 research_wiki.py ingest_paper <wiki_root> \
        --title "<full title>" --authors "A, B, C" --year 2025 \
        --venue <venue> [--external-id-doi <doi>] [--thesis "..."] [--tags ...]

    # Batch backfill (integration-contract §5 repair command):
    python3 research_wiki.py sync <wiki_root> --arxiv-ids id1,id2,id3
    python3 research_wiki.py sync <wiki_root> --from-file ids.txt

    # ARIS v2 — Principle + failure-pattern upsert (canonical CLI):
    python3 research_wiki.py upsert_principle <wiki_root> <slug> \
        --from paper:<slug> --name "<principle>" --generalized "<form>" \
        [--tags tag1,tag2]
    python3 research_wiki.py upsert_failure_pattern <wiki_root> <slug> \
        --from paper:<slug>|idea:<id>|exp:<id> --name "<name>" \
        --generalized "<form>" [--affects-principles a,b] \
        [--resolved-by-principles c,d] [--tags tag1,tag2] \
        [--status active|resolved|theoretical]
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

_ARXIV_API = "http://export.arxiv.org/api/query?id_list={ids}"
_ARXIV_NS = {"atom": "http://www.w3.org/2005/Atom",
             "arxiv": "http://arxiv.org/schemas/atom"}

# Edge types (extended for ARIS v2 principle + failure-pattern entities)
VALID_EDGE_TYPES = {
    # v1 (paper / idea / experiment / claim)
    "extends", "contradicts", "addresses_gap", "inspired_by",
    "tested_by", "supports", "invalidates", "supersedes",
    # v2 principle edges
    "embodies_principle", "shares_principle_with",
    # v2 failure-pattern edges
    "failure_mode_of", "manifested_as", "resolved_by",
}


def slugify(title: str, author_last: str = "", year: int = 0) -> str:
    """Generate a canonical slug: author_last + year + keyword."""
    stop_words = {"a", "an", "the", "of", "for", "in", "on", "with", "via", "and", "to", "by"}
    words = re.sub(r"[^a-z0-9\s]", "", title.lower()).split()
    keywords = [w for w in words if w not in stop_words and len(w) > 2]
    keyword = "_".join(keywords[:3]) if keywords else "untitled"

    author = re.sub(r"[^a-z]", "", author_last.lower()) if author_last else "unknown"
    yr = str(year) if year else "0000"
    return f"{author}{yr}_{keyword}"


def init_wiki(wiki_root: str):
    """Initialize wiki directory structure (v2: includes principles/ and failures/)."""
    root = Path(wiki_root)
    dirs = ["papers", "ideas", "experiments", "claims", "principles", "failures", "graph"]
    for d in dirs:
        (root / d).mkdir(parents=True, exist_ok=True)

    for f in ["index.md", "log.md", "gap_map.md", "query_pack.md"]:
        path = root / f
        if not path.exists():
            if f == "index.md":
                path.write_text("# Research Wiki Index\n\n_Auto-generated. Do not edit._\n")
            elif f == "log.md":
                path.write_text("# Research Wiki Log\n\n_Append-only timeline._\n")
            elif f == "gap_map.md":
                path.write_text("# Gap Map\n\n_Field gaps with stable IDs._\n")
            elif f == "query_pack.md":
                path.write_text("# Query Pack\n\n_Auto-generated for /idea-creator. Max 8000 chars._\n")

    edges_path = root / "graph" / "edges.jsonl"
    if not edges_path.exists():
        edges_path.write_text("")

    append_log(wiki_root, "Wiki initialized")
    print(f"Research wiki initialized at {root}")


def add_edge(wiki_root: str, from_id: str, to_id: str, edge_type: str, evidence: str = ""):
    """Add a typed edge to the relationship graph."""
    if edge_type not in VALID_EDGE_TYPES:
        print(f"Warning: unknown edge type '{edge_type}'. Valid: {VALID_EDGE_TYPES}", file=sys.stderr)

    edges_path = Path(wiki_root) / "graph" / "edges.jsonl"

    existing_edges = []
    if edges_path.exists():
        for line in edges_path.read_text().strip().split("\n"):
            if line.strip():
                try:
                    existing_edges.append(json.loads(line))
                except json.JSONDecodeError:
                    continue

    for e in existing_edges:
        if e.get("from") == from_id and e.get("to") == to_id and e.get("type") == edge_type:
            print(f"Edge already exists: {from_id} --{edge_type}--> {to_id}")
            return

    edge = {
        "from": from_id,
        "to": to_id,
        "type": edge_type,
        "evidence": evidence,
        "added": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    with open(edges_path, "a") as f:
        f.write(json.dumps(edge, ensure_ascii=False) + "\n")

    print(f"Edge added: {from_id} --{edge_type}--> {to_id}")


def rebuild_query_pack(wiki_root: str, max_chars: int = 8000):
    """Generate a compressed query_pack.md for /idea-creator.

    v2 budget: includes Top unresolved failures + principle library sections
    per `research-wiki/SKILL.md`.
    """
    root = Path(wiki_root)
    sections = []

    brief_path = root.parent / "RESEARCH_BRIEF.md"
    if brief_path.exists():
        brief = brief_path.read_text()[:300]
        sections.append(f"## Project Direction\n{brief}\n")

    gap_path = root / "gap_map.md"
    if gap_path.exists():
        gaps = gap_path.read_text()[:1100]
        if gaps.strip() and gaps.strip() != "# Gap Map\n\n_Field gaps with stable IDs._":
            sections.append(f"## Open Gaps\n{gaps}\n")

    # Principle library (v2)
    principles_dir = root / "principles"
    if principles_dir.exists():
        principles = []
        for f in sorted(principles_dir.glob("*.md")):
            meta = _load_paper_frontmatter(f)
            node_id = meta.get("node_id", f.stem)
            name = meta.get("name", f.stem)
            status = meta.get("status", "EXTRACTED")
            principles.append(f"- [{node_id}] ({status}) {name}")
        if principles:
            principles_text = "\n".join(principles[:10])[:1100]
            sections.append(f"## Principle Library ({len(principles)} total)\n{principles_text}\n")

    # Top unresolved failures (v2 — the sharpest ideation seeds)
    failures_dir = root / "failures"
    if failures_dir.exists():
        unresolved = []
        for f in sorted(failures_dir.glob("*.md")):
            content = f.read_text()
            meta = _load_paper_frontmatter(f)
            if meta.get("status", "active") == "active" and "resolved_by_principles: []" in content:
                node_id = meta.get("node_id", f.stem)
                name = meta.get("name", f.stem)
                unresolved.append(f"- [{node_id}] {name}")
        if unresolved:
            unresolved_text = "\n".join(unresolved[:8])[:1000]
            sections.append(f"## Top Unresolved Failures (ideation seeds)\n{unresolved_text}\n")

    # Failed ideas — highest anti-repetition value
    ideas_dir = root / "ideas"
    if ideas_dir.exists():
        failed = []
        for f in sorted(ideas_dir.glob("*.md")):
            content = f.read_text()
            if "outcome: negative" in content or "outcome: mixed" in content:
                lines = content.split("\n")
                title = ""
                failure = ""
                for line in lines:
                    if line.startswith("title:"):
                        title = line.split(":", 1)[1].strip().strip('"')
                    if "failure" in line.lower() or "lesson" in line.lower():
                        idx = lines.index(line)
                        failure = "\n".join(lines[idx:idx+3])
                if title:
                    failed.append(f"- **{title}**: {failure[:200]}")
        if failed:
            failed_text = "\n".join(failed)[:1200]
            sections.append(f"## Failed Ideas (avoid repeating)\n{failed_text}\n")

    # Paper summaries
    papers_dir = root / "papers"
    if papers_dir.exists():
        paper_summaries = []
        for f in sorted(papers_dir.glob("*.md")):
            content = f.read_text()
            node_id = ""
            title = ""
            thesis = ""
            for line in content.split("\n"):
                if line.startswith("node_id:"):
                    node_id = line.split(":", 1)[1].strip()
                if line.startswith("title:"):
                    title = line.split(":", 1)[1].strip().strip('"')
                if line.startswith("# One-line thesis") or line.startswith("## One-line thesis"):
                    idx = content.split("\n").index(line)
                    next_lines = content.split("\n")[idx+1:idx+3]
                    thesis = " ".join(l for l in next_lines if l.strip() and not l.startswith("#"))
            if title:
                paper_summaries.append(f"- [{node_id}] {title}: {thesis[:150]}")

        if paper_summaries:
            papers_text = "\n".join(paper_summaries[:12])[:1400]
            sections.append(f"## Key Papers ({len(paper_summaries)} total)\n{papers_text}\n")

    # Active relationship chains
    edges_path = root / "graph" / "edges.jsonl"
    if edges_path.exists():
        edges = []
        for line in edges_path.read_text().strip().split("\n"):
            if line.strip():
                try:
                    edges.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        if edges:
            chains = []
            for e in edges[-20:]:
                chains.append(f"  {e['from']} --{e['type']}--> {e['to']}")
            chains_text = "\n".join(chains)[:500]
            sections.append(f"## Recent Relationships ({len(edges)} total)\n{chains_text}\n")

    pack = "# Research Wiki Query Pack\n\n_Auto-generated. Do not edit._\n\n"
    for s in sections:
        if len(pack) + len(s) <= max_chars:
            pack += s
        else:
            remaining = max_chars - len(pack) - 20
            if remaining > 100:
                pack += s[:remaining] + "\n...(truncated)\n"
            break

    pack_path = root / "query_pack.md"
    pack_path.write_text(pack)
    print(f"query_pack.md rebuilt: {len(pack)} chars")


def get_stats(wiki_root: str):
    """Print wiki statistics (v2: includes principles + failures counts)."""
    root = Path(wiki_root)

    def count_files(subdir):
        d = root / subdir
        return len(list(d.glob("*.md"))) if d.exists() else 0

    def count_by_field(subdir, field, value):
        d = root / subdir
        if not d.exists():
            return 0
        count = 0
        for f in d.glob("*.md"):
            if f"{field}: {value}" in f.read_text():
                count += 1
        return count

    papers = count_files("papers")
    ideas = count_files("ideas")
    experiments = count_files("experiments")
    claims = count_files("claims")
    principles = count_files("principles")
    failures = count_files("failures")

    edges_path = root / "graph" / "edges.jsonl"
    edge_count = 0
    if edges_path.exists():
        edge_count = sum(1 for line in edges_path.read_text().strip().split("\n") if line.strip())

    print(f"📚 Research Wiki Stats")
    print(f"Papers:           {papers}")
    print(f"Ideas:            {ideas} ({count_by_field('ideas', 'outcome', 'negative')} failed, "
          f"{count_by_field('ideas', 'outcome', 'positive')} succeeded)")
    print(f"Experiments:      {experiments}")
    print(f"Claims:           {claims} ({count_by_field('claims', 'status', 'supported')} supported, "
          f"{count_by_field('claims', 'status', 'invalidated')} invalidated)")
    print(f"Principles:       {principles}")
    print(f"Failure patterns: {failures} ({count_by_field('failures', 'status', 'active')} active, "
          f"{count_by_field('failures', 'status', 'resolved')} resolved)")
    print(f"Edges:            {edge_count}")
    print(f"Wiki root:        {root}")


def append_log(wiki_root: str, message: str):
    """Append a timestamped entry to log.md."""
    log_path = Path(wiki_root) / "log.md"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    entry = f"- `{ts}` {message}\n"

    if log_path.exists():
        with open(log_path, "a") as f:
            f.write(entry)
    else:
        log_path.write_text(f"# Research Wiki Log\n\n{entry}")


# ═════════════════════════════════════════════════════════════════════════════
# v2 additions: canonical helpers (per integration-contract §2)
# ═════════════════════════════════════════════════════════════════════════════

def _normalize_arxiv_id(arxiv_id: str) -> str:
    """Strip common prefixes and version suffix from arxiv id.

    Preserves legacy category-prefixed IDs: `cs/0601001`, `cs.LG/0703124`
    stay as-is (minus any trailing vN); modern IDs like `2501.12345v2`
    become `2501.12345`. The arXiv API accepts both forms via `id_list=`.
    """
    s = arxiv_id.strip()
    for prefix in ("arXiv:", "arxiv:", "http://arxiv.org/abs/", "https://arxiv.org/abs/"):
        if s.lower().startswith(prefix.lower()):
            s = s[len(prefix):]
    # Never split on '/' — legacy IDs are `category/NNNNNNN`.
    s = re.sub(r"v\d+$", "", s)
    return s


def _yaml_quote(s: str) -> str:
    """YAML double-quoted string escape: backslash and double-quote."""
    if s is None:
        return '""'
    s = str(s).replace("\r", "").replace("\t", " ")
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
    return f'"{s}"'


def fetch_arxiv_metadata(arxiv_id: str, timeout: float = 15.0) -> dict:
    """Query arXiv Atom API for one paper. Returns a metadata dict.

    Raises RuntimeError on network failure or malformed response — callers
    decide whether to abort the ingest or fall back to manual metadata.
    """
    aid = _normalize_arxiv_id(arxiv_id)
    url = _ARXIV_API.format(ids=aid)
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            body = resp.read()
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise RuntimeError(f"arXiv API fetch failed for {aid}: {e}")

    try:
        root = ET.fromstring(body)
    except ET.ParseError as e:
        raise RuntimeError(f"arXiv API returned unparseable XML for {aid}: {e}")

    entry = root.find("atom:entry", _ARXIV_NS)
    if entry is None:
        raise RuntimeError(f"arXiv API returned no entry for {aid}")

    def _txt(el, default=""):
        return el.text.strip() if el is not None and el.text else default

    title = _txt(entry.find("atom:title", _ARXIV_NS))
    title = re.sub(r"\s+", " ", title)
    summary = _txt(entry.find("atom:summary", _ARXIV_NS))
    summary = re.sub(r"\s+", " ", summary)
    published = _txt(entry.find("atom:published", _ARXIV_NS))
    year = int(published[:4]) if published[:4].isdigit() else 0

    authors = []
    for a in entry.findall("atom:author", _ARXIV_NS):
        n = _txt(a.find("atom:name", _ARXIV_NS))
        if n:
            authors.append(n)

    primary = entry.find("arxiv:primary_category", _ARXIV_NS)
    primary_cat = primary.get("term") if primary is not None else ""

    journal_ref = _txt(entry.find("arxiv:journal_ref", _ARXIV_NS))
    venue = journal_ref if journal_ref else "arXiv"

    return {
        "arxiv_id": aid,
        "title": title,
        "authors": authors,
        "year": year,
        "venue": venue,
        "abstract": summary,
        "primary_category": primary_cat,
    }


def _last_name(full_name: str) -> str:
    """Crude last-name extraction for slug generation."""
    parts = full_name.strip().split()
    return parts[-1] if parts else ""


def _load_paper_frontmatter(path: Path) -> dict:
    """Parse the YAML-ish frontmatter of a wiki page. Returns {} on failure."""
    if not path.exists():
        return {}
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    meta = {}
    for line in m.group(1).split("\n"):
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip().strip('"').strip("'")
    return meta


def _find_existing_page_by_arxiv(wiki_root: Path, arxiv_id: str):
    papers = wiki_root / "papers"
    if not papers.exists():
        return None
    for p in papers.glob("*.md"):
        text = p.read_text()
        if re.search(r'arxiv:\s*["\']?' + re.escape(arxiv_id) + r'["\']?', text):
            return p
        if re.search(r"arxiv\.org/abs/" + re.escape(arxiv_id), text):
            return p
    return None


def _render_paper_page(meta: dict, slug: str, thesis: str, tags) -> str:
    """Render the markdown paper page following research-wiki SKILL.md schema."""
    tags = tags or []
    lines = ["---"]
    lines.append(f"type: paper")
    lines.append(f"node_id: paper:{slug}")
    lines.append(f"title: {_yaml_quote(meta.get('title', ''))}")
    authors = meta.get("authors", [])
    lines.append("authors: [" + ", ".join(_yaml_quote(a) for a in authors) + "]")
    lines.append(f"year: {meta.get('year', 0)}")
    lines.append(f"venue: {_yaml_quote(meta.get('venue', 'arXiv'))}")
    lines.append("external_ids:")
    for k, v in [("arxiv", meta.get("arxiv_id", "")),
                 ("doi", meta.get("doi", "")),
                 ("s2", meta.get("s2_id", ""))]:
        value_str = _yaml_quote(v) if v else "null"
        lines.append(f"  {k}: {value_str}")
    lines.append("tags: [" + ", ".join(_yaml_quote(t) for t in tags) + "]")
    lines.append("relevance: related")
    lines.append("origin_skill: research-lit")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines.append(f"created_at: {now}")
    lines.append(f"updated_at: {now}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {meta.get('title', slug)}")
    lines.append("")
    lines.append("## One-line thesis")
    lines.append("")
    lines.append(thesis or "_TODO: fill in after reading._")
    lines.append("")
    for section in ["Problem / Gap", "Method", "Key Results",
                    "Assumptions", "Limitations / Failure Modes",
                    "Reusable Ingredients", "Open Questions", "Claims"]:
        lines.append(f"## {section}")
        lines.append("")
        lines.append("_TODO._")
        lines.append("")
    lines.append("## Connections")
    lines.append("")
    lines.append("_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._")
    lines.append("")
    lines.append("## Relevance to This Project")
    lines.append("")
    lines.append("_TODO._")
    lines.append("")
    if meta.get("abstract"):
        lines.append("## Abstract (original)")
        lines.append("")
        lines.append("> " + meta["abstract"])
        lines.append("")

    return "\n".join(lines) + "\n"


def ingest_paper(wiki_root: str, *, arxiv_id: str = "", title: str = "",
                 authors=None, year: int = 0,
                 venue: str = "", doi: str = "", thesis: str = "",
                 tags=None,
                 update_on_exist: bool = False) -> Path:
    """Canonical paper-ingest entrypoint.

    Preferred: pass --arxiv-id and let the helper fetch metadata. If the
    arXiv lookup fails (offline, unknown id), callers may supply
    title/authors/year/venue manually; doi is optional.

    Always:
      - slugs the title (author + year + keyword)
      - dedups by arxiv_id first, then by slug — `update_on_exist=False`
        skips rewriting an existing page
      - creates papers/<slug>.md with the schema from research-wiki SKILL.md
      - rebuilds index.md and query_pack.md
      - appends to log.md
    """
    root = Path(wiki_root)
    if not (root / "papers").exists():
        raise RuntimeError(f"{root} is not an initialized wiki (papers/ missing). "
                           f"Run `init` first.")

    tags = tags or []
    authors = authors or []

    meta: dict = {}
    existing = None
    if arxiv_id:
        aid = _normalize_arxiv_id(arxiv_id)
        existing = _find_existing_page_by_arxiv(root, aid)
        if existing and not update_on_exist:
            append_log(str(root), f"ingest_paper: skipped existing paper "
                                  f"{existing.name} (arxiv:{aid})")
            print(f"Paper already ingested: {existing.name} (arxiv:{aid}) — skipping.")
            return existing
        try:
            meta = fetch_arxiv_metadata(aid)
        except RuntimeError as e:
            if title:
                print(f"Warning: {e} — falling back to manual metadata.", file=sys.stderr)
                meta = {"arxiv_id": aid}
            else:
                raise
        if title:
            meta["title"] = title
        if authors:
            meta["authors"] = authors
        if year:
            meta["year"] = year
        if venue:
            meta["venue"] = venue
    else:
        if not (title and authors and year):
            raise RuntimeError("Manual ingest requires --title, --authors, and --year "
                               "when --arxiv-id is not supplied.")
        meta = {
            "arxiv_id": "",
            "title": title,
            "authors": authors,
            "year": year,
            "venue": venue or "unknown",
        }
    if doi:
        meta["doi"] = doi

    author_last = _last_name(meta["authors"][0]) if meta.get("authors") else ""
    slug = slugify(meta["title"], author_last, meta.get("year", 0))

    if existing:
        page_path = existing
        slug = existing.stem
        was_update = True
    else:
        page_path = root / "papers" / f"{slug}.md"
        if page_path.exists():
            if not update_on_exist:
                append_log(str(root), f"ingest_paper: skipped existing paper "
                                      f"{page_path.name} (slug dedup)")
                print(f"Paper already ingested: {page_path.name} (slug dedup) — skipping.")
                return page_path
            was_update = True
        else:
            was_update = False

    rendered = _render_paper_page(meta, slug, thesis, tags)
    page_path.write_text(rendered)

    rebuild_index(str(root))
    rebuild_query_pack(str(root))

    action = "updated" if was_update else "ingested"
    append_log(str(root), f"ingest_paper: {action} paper:{slug} "
                          f"(arxiv:{meta.get('arxiv_id','-')})")
    print(f"Paper {action}: {page_path}")
    return page_path


def sync_papers(wiki_root: str, arxiv_ids, update_on_exist: bool = False) -> None:
    """Batch backfill: ingest each arxiv id; dedup is handled per-id."""
    errors = []
    for aid in arxiv_ids:
        aid = aid.strip()
        if not aid:
            continue
        try:
            ingest_paper(wiki_root, arxiv_id=aid, update_on_exist=update_on_exist)
        except RuntimeError as e:
            print(f"ERROR: {aid}: {e}", file=sys.stderr)
            errors.append((aid, str(e)))
    if errors:
        print(f"\nsync: {len(errors)} error(s)", file=sys.stderr)
        sys.exit(1)


def rebuild_index(wiki_root: str) -> None:
    """Regenerate index.md from wiki entity files (v2: includes principles + failures)."""
    root = Path(wiki_root)
    lines = ["# Research Wiki Index", "",
             "_Auto-generated by `research_wiki.py rebuild_index`. Do not edit._", ""]

    for subdir, header in [("papers", "Papers"), ("ideas", "Ideas"),
                            ("experiments", "Experiments"), ("claims", "Claims"),
                            ("principles", "Principles"), ("failures", "Failure Patterns")]:
        d = root / subdir
        if not d.exists():
            continue
        entries = []
        for f in sorted(d.glob("*.md")):
            meta = _load_paper_frontmatter(f)
            node_id = meta.get("node_id", f.stem)
            title = meta.get("title", meta.get("name", f.stem))
            year = meta.get("year", "")
            entries.append(f"- `{node_id}` — {title}" + (f" ({year})" if year else ""))
        if entries:
            lines.append(f"## {header} ({len(entries)})")
            lines.extend(entries)
            lines.append("")

    (root / "index.md").write_text("\n".join(lines) + "\n")
    print(f"index.md rebuilt")


def upsert_principle(wiki_root: str, slug: str, *, from_node: str,
                     name: str, generalized_form: str,
                     tags=None, status: str = "EXTRACTED") -> Path:
    """Create or update a principle page. ARIS v2 entity.

    See research-wiki/SKILL.md — Six Entity Types + upsert_principle schema.
    """
    root = Path(wiki_root)
    principles_dir = root / "principles"
    principles_dir.mkdir(parents=True, exist_ok=True)

    tags = tags or []
    page_path = principles_dir / f"{slug}.md"
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    is_update = page_path.exists()
    if is_update:
        # Preserve existing evidence_papers by reading current content
        existing_meta = _load_paper_frontmatter(page_path)
        existing_evidence = existing_meta.get("evidence_papers", "")
    else:
        existing_evidence = ""

    lines = ["---"]
    lines.append("type: principle")
    lines.append(f"node_id: principle:{slug}")
    lines.append(f"name: {_yaml_quote(name)}")
    lines.append(f"generalized_form: {_yaml_quote(generalized_form)}")
    lines.append(f"evidence_papers: [{from_node}]")
    lines.append("tested_in_projects: []")
    lines.append(f"status: {status}")
    lines.append("tags: [" + ", ".join(_yaml_quote(t) for t in tags) + "]")
    lines.append("origin_skill: research-lit")
    if not is_update:
        lines.append(f"created_at: {now}")
    lines.append(f"updated_at: {now}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {name}")
    lines.append("")
    lines.append("## One-sentence principle")
    lines.append("")
    lines.append(name)
    lines.append("")
    lines.append("## Generalized Form")
    lines.append("")
    lines.append(generalized_form)
    lines.append("")
    lines.append("## Surface Methods That Embody It")
    lines.append("")
    lines.append(f"- {from_node}")
    lines.append("")
    lines.append("## Adaptations Tested")
    lines.append("")
    lines.append("_None yet._")
    lines.append("")
    lines.append("## Anti-Copying Guard")
    lines.append("")
    lines.append("_See `shared-references/principle-extraction.md` Layer 5._")
    lines.append("")
    lines.append("## Connections")
    lines.append("")
    lines.append("_Edges are recorded in `graph/edges.jsonl`._")
    lines.append("")

    page_path.write_text("\n".join(lines) + "\n")

    # Add edge from source to principle
    if from_node.startswith(("paper:", "idea:")):
        add_edge(str(root), from_node, f"principle:{slug}", "embodies_principle",
                 evidence=f"upsert_principle auto-link at {now}")

    action = "updated" if is_update else "created"
    append_log(str(root), f"upsert_principle: {action} principle:{slug} "
                          f"(from {from_node})")
    print(f"Principle {action}: {page_path}")
    return page_path


def upsert_failure_pattern(wiki_root: str, slug: str, *, from_node: str,
                           name: str, generalized_form: str,
                           affects_principles=None,
                           resolved_by_principles=None,
                           tags=None,
                           status: str = "active") -> Path:
    """Create or update a failure-pattern page. ARIS v2 entity.

    See research-wiki/SKILL.md — Six Entity Types + upsert_failure-pattern schema.
    """
    root = Path(wiki_root)
    failures_dir = root / "failures"
    failures_dir.mkdir(parents=True, exist_ok=True)

    affects_principles = affects_principles or []
    resolved_by_principles = resolved_by_principles or []
    tags = tags or []

    page_path = failures_dir / f"{slug}.md"
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    is_update = page_path.exists()

    lines = ["---"]
    lines.append("type: failure-pattern")
    lines.append(f"node_id: failure-pattern:{slug}")
    lines.append(f"name: {_yaml_quote(name)}")
    lines.append(f"generalized_form: {_yaml_quote(generalized_form)}")
    ep_entry = f"[{from_node}]" if from_node.startswith("paper:") else "[]"
    mi_entry = f"[{from_node}]" if from_node.startswith("idea:") else "[]"
    me_entry = f"[{from_node}]" if from_node.startswith("exp:") else "[]"
    lines.append(f"evidence_papers: {ep_entry}")
    lines.append(f"manifested_in_ideas: {mi_entry}")
    lines.append(f"manifested_in_experiments: {me_entry}")
    lines.append("affects_principles: [" + ", ".join(
        f"principle:{p.removeprefix('principle:')}" if not p.startswith("principle:") else p
        for p in affects_principles) + "]")
    lines.append("resolved_by_principles: [" + ", ".join(
        f"principle:{p.removeprefix('principle:')}" if not p.startswith("principle:") else p
        for p in resolved_by_principles) + "]")
    lines.append(f"status: {status}")
    lines.append("tags: [" + ", ".join(_yaml_quote(t) for t in tags) + "]")
    lines.append("origin_skill: research-lit")
    if not is_update:
        lines.append(f"created_at: {now}")
    lines.append(f"updated_at: {now}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {name}")
    lines.append("")
    lines.append("## Underlying Trigger")
    lines.append("")
    lines.append(generalized_form)
    lines.append("")
    lines.append("## Generalized Conditions")
    lines.append("")
    lines.append("_See `shared-references/failure-extraction.md` Layer 3._")
    lines.append("")
    lines.append("## Evidence")
    lines.append("")
    lines.append(f"- {from_node}")
    lines.append("")
    lines.append("## Resolution Attempts")
    lines.append("")
    if resolved_by_principles:
        for p in resolved_by_principles:
            pid = p if p.startswith("principle:") else f"principle:{p}"
            lines.append(f"- {pid}")
    else:
        lines.append("_No known resolution._")
    lines.append("")
    lines.append("## Connections")
    lines.append("")
    lines.append("_Edges recorded in `graph/edges.jsonl`._")
    lines.append("")

    page_path.write_text("\n".join(lines) + "\n")

    # Add edges
    for ap in affects_principles:
        pid = ap if ap.startswith("principle:") else f"principle:{ap}"
        add_edge(str(root), f"failure-pattern:{slug}", pid, "failure_mode_of",
                 evidence=f"upsert_failure_pattern auto-link at {now}")
    for rp in resolved_by_principles:
        pid = rp if rp.startswith("principle:") else f"principle:{rp}"
        add_edge(str(root), pid, f"failure-pattern:{slug}", "resolved_by",
                 evidence=f"upsert_failure_pattern auto-link at {now}")
    if from_node.startswith(("idea:", "exp:")):
        add_edge(str(root), from_node, f"failure-pattern:{slug}", "manifested_as",
                 evidence=f"upsert_failure_pattern auto-link at {now}")

    action = "updated" if is_update else "created"
    append_log(str(root), f"upsert_failure_pattern: {action} failure-pattern:{slug} "
                          f"(from {from_node})")
    print(f"Failure pattern {action}: {page_path}")
    return page_path


def main():
    parser = argparse.ArgumentParser(description="ARIS Research Wiki utilities")
    subparsers = parser.add_subparsers(dest="command")

    p_init = subparsers.add_parser("init")
    p_init.add_argument("wiki_root")

    p_slug = subparsers.add_parser("slug")
    p_slug.add_argument("title")
    p_slug.add_argument("--author", default="")
    p_slug.add_argument("--year", type=int, default=0)

    p_edge = subparsers.add_parser("add_edge")
    p_edge.add_argument("wiki_root")
    p_edge.add_argument("--from", dest="from_id", required=True)
    p_edge.add_argument("--to", dest="to_id", required=True)
    p_edge.add_argument("--type", dest="edge_type", required=True)
    p_edge.add_argument("--evidence", default="")

    p_qp = subparsers.add_parser("rebuild_query_pack")
    p_qp.add_argument("wiki_root")
    p_qp.add_argument("--max-chars", type=int, default=8000)

    p_idx = subparsers.add_parser("rebuild_index")
    p_idx.add_argument("wiki_root")

    p_stats = subparsers.add_parser("stats")
    p_stats.add_argument("wiki_root")

    p_log = subparsers.add_parser("log")
    p_log.add_argument("wiki_root")
    p_log.add_argument("message")

    p_ing = subparsers.add_parser("ingest_paper",
                                   help="Create (or update) a papers/<slug>.md page")
    p_ing.add_argument("wiki_root")
    p_ing.add_argument("--arxiv-id", default="")
    p_ing.add_argument("--title", default="")
    p_ing.add_argument("--authors", default="")
    p_ing.add_argument("--year", type=int, default=0)
    p_ing.add_argument("--venue", default="")
    p_ing.add_argument("--external-id-doi", dest="doi", default="")
    p_ing.add_argument("--thesis", default="")
    p_ing.add_argument("--tags", default="")
    p_ing.add_argument("--update-on-exist", action="store_true")

    p_sync = subparsers.add_parser("sync",
                                    help="Batch ingest from a list of arXiv IDs")
    p_sync.add_argument("wiki_root")
    p_sync.add_argument("--arxiv-ids", default="")
    p_sync.add_argument("--from-file", default="")
    p_sync.add_argument("--update-on-exist", action="store_true")

    p_up_p = subparsers.add_parser("upsert_principle",
                                    help="Create or update a principle page (ARIS v2)")
    p_up_p.add_argument("wiki_root")
    p_up_p.add_argument("slug")
    p_up_p.add_argument("--from", dest="from_node", required=True,
                        help="Source node_id, e.g. paper:chen2025_factorized_gap")
    p_up_p.add_argument("--name", required=True)
    p_up_p.add_argument("--generalized", dest="generalized_form", required=True)
    p_up_p.add_argument("--tags", default="")
    p_up_p.add_argument("--status", default="EXTRACTED",
                        choices=["EXTRACTED", "APPLIED", "SUPERSEDED", "INVALIDATED"])

    p_up_f = subparsers.add_parser("upsert_failure_pattern",
                                    help="Create or update a failure-pattern page (ARIS v2)")
    p_up_f.add_argument("wiki_root")
    p_up_f.add_argument("slug")
    p_up_f.add_argument("--from", dest="from_node", required=True,
                        help="Source node_id, e.g. paper:<slug>|idea:<id>|exp:<id>")
    p_up_f.add_argument("--name", required=True)
    p_up_f.add_argument("--generalized", dest="generalized_form", required=True)
    p_up_f.add_argument("--affects-principles", default="",
                        help="Comma-separated principle slugs the failure afflicts")
    p_up_f.add_argument("--resolved-by-principles", default="",
                        help="Comma-separated principle slugs that resolve the failure")
    p_up_f.add_argument("--tags", default="")
    p_up_f.add_argument("--status", default="active",
                        choices=["active", "resolved", "theoretical"])

    args = parser.parse_args()

    if args.command == "init":
        init_wiki(args.wiki_root)
    elif args.command == "slug":
        print(slugify(args.title, args.author, args.year))
    elif args.command == "add_edge":
        add_edge(args.wiki_root, args.from_id, args.to_id, args.edge_type, args.evidence)
    elif args.command == "rebuild_query_pack":
        rebuild_query_pack(args.wiki_root, args.max_chars)
    elif args.command == "rebuild_index":
        rebuild_index(args.wiki_root)
    elif args.command == "stats":
        get_stats(args.wiki_root)
    elif args.command == "log":
        append_log(args.wiki_root, args.message)
    elif args.command == "ingest_paper":
        authors = [a.strip() for a in args.authors.split(",") if a.strip()]
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        ingest_paper(args.wiki_root,
                     arxiv_id=args.arxiv_id, title=args.title,
                     authors=authors, year=args.year, venue=args.venue,
                     doi=args.doi, thesis=args.thesis, tags=tags,
                     update_on_exist=args.update_on_exist)
    elif args.command == "sync":
        ids = []
        if args.arxiv_ids:
            ids.extend([i.strip() for i in args.arxiv_ids.split(",") if i.strip()])
        if args.from_file:
            fp = Path(args.from_file)
            if not fp.exists():
                print(f"--from-file not found: {fp}", file=sys.stderr)
                sys.exit(2)
            for line in fp.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    ids.append(line)
        if not ids:
            print("sync: no arxiv ids supplied (use --arxiv-ids or --from-file)",
                  file=sys.stderr)
            sys.exit(2)
        seen = set()
        uniq_ids = []
        for i in ids:
            key = _normalize_arxiv_id(i)
            if key in seen:
                continue
            seen.add(key)
            uniq_ids.append(i)
        sync_papers(args.wiki_root, uniq_ids, update_on_exist=args.update_on_exist)
    elif args.command == "upsert_principle":
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        upsert_principle(args.wiki_root, args.slug,
                          from_node=args.from_node, name=args.name,
                          generalized_form=args.generalized_form,
                          tags=tags, status=args.status)
    elif args.command == "upsert_failure_pattern":
        ap = [a.strip() for a in args.affects_principles.split(",") if a.strip()]
        rp = [r.strip() for r in args.resolved_by_principles.split(",") if r.strip()]
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        upsert_failure_pattern(args.wiki_root, args.slug,
                                from_node=args.from_node, name=args.name,
                                generalized_form=args.generalized_form,
                                affects_principles=ap,
                                resolved_by_principles=rp,
                                tags=tags, status=args.status)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
