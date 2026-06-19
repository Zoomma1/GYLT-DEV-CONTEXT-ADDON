# Project context tools — the socket

`/prepare-project-for-agent` runs `graphify` to build the macro map of a repo, then
(Step 2.5) looks for **additional context tools** in `~/.claude/project-context-tools/`.
This is the extension point: anyone can plug a deeper analyzer after graphify
without modifying the skill.

This addon ships **zero active tools** — only this contract and an example.

## How it works

1. The skill lists `~/.claude/project-context-tools/*.md` (it ignores `*.example.md`).
2. For each file, it reads the front matter + the two blocks below and follows them.
3. Each tool produces one markdown section appended to the generated README under
   `## Additional analysis — <name>`.

## Tool file format

```markdown
---
name: <tool name shown in the README section>
when: <one-line condition; the skill skips the tool if it does not apply to the repo>
---

## Run
<Shell command(s) to execute from the repo root ($CWD). Keep them deterministic.
 Output goes to stdout or a file under ~/.claude/project-contexts/<slug>/.>

## Section
<How to turn the command output into a markdown section: what to summarize,
 which fields to surface, how long. The skill writes the section following this.>
```

## Adding a tool

- By hand: drop a `<name>.md` here following the format above.
- Generated: use the `gylt-new-addon` workflow if your tool ships as its own addon,
  or just author the single file.

## Rules

- A tool that fails or is skipped must say so in its README section — never omit silently.
- Tools run from the repo root but **write only** under `~/.claude/project-contexts/<slug>/`
  (the "zero files in the codebase" rule of prepare-project-for-agent applies to tools too).
- `*.example.md` files are documentation, never executed.

## Example use case

A deep call-graph tracer (per-language) can plug in here: graphify gives the macro
communities/gods, the tracer drills a specific entry point into an annotated call
graph. See `example-tool.md` for the shape — replace the command with your own.
