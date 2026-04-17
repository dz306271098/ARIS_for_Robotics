#!/usr/bin/env python3
"""
ARIS Research Wiki - Helper utilities.
Provides slug generation, page creation, edge management, query_pack generation,
additional context packs, and stats.
Called by the /research-wiki skill and integration hooks in other skills.

Usage:
    python3 research_wiki.py init <wiki_root>
    python3 research_wiki.py slug "<paper title>" --author "<last name>" --year 2025
    python3 research_wiki.py add_edge <wiki_root> --from <node_id> --to <node_id> --type <edge_type> --evidence "<text>"
    python3 research_wiki.py rebuild_query_pack <wiki_root> [--max-chars 8000]
    python3 research_wiki.py rebuild_packs <wiki_root> [--max-chars 8000]
    python3 research_wiki.py stats <wiki_root>
    python3 research_wiki.py log <wiki_root> "<message>"
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def slugify(title: str, author_last: str = "", year: int = 0) -> str:
    """Generate a canonical slug: author_last + year + keyword."""
    stop_words = {"a", "an", "the", "of", "for", "in", "on", "with", "via", "and", "to", "by"}
    words = re.sub(r"[^a-z0-9\s]", "", title.lower()).split()
    keywords = [w for w in words if w not in stop_words and len(w) > 2]
    keyword = "_".join(keywords[:3]) if keywords else "untitled"
    author = re.sub(r"[^a-z]", "", author_last.lower()) if author_last else "unknown"
    yr = str(year) if year else "0000"
    return f"{author}{yr}_{keyword}"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def extract_frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    if not match:
        return {}
    result: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        result[key.strip()] = value.strip().strip('"')
    return result


def extract_section(text: str, heading: str) -> str:
    pattern = rf"^## {re.escape(heading)}\s*$([\s\S]*?)(?=^##\s|\Z)"
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1).strip() if match else ""


def summarize_line(text: str, limit: int = 180) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text[:limit] + ("..." if len(text) > limit else "")


def list_pages(root: Path, subdir: str) -> list[Path]:
    directory = root / subdir
    return sorted(directory.glob("*.md")) if directory.exists() else []


def append_log(wiki_root: str, message: str):
    root = Path(wiki_root)
    log_path = root / "log.md"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"- {timestamp} - {message}\n")


def init_wiki(wiki_root: str):
    root = Path(wiki_root)
    dirs = ["papers", "ideas", "experiments", "claims", "principles", "graph"]
    for d in dirs:
        (root / d).mkdir(parents=True, exist_ok=True)

    defaults = {
        "index.md": "# Research Wiki Index\n\n_Auto-generated. Do not edit._\n",
        "log.md": "# Research Wiki Log\n\n_Append-only timeline._\n",
        "gap_map.md": "# Gap Map\n\n_Field gaps with stable IDs._\n",
        "query_pack.md": "# Research Wiki Query Pack\n\n_Auto-generated for rapid ideation._\n",
        "principle_pack.md": "# Principle Pack\n\n_Auto-generated for route design and innovation._\n",
        "analogy_pack.md": "# Analogy Pack\n\n_Auto-generated cross-domain candidates._\n",
        "failure_pack.md": "# Failure Pack\n\n_Auto-generated anti-repetition memory._\n",
    }
    for name, content in defaults.items():
        path = root / name
        if not path.exists():
            path.write_text(content, encoding="utf-8")

    edges_path = root / "graph" / "edges.jsonl"
    if not edges_path.exists():
        edges_path.write_text("", encoding="utf-8")

    append_log(wiki_root, "Wiki initialized")
    print(f"Research wiki initialized at {root}")


def add_edge(wiki_root: str, from_id: str, to_id: str, edge_type: str, evidence: str = ""):
    valid_types = {
        "extends", "contradicts", "addresses_gap", "inspired_by",
        "tested_by", "supports", "invalidates", "supersedes",
        "distills", "applies_principle", "tests_principle", "motivates", "revives",
    }
    if edge_type not in valid_types:
        print(f"Warning: unknown edge type '{edge_type}'. Valid: {sorted(valid_types)}", file=sys.stderr)

    edges_path = Path(wiki_root) / "graph" / "edges.jsonl"
    existing_edges = []
    if edges_path.exists():
        for line in edges_path.read_text(encoding="utf-8").strip().split("\n"):
            if not line.strip():
                continue
            try:
                existing_edges.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    for edge in existing_edges:
        if edge.get("from") == from_id and edge.get("to") == to_id and edge.get("type") == edge_type:
            print(f"Edge already exists: {from_id} --{edge_type}--> {to_id}")
            return

    edge = {
        "from": from_id,
        "to": to_id,
        "type": edge_type,
        "evidence": evidence,
        "added": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    with open(edges_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(edge, ensure_ascii=False) + "\n")
    print(f"Edge added: {from_id} --{edge_type}--> {to_id}")


def build_project_direction(root: Path) -> str:
    project_root = root.parent
    for candidate in ("CODEX.md", "RESEARCH_BRIEF.md"):
        path = project_root / candidate
        if not path.exists():
            continue
        content = read_text(path)
        if candidate == "CODEX.md":
            match = re.search(r"^## Research Direction\s*$([\s\S]*?)(?=^##\s|\Z)", content, re.MULTILINE)
            if match:
                return summarize_line(match.group(1), 320)
        return summarize_line(content, 320)
    return ""


def gather_gaps(root: Path) -> str:
    gap_path = root / "gap_map.md"
    content = read_text(gap_path)
    content = content.replace("# Gap Map", "").replace("_Field gaps with stable IDs._", "").strip()
    return content[:1200]


def gather_principles(root: Path) -> list[dict[str, str]]:
    principles = []
    for page in list_pages(root, "principles"):
        text = read_text(page)
        fm = extract_frontmatter(text)
        title = fm.get("title") or page.stem.replace("_", " ")
        distilled = extract_section(text, "Distilled Principle")
        preconditions = extract_section(text, "Preconditions")
        adaptation = extract_section(text, "Adaptation to This Project") or extract_section(text, "Adaptation To Our Problem")
        source_field = fm.get("source_field") or summarize_line(extract_section(text, "Source Field"), 80)
        if distilled or adaptation:
            principles.append({
                "title": title,
                "node_id": fm.get("node_id", f"principle:{page.stem}"),
                "distilled": summarize_line(distilled, 220),
                "preconditions": summarize_line(preconditions, 180),
                "adaptation": summarize_line(adaptation, 220),
                "source_field": source_field or "current-domain",
            })
    return principles


def gather_failed_ideas(root: Path) -> list[str]:
    failed = []
    for page in list_pages(root, "ideas"):
        text = read_text(page)
        fm = extract_frontmatter(text)
        outcome = fm.get("outcome", "")
        if outcome not in {"negative", "mixed", "killed", "rejected"} and "outcome: negative" not in text and "outcome: mixed" not in text:
            continue
        title = fm.get("title") or page.stem
        failure = extract_section(text, "Failure Notes") or extract_section(text, "Lessons") or extract_section(text, "Why It Died")
        revive = extract_section(text, "Revive Conditions")
        line = f"- **{title}**: {summarize_line(failure or 'negative or mixed outcome recorded', 180)}"
        if revive:
            line += f" | revive: {summarize_line(revive, 120)}"
        failed.append(line)
    return failed


def gather_invalidated_claims(root: Path) -> list[str]:
    invalidated = []
    for page in list_pages(root, "claims"):
        text = read_text(page)
        fm = extract_frontmatter(text)
        status = fm.get("status", "")
        if status not in {"invalidated", "partial", "unsupported"} and "status: invalidated" not in text:
            continue
        title = fm.get("title") or page.stem
        evidence = extract_section(text, "Evidence") or extract_section(text, "Failure Notes")
        invalidated.append(f"- **{title}**: {summarize_line(evidence or status or 'claim invalidated', 180)}")
    return invalidated


def gather_papers(root: Path) -> list[str]:
    summaries = []
    for page in list_pages(root, "papers"):
        text = read_text(page)
        fm = extract_frontmatter(text)
        title = fm.get("title") or page.stem
        thesis = ""
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if line.strip() == "# One-line thesis":
                thesis = " ".join(l.strip() for l in lines[idx + 1:idx + 3] if l.strip() and not l.startswith("#"))
                break
        if not thesis:
            thesis = extract_section(text, "Method") or extract_section(text, "Relevance to This Project")
        node_id = fm.get("node_id", f"paper:{page.stem}")
        summaries.append(f"- [{node_id}] {title}: {summarize_line(thesis, 160)}")
    return summaries


def gather_analogies(root: Path, principles: list[dict[str, str]]) -> list[str]:
    analogies = []
    for item in principles:
        if item["source_field"] and item["source_field"] not in {"", "current-domain"}:
            analogies.append(
                f"- **{item['title']}** from `{item['source_field']}`: {item['distilled']} | adaptation: {item['adaptation']}"
            )
    if analogies:
        return analogies

    for page in list_pages(root, "papers") + list_pages(root, "ideas"):
        text = read_text(page)
        for heading in ("Analogy Candidates", "Cross-Domain Opportunity", "Adjacent Fields"):
            section = extract_section(text, heading)
            if section:
                analogies.append(f"- **{page.stem}**: {summarize_line(section, 220)}")
                break
    return analogies


def gather_recent_relationships(root: Path) -> list[str]:
    edges_path = root / "graph" / "edges.jsonl"
    relationships = []
    for line in read_text(edges_path).strip().split("\n"):
        if not line.strip():
            continue
        try:
            edge = json.loads(line)
        except json.JSONDecodeError:
            continue
        relationships.append(f"- {edge['from']} --{edge['type']}--> {edge['to']}")
    return relationships[-20:]


def write_pack(path: Path, title: str, sections: list[tuple[str, str]], max_chars: int):
    pack = f"# {title}\n\n_Auto-generated. Do not edit._\n\n"
    for heading, body in sections:
        if not body.strip():
            continue
        chunk = f"## {heading}\n{body.strip()}\n\n"
        if len(pack) + len(chunk) <= max_chars:
            pack += chunk
        else:
            remaining = max_chars - len(pack) - 20
            if remaining > 100:
                pack += chunk[:remaining] + "\n...(truncated)\n"
            break
    path.write_text(pack, encoding="utf-8")


def rebuild_context_packs(wiki_root: str, max_chars: int = 8000):
    root = Path(wiki_root)
    direction = build_project_direction(root)
    gaps = gather_gaps(root)
    principles = gather_principles(root)
    failed_ideas = gather_failed_ideas(root)
    invalidated_claims = gather_invalidated_claims(root)
    papers = gather_papers(root)
    analogies = gather_analogies(root, principles)
    relationships = gather_recent_relationships(root)

    principle_lines = [
        f"- **{item['title']}** [{item['node_id']}]: {item['distilled']} | preconditions: {item['preconditions']} | adaptation: {item['adaptation']}"
        for item in principles
    ]
    query_sections = [
        ("Project Direction", direction[:320]),
        ("Open Gaps", gaps[:1000]),
        ("Top Principles", "\n".join(principle_lines[:6])[:1800]),
        ("Failed Ideas", "\n".join(failed_ideas[:8])[:1400]),
        ("Key Papers", "\n".join(papers[:10])[:1600]),
        ("Recent Relationships", "\n".join(relationships)[:800]),
    ]
    principle_sections = [
        ("Transferable Principles", "\n".join(principle_lines[:12])[:3500]),
        ("Supporting Papers", "\n".join(papers[:10])[:1800]),
        ("Failure Signals To Respect", "\n".join((failed_ideas + invalidated_claims)[:10])[:1200]),
    ]
    analogy_sections = [
        ("Cross-Domain Candidates", "\n".join(analogies[:12])[:3200]),
        ("Related Principles", "\n".join(principle_lines[:8])[:1600]),
        ("Recent Relationships", "\n".join(relationships)[:1000]),
    ]
    failure_sections = [
        ("Failed Ideas", "\n".join(failed_ideas[:14])[:2600]),
        ("Invalidated or Narrowed Claims", "\n".join(invalidated_claims[:12])[:2200]),
        ("Do Not Repeat Blindly", "\n".join((failed_ideas + invalidated_claims)[:12])[:1400]),
    ]

    write_pack(root / "query_pack.md", "Research Wiki Query Pack", query_sections, max_chars)
    write_pack(root / "principle_pack.md", "Principle Pack", principle_sections, max_chars)
    write_pack(root / "analogy_pack.md", "Analogy Pack", analogy_sections, max_chars)
    write_pack(root / "failure_pack.md", "Failure Pack", failure_sections, max_chars)

    print(f"query_pack.md rebuilt: {len(read_text(root / 'query_pack.md'))} chars")
    print(f"principle_pack.md rebuilt: {len(read_text(root / 'principle_pack.md'))} chars")
    print(f"analogy_pack.md rebuilt: {len(read_text(root / 'analogy_pack.md'))} chars")
    print(f"failure_pack.md rebuilt: {len(read_text(root / 'failure_pack.md'))} chars")


def rebuild_query_pack(wiki_root: str, max_chars: int = 8000):
    rebuild_context_packs(wiki_root, max_chars)


def get_stats(wiki_root: str):
    root = Path(wiki_root)

    def count_files(subdir: str) -> int:
        directory = root / subdir
        return len(list(directory.glob("*.md"))) if directory.exists() else 0

    def count_by_field(subdir: str, field: str, value: str) -> int:
        directory = root / subdir
        if not directory.exists():
            return 0
        count = 0
        for page in directory.glob("*.md"):
            if f"{field}: {value}" in read_text(page):
                count += 1
        return count

    papers = count_files("papers")
    ideas = count_files("ideas")
    experiments = count_files("experiments")
    claims = count_files("claims")
    principles = count_files("principles")
    edges_path = root / "graph" / "edges.jsonl"
    edge_count = sum(1 for line in read_text(edges_path).strip().split("\n") if line.strip())

    print("📚 Research Wiki Stats")
    print(f"Papers:      {papers}")
    print(f"Ideas:       {ideas} ({count_by_field('ideas', 'outcome', 'negative')} failed, {count_by_field('ideas', 'outcome', 'positive')} succeeded)")
    print(f"Experiments: {experiments}")
    print(f"Claims:      {claims} ({count_by_field('claims', 'status', 'supported')} supported, {count_by_field('claims', 'status', 'invalidated')} invalidated)")
    print(f"Principles:  {principles}")
    print(f"Edges:       {edge_count}")


def main():
    parser = argparse.ArgumentParser(description="ARIS Research Wiki helper utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)

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

    p_rp = subparsers.add_parser("rebuild_packs")
    p_rp.add_argument("wiki_root")
    p_rp.add_argument("--max-chars", type=int, default=8000)

    p_stats = subparsers.add_parser("stats")
    p_stats.add_argument("wiki_root")

    p_log = subparsers.add_parser("log")
    p_log.add_argument("wiki_root")
    p_log.add_argument("message")

    args = parser.parse_args()
    if args.command == "init":
        init_wiki(args.wiki_root)
    elif args.command == "slug":
        print(slugify(args.title, args.author, args.year))
    elif args.command == "add_edge":
        add_edge(args.wiki_root, args.from_id, args.to_id, args.edge_type, args.evidence)
    elif args.command in {"rebuild_query_pack", "rebuild_packs"}:
        rebuild_context_packs(args.wiki_root, args.max_chars)
    elif args.command == "stats":
        get_stats(args.wiki_root)
    elif args.command == "log":
        append_log(args.wiki_root, args.message)
        print("Logged")


if __name__ == "__main__":
    main()
