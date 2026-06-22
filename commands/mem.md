---
description: Manage multi-memory systems for the current project (list/use/new/rm/show/diff)
argument-hint: [list|use <name>|new <name>|rm <name> [--force]|show <name>|diff <a> <b>]
allowed-tools: ["Bash"]
---

# /mem — Multi-Memory System Manager

Run the `mem` script with the user's arguments and report the output verbatim.

## Steps

1. Invoke the script via Bash:
   ```
   ~/.claude/scripts/mem.sh $ARGUMENTS
   ```
   - If `$ARGUMENTS` is empty, run `~/.claude/scripts/mem.sh list`.
   - Always run from the user's current working directory (the script resolves the project from `$PWD`).

2. Print the script's stdout and stderr verbatim. Do not paraphrase.

3. If the script exits non-zero, surface the error message clearly to the user.

## Subcommand reference (for the user)

- `/mem` or `/mem list` — show active system + all systems with entry counts
- `/mem use <name>` — atomic switch to system `<name>` (effect on next session start)
- `/mem new <name>` — create a new empty system (does not auto-switch)
- `/mem rm <name> [--force]` — remove a system (refuses active; needs `--force`)
- `/mem show <name>` — print MEMORY.md of system `<name>`
- `/mem diff <a> <b>` — diff between two systems' MEMORY.md indexes

## Notes

- System names: alphanumeric, dash, underscore only.
- Switching takes effect at the NEXT session start (harness loads memory once at startup).
- Project memory dir is auto-created on first use.
