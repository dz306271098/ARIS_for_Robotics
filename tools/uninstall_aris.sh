#!/usr/bin/env bash
# uninstall_aris.sh — Safe wrapper for ARIS skill uninstallation.
#
# Removes every symlink this installer created (per the manifest at
# <install-root>/.aris/installed-skills.txt). Does NOT touch user-owned
# skills, copies, or files — only the symlinks this installer wrote.
#
# Usage:
#   bash tools/uninstall_aris.sh                        # uninstall global (~/.claude/skills/)
#   bash tools/uninstall_aris.sh --project              # uninstall project-local (cwd)
#   bash tools/uninstall_aris.sh --project /path        # uninstall project-local (explicit)
#   bash tools/uninstall_aris.sh --dry-run              # preview what would be removed
#   bash tools/uninstall_aris.sh --quiet                # no prompts; skip on conditions needing prompts
#
# Modes:
#   --global (default)     uninstall from ~/.claude/skills/
#   --project [PATH]       uninstall from <PATH>/.claude/skills/
#   --archive-copy         if ~/.claude/skills/ contains REAL directories
#                          (not symlinks) that match ARIS skill names, archive
#                          them to ~/.claude/skills.aris-backup-<ts>/ before
#                          exiting. Useful if the user previously installed
#                          via `cp -r` and wants to clean up before reinstalling
#                          via install_aris.sh.
#
# This wrapper is a thin layer on top of `install_aris.sh --uninstall` with two
# additions:
#   1. Explicit pre-flight summary before the uninstall prompt
#   2. --archive-copy helper for users migrating away from `cp -r` installs
#
# All safety rules from install_aris.sh apply (S1, S2, S8, S11).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_aris.sh"
ARIS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -x "$INSTALL_SCRIPT" ]] || { echo "error: $INSTALL_SCRIPT not executable" >&2; exit 1; }

# ─── Args ────────────────────────────────────────────────────────────────────
MODE="global"
PROJECT_PATH=""
DRY_RUN=false
QUIET=false
ARCHIVE_COPY=false

usage() { sed -n '2,30p' "$0" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)        MODE="global"; shift ;;
        --project)
            MODE="project"
            if [[ $# -ge 2 && -n "$2" && "$2" != --* ]]; then
                PROJECT_PATH="$2"; shift 2
            else
                shift
            fi ;;
        --dry-run)       DRY_RUN=true; shift ;;
        --quiet)         QUIET=true; shift ;;
        --archive-copy)  ARCHIVE_COPY=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# ─── Resolve install root ────────────────────────────────────────────────────
case "$MODE" in
    global)
        INSTALL_ROOT="${CLAUDE_HOME:-$HOME/.claude}"
        SKILLS_DIR="$INSTALL_ROOT/skills" ;;
    project)
        INSTALL_ROOT="${PROJECT_PATH:-$(pwd)}"
        [[ -d "$INSTALL_ROOT" ]] || { echo "error: project path does not exist: $INSTALL_ROOT" >&2; exit 1; }
        INSTALL_ROOT="$(cd "$INSTALL_ROOT" && pwd)"
        SKILLS_DIR="$INSTALL_ROOT/.claude/skills" ;;
esac

MANIFEST="$INSTALL_ROOT/.aris/installed-skills.txt"

# ─── Pre-flight summary ──────────────────────────────────────────────────────
echo ""
echo "ARIS Uninstall"
echo "  Mode:         $MODE"
echo "  Install root: $INSTALL_ROOT"
echo "  Skills dir:   $SKILLS_DIR"
echo "  Manifest:     $MANIFEST"
echo ""

# Count symlinks vs real dirs
N_SYMLINK=0
N_REAL_DIR=0
N_TOTAL=0
if [[ -d "$SKILLS_DIR" ]]; then
    for d in "$SKILLS_DIR"/*; do
        [[ -e "$d" || -L "$d" ]] || continue
        N_TOTAL=$((N_TOTAL + 1))
        if [[ -L "$d" ]]; then
            N_SYMLINK=$((N_SYMLINK + 1))
        elif [[ -d "$d" ]]; then
            N_REAL_DIR=$((N_REAL_DIR + 1))
        fi
    done
fi

echo "  Entries in skills/: $N_TOTAL total ($N_SYMLINK symlinks, $N_REAL_DIR real directories)"
echo ""

# ─── Archive copy mode ──────────────────────────────────────────────────────
if $ARCHIVE_COPY; then
    if (( N_REAL_DIR == 0 )); then
        echo "→ --archive-copy: no real directories to archive in $SKILLS_DIR"
        exit 0
    fi
    TS="$(date -u +%Y%m%dT%H%M%SZ)"
    ARCHIVE="${SKILLS_DIR}.aris-backup-${TS}"
    echo "  Archive $N_REAL_DIR real directories from:"
    echo "    $SKILLS_DIR"
    echo "  to:"
    echo "    $ARCHIVE"
    echo ""
    if ! $QUIET; then
        printf "Proceed? [y/N] "
        read -r REPLY
        [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "aborted"; exit 0; }
    fi
    if $DRY_RUN; then
        echo "(dry-run) would mkdir $ARCHIVE and mv real dirs in"
    else
        mkdir -p "$ARCHIVE"
        for d in "$SKILLS_DIR"/*; do
            [[ -d "$d" && ! -L "$d" ]] || continue
            name="$(basename "$d")"
            # Skip ARIS install-root bookkeeping
            [[ "$name" == ".aris" ]] && continue
            mv -- "$d" "$ARCHIVE/$name"
            echo "  → archived: $name"
        done
        echo ""
        echo "✓ Archived $N_REAL_DIR directories."
        echo "  You can now run:"
        echo "    bash $ARIS_REPO/tools/install_aris.sh"
        echo "  to install ARIS skills as managed symlinks."
        echo "  The archive ($ARCHIVE) is preserved and can be removed manually once verified."
    fi
    exit 0
fi

# ─── Regular uninstall via install_aris.sh --uninstall ───────────────────────
if [[ ! -f "$MANIFEST" ]]; then
    echo "error: no ARIS manifest at $MANIFEST"
    echo "       nothing to uninstall (or this install was not managed by install_aris.sh)"
    echo ""
    if (( N_REAL_DIR > 0 )); then
        echo "  Note: $N_REAL_DIR real directories found under $SKILLS_DIR."
        echo '  These appear to be a "cp -r" install (not managed by install_aris.sh).'
        ARGS_HINT="--$MODE"
        [[ "$MODE" == "project" && -n "$PROJECT_PATH" ]] && ARGS_HINT="$ARGS_HINT $PROJECT_PATH"
        echo "  To archive them: bash tools/uninstall_aris.sh $ARGS_HINT --archive-copy"
    fi
    exit 1
fi

# Show what will be removed
echo "This will remove the $N_SYMLINK ARIS-managed symlinks listed in the manifest."
echo "Real directories (if any) will NOT be touched."
echo ""

ARGS=("--uninstall")
case "$MODE" in
    global)  ARGS+=("--global") ;;
    project)
        ARGS+=("--project")
        [[ -n "$PROJECT_PATH" ]] && ARGS+=("$PROJECT_PATH") ;;
esac
$DRY_RUN && ARGS+=("--dry-run")
$QUIET   && ARGS+=("--quiet")

exec bash "$INSTALL_SCRIPT" "${ARGS[@]}"
