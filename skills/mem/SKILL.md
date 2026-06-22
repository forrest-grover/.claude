---
name: mem
description: >
  Manage per-project memory partitions ("systems"). Use when the user asks to
  list/switch/create/remove memory systems or partitions, view the active
  memory system, show or diff a system's MEMORY.md, or add entries. Trigger
  phrases include: "what memory systems do I have", "switch memory", "list
  memory partitions", "current memory system", "/mem ...". Project resolved
  from $PWD; backed by ~/.claude/scripts/mem.sh. Does NOT manage global
  ~/.claude/memory/ (read those files directly).
---

# mem — Multi-Memory System Manager

## Scope

Project-scoped memory partitions only:
`~/.claude/projects/<slug>/systems/<name>/MEMORY.md`. Exactly one system is
active per project; the active system's directory is symlinked to `memory/`
and its `MEMORY.md` is what the harness loads at session start.

**Boundary:** the user's global memory at `~/.claude/memory/` is shared
across all projects and is NOT managed here. If the user asks about memory
they *currently see in context*, those entries likely live in global memory —
read those files directly with `Read`. Run this skill only when the request
is about per-project partitions.

## Critical safety behaviors

These two commands have user-visible footguns. Apply the rule every time.

- **`use <name>` is deferred.** Switching the active system takes effect at
  the *next session start* — the harness already loaded memory for the
  current session. Always tell the user: "active set; restart your session
  for it to load."
- **`rm <name>` requires `--force`.** Never pass `--force` on the user's
  behalf without explicit instruction; the bare `rm` returns the safety
  message and that is the intended behavior.

## When to invoke

User asks about memory systems / partitions / switching memory / "/mem ...".
Or you decide you need to act on the partition layer.

Do NOT invoke for: reading what's currently in memory (use `Read` on the
files), editing a single entry (use `Edit`/`Write`), or anything touching
global `~/.claude/memory/`.

## Invocation

Always run from the user's `$PWD` (the script encodes `$PWD` to the project
slug):

```
~/.claude/scripts/mem.sh <subcommand> [args]
```

## Subcommand reference

| Subcommand | Purpose | Output handling |
|---|---|---|
| `list` (default) | Active system + all systems with entry counts | print verbatim |
| `use <name>` | Atomic switch to `<name>` | print verbatim, then add deferred-effect note |
| `new <name>` | Create empty system seeded with index skeleton | print verbatim |
| `rm <name> [--force]` | Remove non-active system; `--force` required | print verbatim |
| `show <name>` | Print system's MEMORY.md | print verbatim |
| `diff <a> <b>` | Unified diff of two systems' MEMORY.md | print verbatim |
| `add <type> <slug> [-d "..."]` | Create new entry in active system with seeded frontmatter + appended index line. type: user/feedback/project/reference; slug: lowercase alnum + underscore. | print verbatim, then offer to fill in body |

### Validation rules baked into the script

- System names: `[A-Za-z0-9_-]{1,64}`
- `rm` refuses the active system

## Output handling

Print the script's stdout/stderr verbatim. Do not paraphrase structured
output.

After verbatim output, you may add a single-line action prompt — e.g.,
"Restart your session for the switch to load." Keep it short.

If the script exits non-zero, surface the error verbatim before
proposing next steps.

## Related

- Backing script: `~/.claude/scripts/mem.sh`
- Slash-command equivalent (calls the same script): `~/.claude/commands/mem.md`
- Global memory (out of scope here): `~/.claude/memory/`
