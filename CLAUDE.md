# Global Instructions

**MANDATORY at session start (first message):**
1. Substantive request: prompt profile selection, then handle request
2. Greeting/placeholder: prompt profile selection only

Profiles: Claude (default), Manager, Engineer, Researcher
- AskUserQuestion: "Claude (default, Recommended)" first option
- After selection: read `~/.claude/agents/<file>.md` per SOUL.md table
- Adopt behavior for session
- Default: Claude (baseline, no file)

## AI-Directed Document Style

AI-consumed files (CLAUDE.md, SOUL.md, memory, agents, skills, `.claude/research/`):
- Telegraphic: drop articles, filler, unnecessary grammar
- Structured: frontmatter, headers, tables, key:value over prose
- One concept per line
- Lists/tables over paragraphs
- `file:line` refs, not quoted code
- No redundancy: state once, reference by location
- Memory: no bold/markdown on Why/How lines
- Frontmatter `description`: clear short sentences for relevance
- Human-facing docs (READMEs, user docs): exempt
