---
name: lines-of-code
when: always (cheap, language-agnostic)
---

## Run

```bash
# Count source lines per top-level directory, biggest first. Pure illustration —
# replace with your real analyzer (deep call-graph tracer, security scanner, etc.).
find "$CWD" -type f \
  \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.php' -o -name '*.rb' -o -name '*.go' -o -name '*.java' \) \
  -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' \
  | sed "s|$CWD/||" | cut -d/ -f1 | sort | uniq -c | sort -rn | head -15
```

## Section

Summarize the output as a short table (directory → file count), then one sentence
on where the code mass concentrates. If the command returns nothing (no matching
source files), write "lines-of-code tool: no source files matched" instead of an
empty section.

---

> This file ends in `.example.md`, so the skill ignores it. To make it active,
> copy it to `~/.claude/project-context-tools/your-tool.md` (drop the `.example`),
> adjust the Run/Section blocks, and it runs on the next /prepare-project-for-agent.
