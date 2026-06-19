---
name: create-adr
description: Create an Architecture Decision Record (ADR) for the current project, stored alongside its agent context in `~/.claude/project-contexts/<slug>/ADR/`. Invoke whenever a structural decision is made — architecture choice, convention, technical arbitration, pivot. Captures the decision from the session context, numbers it per the folder convention, generates a complete ADR (not an empty skeleton), and updates the ADR INDEX. The ADRs are surfaced back to future sessions as a live link by /prepare-project-for-agent.
allowed-tools:
  - Bash
  - Read
  - Write
---

# /create-adr

Creates a homogeneous ADR for the current project without copying an existing ADR by hand. The skill *is* the format. ADRs live next to the project's agent context (`~/.claude/project-contexts/<slug>/ADR/`), so they travel with the context the agent already loads — no codebase pollution, no vault dependency.

## When to invoke

- Architecture decision (technology, pattern, structure choice)
- Convention (naming, workflow, session rule)
- Settled technical arbitration (X over Y, and why)
- Pivot or invalidation of an approach (with `status: superseded` + link)

Do not invoke for: a simple note, a ticket, a reversible choice with no lasting consequence.

## Step 1 — Resolve the target folder

1. `CWD = $(pwd)`, `SLUG = $(basename "$CWD")`.
2. `ADR_DIR = ~/.claude/project-contexts/<SLUG>/ADR/`.
3. `mkdir -p "$ADR_DIR"`.

> Note: the ADR folder lives under the same `<SLUG>` as /prepare-project-for-agent. If no context exists yet for this project, the ADR folder is created anyway — the next /prepare-project-for-agent run will pick it up.

## Step 2 — Determine the next ADR number

Scan `ADR_DIR` for existing `ADR-*.md` (excluding `INDEX.md`). Files are named `ADR-NNN-<kebab-title>.md` (zero-padded to 3 digits).

- No existing ADR → `NNN = 001`.
- Otherwise → highest existing number + 1.

## Step 3 — Capture the decision

Gather, from the current session context (ask the user only for what is genuinely missing):
- **Title** — short, in the imperative or as a statement ("Use Postgres over MongoDB", "BFF owns auth, not the SPA").
- **Context** — what problem/forces led to the decision.
- **Decision** — what was decided, precisely.
- **Consequences** — what this implies (positive and negative), what it constrains going forward.
- **Status** — `accepted` by default. If it supersedes a prior ADR, set `superseded` on the old one and link both ways.

## Step 4 — Write the ADR

Write `ADR_DIR/ADR-NNN-<kebab-title>.md` using `template-adr.md` (in this skill's folder). Fill every field — no bracketed placeholders left in the output.

## Step 5 — Update the INDEX

Maintain `ADR_DIR/INDEX.md`. If it does not exist, create it with a header and a table. Append (or update) the row for this ADR:

```markdown
# ADR — <SLUG>

| ID | Title | Status | Date |
|----|-------|--------|------|
| [ADR-001](ADR-001-....md) | ... | accepted | YYYY-MM-DD |
```

Keep rows ordered by ID.

## Step 6 — Confirm

Tell the user:

> ADR-NNN created: `~/.claude/project-contexts/<SLUG>/ADR/ADR-NNN-<title>.md`
> It will be surfaced to future sessions via the README's live link (run /prepare-project-for-agent if no context README exists yet).

## Rules

- One decision per ADR. If the session produced several, create several.
- Never overwrite an existing ADR with the same number — recompute the next number.
- An ADR is immutable once accepted. To change a decision, write a new ADR with `supersedes: ADR-NNN` and flip the old one to `status: superseded`.
