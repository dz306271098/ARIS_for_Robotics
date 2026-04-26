#!/usr/bin/env python3
"""project_contract.py — Canonical helper for ARIS build-system contract.

Parses `.aris/project.yaml`, auto-detects language/frameworks when absent,
and exposes CLI subcommands that caller skills invoke to get language-specific
build/run/bench/install commands.

Exit codes:
  0  success
  1  schema validation failed
  2  CLI usage error
  3  dependency missing (e.g. PyYAML on a system without it)
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


SCHEMA_VERSION = 1

VALID_LANGUAGES = {"python", "cpp", "rust", "polyglot"}
VALID_VENUE_FAMILIES = {
    "theory", "pl", "systems", "db", "graphics",
    "hpc", "robotics", "gpu", "ml",
}
VALID_FRAMEWORKS = {"ros2", "cuda", "cudnn", "tensorrt", "torch", "jax"}
VALID_BUILD_SYSTEMS = {"make", "cmake", "cargo", "colcon", "custom", "pip", "none"}
VALID_BENCH_HARNESSES = {
    "google-benchmark", "catch2", "rosbag-replay",
    "cuda-eventtimer", "pytest-benchmark", "custom",
}
VALID_CPU_SANITIZERS = {"address", "undefined", "thread", "memory", "leak"}
VALID_GPU_SANITIZERS = {"memcheck", "racecheck", "synccheck", "initcheck"}
VALID_CPU_PROFILERS = {"perf", "valgrind", "instruments", "cprofile"}
VALID_GPU_PROFILERS = {"nsight-compute", "nsight-systems", "nvprof"}


# ---------- YAML loading (try PyYAML; fallback to minimal parser) ----------

def _load_yaml(path: Path) -> Dict[str, Any]:
    """Load YAML with PyYAML if available; fallback to a minimal parser.

    The minimal parser handles the exact subset we author: 2-space indent,
    scalar/list/mapping values, '#' comments. It errors on anything fancier
    and suggests installing PyYAML.
    """
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text) or {}
    except ImportError:
        pass
    return _parse_minimal_yaml(text, path)


def _parse_minimal_yaml(text: str, path: Path) -> Dict[str, Any]:
    """Handle the narrow YAML subset used in ARIS project/container contracts."""
    def parse_value(raw: str) -> Any:
        raw = raw.strip()
        if not raw:
            return None
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[1:-1].strip()
            if not inner:
                return []
            return [parse_value(x.strip()) for x in _split_top_level(inner, ",")]
        if raw.startswith('"') and raw.endswith('"'):
            return raw[1:-1]
        if raw.startswith("'") and raw.endswith("'"):
            return raw[1:-1]
        if raw.lower() in ("true", "false"):
            return raw.lower() == "true"
        if raw.lower() in ("null", "~"):
            return None
        try:
            return int(raw)
        except ValueError:
            pass
        try:
            return float(raw)
        except ValueError:
            pass
        return raw

    def _split_top_level(s: str, sep: str) -> List[str]:
        depth = 0
        cur = []
        out = []
        for ch in s:
            if ch in "[{(":
                depth += 1
            elif ch in "]})":
                depth -= 1
            if ch == sep and depth == 0:
                out.append("".join(cur))
                cur = []
            else:
                cur.append(ch)
        if cur:
            out.append("".join(cur))
        return out

    lines = []
    for raw in text.splitlines():
        # Strip trailing comments (but not inside quotes — our subset doesn't
        # have quoted '#', so a plain strip is safe).
        stripped = raw.rstrip()
        if "#" in stripped:
            in_q = False
            q = None
            out = []
            for ch in stripped:
                if ch in ('"', "'"):
                    if not in_q:
                        in_q = True
                        q = ch
                    elif q == ch:
                        in_q = False
                        q = None
                if ch == "#" and not in_q:
                    break
                out.append(ch)
            stripped = "".join(out).rstrip()
        if stripped:
            lines.append(stripped)

    def indent_of(s: str) -> int:
        return len(s) - len(s.lstrip())

    root: Dict[str, Any] = {}
    stack: List[Tuple[int, Any]] = [(-1, root)]

    i = 0
    while i < len(lines):
        line = lines[i]
        ind = indent_of(line)
        content = line.strip()
        while stack and stack[-1][0] >= ind:
            stack.pop()
        parent = stack[-1][1]
        if content.startswith("- "):
            item = content[2:].strip()
            if isinstance(parent, list):
                if ":" in item and not (item.startswith('"') or item.startswith("'")):
                    # mapping item — not used in our schema; error
                    raise ValueError(
                        f"{path}: mapping inside list at line {i+1} not supported by minimal parser; install PyYAML"
                    )
                parent.append(parse_value(item))
            else:
                raise ValueError(f"{path}: list item with non-list parent at line {i+1}")
            i += 1
            continue
        if ":" in content:
            key, _, val = content.partition(":")
            key = key.strip()
            val = val.strip()
            if val == "":
                # next lines are a nested mapping or list
                # peek next non-empty line to decide
                j = i + 1
                nested: Any = {}
                if j < len(lines):
                    nxt = lines[j]
                    if nxt.strip().startswith("- ") and indent_of(nxt) > ind:
                        nested = []
                if isinstance(parent, dict):
                    parent[key] = nested
                else:
                    raise ValueError(f"{path}: unexpected key at line {i+1}")
                stack.append((ind, nested))
                i += 1
                continue
            if isinstance(parent, dict):
                parent[key] = parse_value(val)
            else:
                raise ValueError(f"{path}: unexpected key at line {i+1}")
            i += 1
            continue
        raise ValueError(f"{path}: cannot parse line {i+1}: {content!r}")

    return root


# ---------- Auto-detection ----------

def detect(root: Path) -> Dict[str, Any]:
    """Infer language + frameworks from filesystem signals."""
    has_cmakelists = (root / "CMakeLists.txt").is_file()
    has_makefile = (root / "Makefile").is_file()
    has_package_xml = (root / "package.xml").is_file() or any(root.glob("**/package.xml"))
    has_cargo = (root / "Cargo.toml").is_file()
    has_pyproject = (root / "pyproject.toml").is_file()
    has_requirements = (root / "requirements.txt").is_file()
    cu_files = list(root.glob("**/*.cu")) + list(root.glob("**/*.cuh"))
    has_cu = bool(cu_files)

    frameworks: List[str] = []
    if has_package_xml:
        language = "cpp"
        frameworks.append("ros2")
        venue_family = "robotics"
    elif has_cu:
        language = "cpp"
        frameworks.append("cuda")
        venue_family = "gpu"
    elif has_cmakelists or has_makefile:
        language = "cpp"
        venue_family = "systems"
    elif has_cargo:
        language = "rust"
        venue_family = "systems"
    elif has_pyproject or has_requirements:
        language = "python"
        venue_family = "ml"
    else:
        language = "python"
        venue_family = "ml"

    # Build system
    if has_package_xml:
        build_system = "colcon"
    elif has_cmakelists:
        build_system = "cmake"
    elif has_makefile:
        build_system = "make"
    elif has_cargo:
        build_system = "cargo"
    else:
        build_system = "pip" if language == "python" else "none"

    return {
        "language": language,
        "venue_family": venue_family,
        "frameworks": frameworks,
        "build": {"system": build_system},
        "_detected": True,
    }


def load(root: Path) -> Dict[str, Any]:
    """Load contract with priority: CLAUDE.md → .aris/project.yaml → auto-detect.

    The CLAUDE.md form mirrors the existing `## Remote Server` / `## Vast.ai`
    convention so users author project config in the same place. Sections
    matched (case-insensitive, parens/extras stripped):
      - "Project" / "C++ Project" / "Cpp Project" / "CUDA Project" / "ROS2 Workspace"
        → merged into the project contract dict
      - "Container" → produces a `_container` sub-dict on the same return value
    """
    cfg_md = _load_claude_md(root)
    md_has_project = cfg_md and any(k in cfg_md for k in ("language", "frameworks", "build"))
    md_container = (cfg_md or {}).get("_container") if cfg_md else None

    if md_has_project:
        cfg_md.setdefault("_detected", False)
        cfg_md.setdefault("_source", "CLAUDE.md")
        return cfg_md

    contract = root / ".aris" / "project.yaml"
    if contract.is_file():
        cfg = _load_yaml(contract)
        cfg.setdefault("_detected", False)
        cfg.setdefault("_source", str(contract))
        if md_container and "_container" not in cfg:
            cfg["_container"] = md_container
        return cfg

    cfg = detect(root)
    cfg["_source"] = "auto-detect"
    if md_container:
        cfg["_container"] = md_container
    return cfg


def _load_claude_md(root: Path) -> Dict[str, Any]:
    """Parse project + container config from CLAUDE.md sections.

    Recognised section headers (matched case-insensitively, after stripping
    parenthesised suffixes):
      - "Project" | "C++ Project" | "Cpp Project" | "CUDA Project" | "ROS2 Workspace"
      - "Container"

    Within each section, parses lines like `- key: value` or `- key:`+nested
    `  - item` bullets. Comma-separated values become lists. Numeric / bool /
    null literals are coerced. Returns {} if no recognised sections present.
    """
    path = root / "CLAUDE.md"
    if not path.is_file():
        return {}

    text = path.read_text(encoding="utf-8", errors="replace")

    project_aliases = {"project", "c++ project", "cpp project", "cuda project",
                       "ros2 workspace", "ros2 project", "build"}
    container_aliases = {"container"}

    sections: Dict[str, List[str]] = {}
    cur_name: Optional[str] = None
    cur_lines: List[str] = []

    def normalize_header(h: str) -> str:
        # strip "## ", trim, drop parenthesised suffix, lowercase
        h = h[2:].strip()
        if "(" in h:
            h = h[:h.index("(")].strip()
        return h.lower()

    for raw in text.splitlines():
        if raw.startswith("## "):
            if cur_name is not None:
                sections.setdefault(cur_name, []).extend(cur_lines)
            name = normalize_header(raw)
            if name in project_aliases or name in container_aliases:
                cur_name = "container" if name in container_aliases else "project"
                cur_lines = []
            else:
                cur_name = None
                cur_lines = []
        elif cur_name is not None:
            cur_lines.append(raw)

    if cur_name is not None:
        sections.setdefault(cur_name, []).extend(cur_lines)

    if not sections:
        return {}

    project_cfg = _parse_md_section(sections.get("project", []))
    container_cfg = _parse_md_section(sections.get("container", []))

    # Re-shape flat keys to the structured form the rest of the helper expects.
    cfg: Dict[str, Any] = {}
    for k in ("language", "venue_family", "frameworks", "metrics", "assurance"):
        if k in project_cfg:
            cfg[k] = project_cfg[k]

    build: Dict[str, Any] = {}
    for src, dst in [("build_system", "system"), ("build_cmd", "cmd"),
                     ("build_flags", "flags"), ("cuda_arch", "cuda_arch"),
                     ("ros2_distro", "ros2_distro")]:
        if src in project_cfg:
            build[dst] = project_cfg[src]
    if "build" in project_cfg and isinstance(project_cfg["build"], dict):
        build.update(project_cfg["build"])
    if build:
        cfg["build"] = build

    bench: Dict[str, Any] = {}
    for src, dst in [("bench_harness", "harness"), ("bench_cmd", "cmd"),
                     ("bench_iterations", "iterations")]:
        if src in project_cfg:
            bench[dst] = project_cfg[src]
    if bench:
        cfg["bench"] = bench

    sanitizers: Dict[str, Any] = {}
    if "sanitizers_cpu" in project_cfg:
        sanitizers["cpu"] = _to_list(project_cfg["sanitizers_cpu"])
    if "sanitizers_gpu" in project_cfg:
        sanitizers["gpu"] = _to_list(project_cfg["sanitizers_gpu"])
    if sanitizers:
        cfg["sanitizers"] = sanitizers

    profile: Dict[str, Any] = {}
    if "profile_cpu_tool" in project_cfg:
        profile["cpu_tool"] = project_cfg["profile_cpu_tool"]
    if "profile_gpu_tool" in project_cfg:
        profile["gpu_tool"] = project_cfg["profile_gpu_tool"]
    if profile:
        cfg["profile"] = profile

    if "frameworks" in cfg and not isinstance(cfg["frameworks"], list):
        cfg["frameworks"] = _to_list(cfg["frameworks"])

    if container_cfg:
        cfg["_container"] = container_cfg

    return cfg


def _to_list(v: Any) -> List[str]:
    if isinstance(v, list):
        return v
    if isinstance(v, str):
        return [x.strip() for x in v.split(",") if x.strip()]
    return [v] if v else []


def _parse_md_section(lines: List[str]) -> Dict[str, Any]:
    """Parse `- key: value` and nested `  - item` bullets into a dict.

    Tolerant of backticks (stripped), single quotes around values, and
    comma-separated lists. Numeric / bool literals coerced.
    """
    out: Dict[str, Any] = {}
    i = 0
    n = len(lines)

    def coerce(s: str) -> Any:
        s = s.strip()
        if s.startswith("`") and s.endswith("`"):
            s = s[1:-1]
        if s.startswith('"') and s.endswith('"'):
            return s[1:-1]
        if s.startswith("'") and s.endswith("'"):
            return s[1:-1]
        if s.lower() in ("true", "false"):
            return s.lower() == "true"
        if s.lower() in ("null", "none", "~", ""):
            return None
        try:
            return int(s)
        except ValueError:
            pass
        try:
            return float(s)
        except ValueError:
            pass
        if "," in s and not s.startswith("[") and not s.startswith("{"):
            return [x.strip() for x in s.split(",") if x.strip()]
        return s

    while i < n:
        line = lines[i].rstrip()
        stripped = line.lstrip()
        if not stripped.startswith("- "):
            i += 1
            continue
        body = stripped[2:].strip()
        if ":" not in body:
            i += 1
            continue
        key, _, val = body.partition(":")
        key = key.strip().replace(" ", "_").replace("-", "_")
        val = val.strip()
        if val:
            v = coerce(val)
            if key in out:
                # Repeated key → accumulate into list (e.g. multi `- pre_exec:` lines)
                if isinstance(out[key], list):
                    out[key].append(v)
                else:
                    out[key] = [out[key], v]
            else:
                out[key] = v
            i += 1
            continue
        # value-less key — collect indented sub-bullets as a list
        items: List[Any] = []
        i += 1
        while i < n:
            sub = lines[i].rstrip()
            sub_stripped = sub.lstrip()
            if not sub_stripped:
                i += 1
                continue
            if sub.startswith("  ") and sub_stripped.startswith("- "):
                items.append(coerce(sub_stripped[2:].strip()))
                i += 1
                continue
            break
        out[key] = items
    return out


# ---------- Validation ----------

def validate(cfg: Dict[str, Any]) -> List[str]:
    errors: List[str] = []
    lang = cfg.get("language")
    if lang and lang not in VALID_LANGUAGES:
        errors.append(f"language={lang!r} not in {sorted(VALID_LANGUAGES)}")
    vf = cfg.get("venue_family")
    if vf and vf not in VALID_VENUE_FAMILIES:
        errors.append(f"venue_family={vf!r} not in {sorted(VALID_VENUE_FAMILIES)}")
    fws = cfg.get("frameworks", []) or []
    if not isinstance(fws, list):
        errors.append("frameworks must be a list")
    else:
        for f in fws:
            if f not in VALID_FRAMEWORKS:
                errors.append(f"framework={f!r} not in {sorted(VALID_FRAMEWORKS)}")

    build = cfg.get("build") or {}
    if not isinstance(build, dict):
        errors.append("build must be a mapping")
    else:
        bs = build.get("system")
        if bs and bs not in VALID_BUILD_SYSTEMS:
            errors.append(f"build.system={bs!r} not in {sorted(VALID_BUILD_SYSTEMS)}")
        if "cuda" in fws and not build.get("cuda_arch"):
            errors.append("cuda in frameworks requires build.cuda_arch (e.g. sm_86)")
        if "ros2" in fws and not build.get("ros2_distro"):
            errors.append("ros2 in frameworks requires build.ros2_distro (e.g. jazzy)")

    bench = cfg.get("bench") or {}
    if bench:
        h = bench.get("harness")
        if h and h not in VALID_BENCH_HARNESSES:
            errors.append(f"bench.harness={h!r} not in {sorted(VALID_BENCH_HARNESSES)}")

    san = cfg.get("sanitizers") or {}
    if san:
        cpu = san.get("cpu", []) or []
        for s in cpu:
            if s not in VALID_CPU_SANITIZERS:
                errors.append(f"sanitizers.cpu[{s!r}] not in {sorted(VALID_CPU_SANITIZERS)}")
        gpu = san.get("gpu", []) or []
        for s in gpu:
            if s not in VALID_GPU_SANITIZERS:
                errors.append(f"sanitizers.gpu[{s!r}] not in {sorted(VALID_GPU_SANITIZERS)}")

    prof = cfg.get("profile") or {}
    if prof:
        cpu_tool = prof.get("cpu_tool")
        if cpu_tool and cpu_tool not in VALID_CPU_PROFILERS:
            errors.append(f"profile.cpu_tool={cpu_tool!r} not in {sorted(VALID_CPU_PROFILERS)}")
        gpu_tool = prof.get("gpu_tool")
        if gpu_tool and gpu_tool not in VALID_GPU_PROFILERS:
            errors.append(f"profile.gpu_tool={gpu_tool!r} not in {sorted(VALID_GPU_PROFILERS)}")

    return errors


# ---------- Command resolution ----------

def get_build_cmd(cfg: Dict[str, Any]) -> str:
    build = cfg.get("build") or {}
    if "cmd" in build and build["cmd"]:
        return build["cmd"]
    bs = build.get("system")
    lang = cfg.get("language", "python")
    if bs == "cmake":
        return "cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"
    if bs == "make":
        return "make -j"
    if bs == "cargo":
        return "cargo build --release"
    if bs == "colcon":
        return "colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release"
    if bs == "pip" or lang == "python":
        return ":"  # no-op for Python
    return ":"


def get_run_cmd(cfg: Dict[str, Any]) -> str:
    run = cfg.get("run") or {}
    if "cmd" in run and run["cmd"]:
        return run["cmd"]
    lang = cfg.get("language", "python")
    if lang == "python":
        return "python main.py"
    if lang == "cpp":
        return "./build/app"
    if lang == "rust":
        return "./target/release/app"
    return ":"


def get_bench_cmd(cfg: Dict[str, Any]) -> str:
    bench = cfg.get("bench") or {}
    if "cmd" in bench and bench["cmd"]:
        return bench["cmd"]
    h = bench.get("harness")
    if h == "google-benchmark":
        return "./build/bench --benchmark_format=json --benchmark_out=BENCHMARK_RESULT.json"
    if h == "catch2":
        return "./build/bench --reporter=json::out=BENCHMARK_RESULT.json"
    if h == "pytest-benchmark":
        return "pytest --benchmark-only --benchmark-json=BENCHMARK_RESULT.json"
    return get_run_cmd(cfg)


def get_install_cmd(cfg: Dict[str, Any]) -> str:
    lang = cfg.get("language", "python")
    build = cfg.get("build") or {}
    bs = build.get("system")
    if bs == "pip" or lang == "python":
        if (Path.cwd() / "requirements.txt").is_file():
            return "pip install -r requirements.txt"
        if (Path.cwd() / "pyproject.toml").is_file():
            return "pip install -e ."
        return ":"
    if bs == "cmake":
        return "cmake -S . -B build -DCMAKE_BUILD_TYPE=Release"
    if bs == "colcon":
        return "rosdep install --from-paths src --ignore-src -r -y"
    if bs == "cargo":
        return "cargo fetch"
    return ":"


def get_metrics(cfg: Dict[str, Any]) -> List[str]:
    metrics = cfg.get("metrics") or {}
    lang = cfg.get("language", "python")
    fws = cfg.get("frameworks", []) or []
    out: List[str] = []
    if "ros2" in fws and "ros2" in metrics:
        out += metrics["ros2"]
    if "cuda" in fws and "cuda" in metrics:
        out += metrics["cuda"]
    if lang == "cpp" and "cpp" in metrics:
        out += metrics["cpp"]
    if not out:
        # Defaults per language
        if lang == "python":
            out = ["loss", "eval_accuracy", "runtime_s"]
        elif lang == "cpp":
            out = ["wall_time_ms", "peak_rss_kb"]
        elif "ros2" in fws:
            out = ["control_loop_freq_hz", "topic_latency_p99_ms"]
        elif "cuda" in fws:
            out = ["kernel_time_us", "occupancy_pct"]
    return out


# ---------- Init (scaffold) ----------

def init(root: Path, language: Optional[str] = None,
         frameworks: Optional[List[str]] = None,
         overwrite: bool = False,
         target_format: str = "yaml") -> Path:
    """Scaffold project contract.

    target_format:
      "yaml"     -> .aris/project.yaml (programmatic / advanced)
      "claude-md" -> append ## Project + ## Container sections to CLAUDE.md (default UX)
    """
    if target_format == "claude-md":
        return _init_claude_md(root, language=language, frameworks=frameworks, overwrite=overwrite)
    target = root / ".aris" / "project.yaml"
    if target.exists() and not overwrite:
        raise FileExistsError(f"{target} already exists; pass --overwrite to replace")
    target.parent.mkdir(parents=True, exist_ok=True)
    detected = detect(root)
    language = language or detected.get("language", "python")
    frameworks = frameworks if frameworks is not None else detected.get("frameworks", [])
    venue_family = detected.get("venue_family", "ml")
    bs = (detected.get("build") or {}).get("system", "none")

    lines = [
        f"# ARIS project contract — auto-generated by project_contract.py init",
        f"# Edit to match your project; re-run `project_contract.py validate` to check.",
        f"",
        f"language: {language}",
        f"venue_family: {venue_family}",
    ]
    if frameworks:
        fws_str = "[" + ", ".join(frameworks) + "]"
        lines.append(f"frameworks: {fws_str}")
    lines.append("")
    lines.append("build:")
    lines.append(f"  system: {bs}")
    if "cuda" in (frameworks or []):
        lines.append("  cuda_arch: sm_86")
    if "ros2" in (frameworks or []):
        lines.append("  ros2_distro: jazzy")
    if bs == "cmake":
        lines.append('  flags: ["-O3", "-DNDEBUG"]')
    lines.append("")

    if language == "cpp":
        lines += [
            "sanitizers:",
            "  cpu: [address, undefined]",
        ]
        if "cuda" in (frameworks or []):
            lines.append("  gpu: [memcheck, racecheck]")
        lines.append("")
        lines += [
            "profile:",
            "  cpu_tool: perf",
        ]
        if "cuda" in (frameworks or []):
            lines.append("  gpu_tool: nsight-compute")
        lines.append("")

    lines += [
        "metrics:",
    ]
    if language == "cpp":
        lines.append("  cpp: [wall_time_ms, peak_rss_kb, cache_misses, throughput_ops_sec]")
    if "ros2" in (frameworks or []):
        lines.append("  ros2: [control_loop_freq_hz, topic_latency_p99_ms, node_uptime_s]")
    if "cuda" in (frameworks or []):
        lines.append("  cuda: [kernel_time_us, occupancy_pct, warp_execution_efficiency]")
    if language == "python":
        lines.append("  python: [loss, eval_accuracy, runtime_s]")

    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def _init_claude_md(root: Path, language: Optional[str], frameworks: Optional[List[str]],
                    overwrite: bool) -> Path:
    """Append a `## Project` (+ optional `## Container`) section to CLAUDE.md.

    If CLAUDE.md exists and already has a `## Project` section, --overwrite is
    required (we won't silently mangle existing config).
    """
    target = root / "CLAUDE.md"
    detected = detect(root)
    language = language or detected.get("language", "python")
    frameworks = frameworks if frameworks is not None else detected.get("frameworks", [])
    venue_family = detected.get("venue_family", "ml")
    bs = (detected.get("build") or {}).get("system", "none")

    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    has_project_section = any(
        line.strip().lower().rstrip("()").startswith("## project")
        or line.strip().lower().startswith("## c++ project")
        or line.strip().lower().startswith("## cpp project")
        for line in existing.splitlines()
    )
    if has_project_section and not overwrite:
        raise FileExistsError(
            f"{target} already has a Project section; pass --overwrite to add another"
        )

    block = ["", "## Project", f"- language: {language}", f"- venue_family: {venue_family}"]
    if frameworks:
        block.append(f"- frameworks: {', '.join(frameworks)}")
    block.append(f"- build_system: {bs}")
    if "cuda" in (frameworks or []):
        block.append("- cuda_arch: sm_86         # set to your GPU arch (sm_75/sm_80/sm_86/sm_89/sm_90)")
    if "ros2" in (frameworks or []):
        block.append("- ros2_distro: jazzy       # or humble / iron / rolling")
    if language == "cpp":
        block.append("- bench_harness: google-benchmark")
        block.append("- bench_iterations: 10")
        block.append("- sanitizers_cpu: address, undefined")
        if "cuda" in (frameworks or []):
            block.append("- sanitizers_gpu: memcheck, racecheck")
        block.append("- profile_cpu_tool: perf")
        if "cuda" in (frameworks or []):
            block.append("- profile_gpu_tool: nsight-compute")
    block.append("")

    if frameworks and any(f in frameworks for f in ("ros2", "cuda")):
        block += [
            "## Container",
            "- runtime: docker        # or podman / distrobox / toolbox / auto",
            "- name: my-cpp-dev       # your container name (ARIS does not ship one)",
            "- workdir: /workspace",
        ]
        pre = []
        if "ros2" in frameworks:
            pre.append("- pre_exec: source /opt/ros/jazzy/setup.bash")
        if "cuda" in frameworks:
            pre.append("- pre_exec: export PATH=/usr/local/cuda/bin:$PATH")
        block += pre
        block.append("")

    new_content = existing.rstrip() + "\n" + "\n".join(block) if existing else "\n".join(block).lstrip()
    target.write_text(new_content + "\n", encoding="utf-8")
    return target


def load_container(root: Path) -> Dict[str, Any]:
    """Return container config from CLAUDE.md `## Container` or .aris/container.yaml."""
    cfg = load(root)
    if cfg.get("_container"):
        return cfg["_container"]
    yaml_path = root / ".aris" / "container.yaml"
    if yaml_path.is_file():
        return _load_yaml(yaml_path)
    return {}


# ---------- CLI ----------

def _cli() -> int:
    p = argparse.ArgumentParser(description="ARIS build-system contract helper")
    p.add_argument("--root", default=".", help="Project root (default: cwd)")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("validate", help="Validate .aris/project.yaml (or detection result)")
    sub.add_parser("get-language")
    sub.add_parser("get-venue-family")
    sub.add_parser("get-frameworks")
    sub.add_parser("get-build-cmd")
    sub.add_parser("get-run-cmd")
    sub.add_parser("get-bench-cmd")
    sub.add_parser("get-install-cmd")
    sub.add_parser("get-metrics")

    sub.add_parser("show", help="Dump the effective contract as JSON")
    sub.add_parser("install-deps", help="Print the install command; does NOT execute")
    sub.add_parser("get-container", help="Dump container config (CLAUDE.md or .aris/container.yaml) as JSON")
    sub.add_parser("source", help="Print where the contract was loaded from (CLAUDE.md / yaml / auto-detect)")

    sp_init = sub.add_parser("init", help="Scaffold project contract")
    sp_init.add_argument("--language", choices=sorted(VALID_LANGUAGES))
    sp_init.add_argument("--frameworks", default="", help="Comma-separated framework list")
    sp_init.add_argument("--overwrite", action="store_true")
    sp_init.add_argument("--target", choices=["yaml", "claude-md"], default="claude-md",
                        help="Where to write: claude-md (default, user-friendly) or yaml (programmatic)")

    args = p.parse_args()
    root = Path(args.root).resolve()

    if args.cmd == "init":
        fws = [f.strip() for f in args.frameworks.split(",") if f.strip()] if args.frameworks else None
        try:
            out = init(root, language=args.language, frameworks=fws,
                       overwrite=args.overwrite, target_format=args.target)
        except FileExistsError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return 2
        print(f"wrote {out}")
        return 0

    cfg = load(root)

    if args.cmd == "validate":
        errs = validate(cfg)
        if errs:
            for e in errs:
                print(f"ERROR: {e}", file=sys.stderr)
            return 1
        if cfg.get("_detected"):
            print("OK (detected; no .aris/project.yaml present — consider `init` to persist)")
        else:
            print("OK")
        return 0

    if args.cmd == "get-language":
        print(cfg.get("language", "python"))
        return 0
    if args.cmd == "get-venue-family":
        print(cfg.get("venue_family", "ml"))
        return 0
    if args.cmd == "get-frameworks":
        print(" ".join(cfg.get("frameworks", []) or []))
        return 0
    if args.cmd == "get-build-cmd":
        print(get_build_cmd(cfg))
        return 0
    if args.cmd == "get-run-cmd":
        print(get_run_cmd(cfg))
        return 0
    if args.cmd == "get-bench-cmd":
        print(get_bench_cmd(cfg))
        return 0
    if args.cmd == "get-install-cmd" or args.cmd == "install-deps":
        print(get_install_cmd(cfg))
        return 0
    if args.cmd == "get-metrics":
        print(" ".join(get_metrics(cfg)))
        return 0
    if args.cmd == "show":
        cfg_out = {k: v for k, v in cfg.items() if not k.startswith("_")}
        cfg_out["_detected"] = cfg.get("_detected", False)
        cfg_out["_source"] = cfg.get("_source", "auto-detect")
        print(json.dumps(cfg_out, indent=2))
        return 0
    if args.cmd == "get-container":
        ctr = load_container(root)
        print(json.dumps(ctr, indent=2))
        return 0
    if args.cmd == "source":
        print(cfg.get("_source", "auto-detect"))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(_cli())
