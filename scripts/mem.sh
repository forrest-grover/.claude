#!/usr/bin/env bash
# Multi-memory-system manager for the active project (resolved from $PWD).
#
# Layout:
#   ~/.claude/projects/<encoded-cwd>/active                 (file, name of active system)
#   ~/.claude/projects/<encoded-cwd>/memory -> systems/<active>/   (dir symlink, harness reads here)
#   ~/.claude/projects/<encoded-cwd>/systems/<name>/MEMORY.md
#   ~/.claude/projects/<encoded-cwd>/systems/<name>/<entries>.md
#
# Subcommands: list (default), use, new, rm, show, diff, add
#
# Concurrency note: switching the active system takes effect at NEXT session
# start (the harness loads memory once at startup via readdir on the symlink
# target). `ln -sfn` performs an atomic rename(2) so swap is safe.
#
# Idempotent: every operation is safe to re-run.

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
PROJECTS_DIR="$CLAUDE_HOME/projects"

usage() {
  cat <<'EOF'
Usage: mem [subcommand] [args]

  list                  list available systems and active (default)
  use <name>            switch active system (atomic; effect on next session)
  new <name>            create new empty system
  rm <name> [--force]   remove system (refuses active; needs --force)
  show <name>           print MEMORY.md of a system
  diff <a> <b>          diff two systems' MEMORY.md
  add <type> <slug> [-d "description"]
                        create new entry in active system with seeded frontmatter
                        and index line. type: user|feedback|project|reference
EOF
}

# Encode $PWD to <encoded-cwd>: replace every '/' with '-'.
# Note: harness convention preserves the leading slash conversion, yielding
# a leading dash (e.g. /path/to/workspace -> -path-to-workspace).
encode_cwd() {
  printf '%s' "${PWD//\//-}"
}

# Validate system name: alphanumeric + dash + underscore only, 1..64 chars.
valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9_-]{1,64}$ ]]
}

# Resolve project dir. Auto-create if missing.
project_dir() {
  local enc="$(encode_cwd)"
  local pdir="$PROJECTS_DIR/$enc"

  if [[ ! -d "$pdir" ]]; then
    mkdir -p "$pdir/systems/default"
    : > "$pdir/systems/default/MEMORY.md"
    ln -s systems/default "$pdir/memory"
    printf 'default\n' > "$pdir/active"
    echo "INFO: created project memory dir: $pdir" >&2
  fi
  printf '%s' "$pdir"
}

active_name() {
  local pdir="$1"
  if [[ -f "$pdir/active" ]]; then
    head -n1 "$pdir/active" | tr -d '\n\r'
  else
    # Fallback: derive from symlink
    local tgt; tgt="$(readlink "$pdir/memory" 2>/dev/null || true)"
    tgt="${tgt##systems/}"
    printf '%s' "${tgt%/}"
  fi
}

count_entries() {
  # Count *.md files excluding MEMORY.md
  local sysdir="$1"
  [[ -d "$sysdir" ]] || { printf '0'; return; }
  find "$sysdir" -maxdepth 1 -type f -name '*.md' ! -name 'MEMORY.md' | wc -l | tr -d ' '
}

cmd_list() {
  local pdir; pdir="$(project_dir)"
  local active; active="$(active_name "$pdir")"
  echo "project: $pdir"
  echo "active:  $active"
  echo
  echo "systems:"
  local sdir="$pdir/systems"
  if [[ ! -d "$sdir" ]] || ! compgen -G "$sdir/*/" >/dev/null; then
    echo "  (none)"
    return
  fi
  for s in "$sdir"/*/; do
    local name="${s%/}"; name="${name##*/}"
    local n; n="$(count_entries "$s")"
    local marker="  "
    [[ "$name" == "$active" ]] && marker="* "
    printf '%s%-20s  %s entries\n' "$marker" "$name" "$n"
  done
}

cmd_use() {
  local name="${1:-}"
  [[ -n "$name" ]] || { echo "ERROR: name required" >&2; exit 2; }
  valid_name "$name" || { echo "ERROR: invalid name (alnum + - _ only)" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local sysdir="$pdir/systems/$name"
  if [[ ! -d "$sysdir" ]]; then
    echo "ERROR: system '$name' does not exist. Try: /mem new $name" >&2
    exit 1
  fi
  # Atomic symlink swap (ln -sfn uses rename(2))
  ( cd "$pdir" && ln -sfn "systems/$name" memory )
  printf '%s\n' "$name" > "$pdir/active"
  echo "active set to: $name"
  echo "(takes effect at next session start)"
}

cmd_new() {
  local name="${1:-}"
  [[ -n "$name" ]] || { echo "ERROR: name required" >&2; exit 2; }
  valid_name "$name" || { echo "ERROR: invalid name (alnum + - _ only)" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local sysdir="$pdir/systems/$name"
  if [[ -d "$sysdir" ]]; then
    echo "ERROR: system '$name' already exists" >&2
    exit 1
  fi
  mkdir -p "$sysdir"
  # Seed MEMORY.md with index skeleton (idempotent on first create).
  cat > "$sysdir/MEMORY.md" <<EOF
# Memory Index

## User

## Feedback

## Project

## Reference
EOF
  echo "created system: $name"
  echo "(not auto-switched; run: /mem use $name)"
}

cmd_rm() {
  local name="${1:-}"
  local force="${2:-}"
  [[ -n "$name" ]] || { echo "ERROR: name required" >&2; exit 2; }
  valid_name "$name" || { echo "ERROR: invalid name" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local active; active="$(active_name "$pdir")"
  if [[ "$name" == "$active" ]]; then
    echo "ERROR: refusing to remove active system '$name'. Switch first." >&2
    exit 1
  fi
  local sysdir="$pdir/systems/$name"
  if [[ ! -d "$sysdir" ]]; then
    echo "ERROR: system '$name' does not exist" >&2
    exit 1
  fi
  if [[ "$force" != "--force" ]]; then
    echo "ERROR: '$name' will be permanently deleted. Re-run with: /mem rm $name --force" >&2
    exit 1
  fi
  rm -rf "$sysdir"
  echo "removed system: $name"
}

cmd_show() {
  local name="${1:-}"
  [[ -n "$name" ]] || { echo "ERROR: name required" >&2; exit 2; }
  valid_name "$name" || { echo "ERROR: invalid name" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local idx="$pdir/systems/$name/MEMORY.md"
  if [[ ! -f "$idx" ]]; then
    echo "ERROR: system '$name' has no MEMORY.md" >&2
    exit 1
  fi
  cat "$idx"
}

cmd_diff() {
  local a="${1:-}" b="${2:-}"
  [[ -n "$a" && -n "$b" ]] || { echo "ERROR: two names required" >&2; exit 2; }
  valid_name "$a" || { echo "ERROR: invalid name '$a'" >&2; exit 2; }
  valid_name "$b" || { echo "ERROR: invalid name '$b'" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local fa="$pdir/systems/$a/MEMORY.md"
  local fb="$pdir/systems/$b/MEMORY.md"
  [[ -f "$fa" ]] || { echo "ERROR: $fa missing" >&2; exit 1; }
  [[ -f "$fb" ]] || { echo "ERROR: $fb missing" >&2; exit 1; }
  diff -u "$fa" "$fb" || true
}

# /mem add <type> <slug> [-d "description"]
# Create a new memory entry in the active system with seeded frontmatter,
# and append a one-line index entry under `## <Type>` in MEMORY.md.
# Refuses if the file already exists.
cmd_add() {
  local etype="${1:-}"
  local slug="${2:-}"
  shift 2 2>/dev/null || true
  local desc=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--description) shift; desc="${1:-}"; shift ;;
      *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$etype" && -n "$slug" ]] || { echo "ERROR: usage: mem add <type> <slug> [-d \"...\"]" >&2; exit 2; }
  case "$etype" in
    user|feedback|project|reference) ;;
    *) echo "ERROR: type must be one of: user feedback project reference" >&2; exit 2 ;;
  esac
  [[ "$slug" =~ ^[a-z0-9_]+$ ]] || { echo "ERROR: slug must be lowercase alnum + underscore" >&2; exit 2; }

  local pdir; pdir="$(project_dir)"
  local active; active="$(active_name "$pdir")"
  local sysdir="$pdir/systems/$active"
  local fname="${etype}_${slug}.md"
  local fpath="$sysdir/$fname"
  local idx="$sysdir/MEMORY.md"

  if [[ -e "$fpath" ]]; then
    echo "ERROR: $fpath already exists" >&2
    exit 1
  fi

  local today; today="$(date -u +%Y-%m-%d)"
  local sid="${CLAUDE_SESSION_ID:-unknown}"
  local desc_line="${desc:-<one-sentence description>}"
  local name_line; name_line="$(echo "$slug" | tr '_' ' ')"

  cat > "$fpath" <<EOF
---
name: $name_line
description: $desc_line
type: $etype
created: $today
last_updated: $today
session_id: $sid
last_read: $today
---

EOF

  # Section title casing: Capitalize first letter for index header match.
  local section
  case "$etype" in
    user)      section="User" ;;
    feedback)  section="Feedback" ;;
    project)   section="Project" ;;
    reference) section="Reference" ;;
  esac

  python3 - "$idx" "$section" "$fname" "$name_line" "$desc_line" <<'PY'
import sys, re, os
idx, section, fname, name_line, desc = sys.argv[1:6]
line = f"- [{name_line}]({fname}) — {desc}"
if not os.path.exists(idx):
    text = f"# Memory Index\n\n## {section}\n{line}\n"
    with open(idx, 'w') as f:
        f.write(text)
    sys.exit(0)
with open(idx) as f:
    text = f.read()
header = f"## {section}"
if header in text:
    # Insert under the existing header (after the header line, before next blank section)
    pat = re.compile(rf"(^## {re.escape(section)}\s*\n)", re.MULTILINE)
    new_text = pat.sub(rf"\1{line}\n", text, count=1)
else:
    new_text = text.rstrip() + f"\n\n{header}\n{line}\n"
with open(idx, 'w') as f:
    f.write(new_text)
PY

  echo "created entry: $fpath"
  echo "indexed under: ## $section"
  echo "(stub frontmatter set; edit body and description as needed)"
}

main() {
  local sub="${1:-list}"
  case "$sub" in
    list|"")    shift 2>/dev/null || true; cmd_list ;;
    use)        shift; cmd_use "$@" ;;
    new)        shift; cmd_new "$@" ;;
    rm)         shift; cmd_rm "$@" ;;
    show)       shift; cmd_show "$@" ;;
    diff)       shift; cmd_diff "$@" ;;
    add)        shift; cmd_add "$@" ;;
    -h|--help|help) usage ;;
    *)          echo "ERROR: unknown subcommand: $sub" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
