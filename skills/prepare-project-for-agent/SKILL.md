---
name: prepare-project-for-agent
description: Prepare a reusable project context so future Claude Code sessions work efficiently on a codebase, without dropping anything into the target repo. Runs the graphify CLI pipeline (AST topology extraction + Leiden clustering, ~10s, $0) then generates a curated README (mechanical + LLM) summarizing communities, structural god nodes, anti-patterns and practical notes for the agent. Stored in `~/.claude/project-contexts/<slug>/` keyed by `basename "$PWD"`. Normally run once per project, regenerable. Invoke from the target repo root — typically the first time you prepare a project so an agent can work on it intelligently, or after a large structural refactor.
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /prepare-project-for-agent

Generates a reusable project context for Claude Code sessions, without touching the target codebase. The context lives in `~/.claude/project-contexts/<slug>/` where `slug = basename "$PWD"` at invocation time.

Loading is automatic: the SessionStart hook `~/.claude/hooks/load-project-context.sh` resolves `basename "$PWD"` → `cat ~/.claude/project-contexts/<slug>/README.md` and injects it at the start of every session (it also scans `*/.git` sub-repos for monorepos). The hook does a raw `cat`: it follows no link and resolves no path — **everything that must reach the agent has to be in the README**. That is why ADRs are injected as a *live link* (Step 3.5): an instruction line + a path the agent reads itself at runtime, always up to date without regenerating this context.

## Prerequisites

- `graphify` CLI installed. Check with `which graphify`. If missing: tell the user and stop. Install: `uv tool install graphifyy` (note the double `y`).
- Invoke from the root of the repo to analyze. The cwd determines both the slug and the extraction scope.

## Step 1 — Identify the project and prepare the context folder

1. Get the cwd: `pwd`. Store as `CWD`.
2. Compute the slug: `basename "$CWD"`. Store as `SLUG`.
3. Ask for confirmation via AskUserQuestion:
   > Preparing context for `<SLUG>` (cwd = `<CWD>`). Continue?
   - Yes → continue
   - No → stop without modifying anything
4. Define `CONTEXT_DIR = ~/.claude/project-contexts/<SLUG>`.
5. If `CONTEXT_DIR/README.md` already exists, ask:
   > A context already exists for `<SLUG>` (generated on `<README date>`). Regenerate (overwrites) or keep the current one?
   - Regenerate → continue
   - Keep → stop, show the path to the existing README
6. Create `CONTEXT_DIR` if absent: `mkdir -p "$CONTEXT_DIR"`.

## Step 2 — Obtain the graph

### 2.0 — Reuse an existing graph if present (safeguard)

**Before running anything, check whether a graph already exists — if so, use it as-is and do NOT regenerate:**

- `<CWD>/graphify-out/graph.json` — a graph committed in the repo (e.g. a teammate ran full mode), or
- `<CONTEXT_DIR>/graphify-out/graph.json` — a prior run's graph in the store.

If found:
- Tell the user: *"Existing graph found at `<path>` — using it as-is (not regenerating). To force a fresh extraction, re-run and ask explicitly for a rebuild."*
- If the graph is in the repo but not yet in the store → `cp -R "$CWD/graphify-out" "$CONTEXT_DIR/graphify-out"` (so the README and the hook read it).
- **Skip 2.1–2.3 entirely** — jump to Step 2.5 (socket), then Step 3 (read) and Step 4 (write the README).

Only if **no** graph exists anywhere, continue below.

### Choose the run mode

graphify can run two ways. Ask via AskUserQuestion, store the choice as `MODE` (`minimal` | `full`):

> How should graphify run for `<SLUG>`?
> - **Minimal** (default) — fast CLI extraction, output kept only in the context store. **Zero footprint in the repo.**
> - **Full** — also installs graphify's live integration, committed to the repo so the **whole team** benefits on clone: the interactive `graph.html`, the **PreToolUse hook** (injects graph context on every tool call), and the **MCP server** (agent queries the graph live).

> **Full mode is a deliberate, controlled trade of the "zero footprint" rule for a shared team artifact.** Default to `minimal` if the user is unsure.

**graphify behavior**: graphify writes to `<target-path>/graphify-out/` (inside the codebase), regardless of cwd. In `minimal` we move it out post-run (zero footprint); in `full` we keep it in the repo (shared) and copy to the store.

### 2.1. Run graphify

```bash
graphify update "$CWD" --no-cluster
```

Then cluster — **minimal** skips the viz, **full** keeps it (produces `graph.html`, part of what the team gets):

```bash
graphify cluster-only "$CWD" --no-viz   # MODE=minimal
graphify cluster-only "$CWD"            # MODE=full  (generates graph.html)
```

### 2.2. Check the expected files

After the runs, verify the presence of:
- `<CWD>/graphify-out/GRAPH_REPORT.md` (structured markdown report — **the skill's primary source of truth**)
- `<CWD>/graphify-out/graph.json` (raw data for drill-down)

If either is missing, or graphify returned a non-zero exit code:
- Capture stderr
- Tell the user (missing tree-sitter grammar for an exotic language, empty repo, missing dependency)
- Stop — no silent fallback. A partial context would mislead the agent.

**Guard "language not supported by tree-sitter"** — graphify can exit 0 and produce a valid `GRAPH_REPORT.md` while having extracted almost nothing if the project language has no tree-sitter grammar. Read the report Summary:

- **If total node count < 10**, OR
- **If all nodes come from config files** (extensions/patterns: `.json`, `.local.*`, `.env*`, `package.json`, `composer.json`, `settings.*`)

→ Explicitly detect the "unsupported language" case and **switch straight to manual mode**:
- Tell the user: `⚠️ graphify only extracted N significant nodes (language probably unsupported by tree-sitter). Switching to manual mode — exploring the repo by hand to build the README.`
- Do not retry graphify with other flags.
- Manual mode: explore the repo (structure, key files, visible conventions) and write the curated README without `GRAPH_REPORT.md` as the source.

### 2.3. Place the output (depends on MODE)

#### MODE = minimal — move to the store (zero repo footprint)

```bash
rm -rf "$CONTEXT_DIR/graphify-out"          # no-op on first run
mv "$CWD/graphify-out" "$CONTEXT_DIR/graphify-out"
```

Check: `<CWD>/graphify-out/` is gone, `<CONTEXT_DIR>/graphify-out/graph.json` exists.

#### MODE = full — keep in the repo (shared team artifact) AND copy to the store

The graph stays in the repo for the team; a copy goes to the store so this skill's README and the SessionStart hook keep working.

1. **Copy** (not move) to the store:
   ```bash
   rm -rf "$CONTEXT_DIR/graphify-out"
   cp -R "$CWD/graphify-out" "$CONTEXT_DIR/graphify-out"
   ```
2. **Install the live Claude Code integration** (PreToolUse hook + CLAUDE.md section):
   ```bash
   graphify claude install
   ```
   Then **detect where it wrote**:
   - Project-level (`./.claude/settings.json` and/or `./CLAUDE.md` changed) → committable, teammates get it on clone.
   - Global-only (`~/.claude` changed) → add one line to the repo's `CLAUDE.md`: *"Live graph hook: run `graphify claude install` once after cloning."*
3. **MCP server** — add graphify's MCP so agents query the graph live. Create/merge `<CWD>/.mcp.json`:
   ```json
   { "mcpServers": { "graphify": { "command": "graphify", "args": ["<CWD>", "--mcp"] } } }
   ```
4. **Hand the commit to the user** (this skill never runs git):
   > Full mode left these in the repo — review and commit so the team gets the live graph:
   > `graphify-out/` (graph.json + graph.html + GRAPH_REPORT.md), `.mcp.json`, and the graphify section in `CLAUDE.md` / `.claude/settings.json`.

Check: `<CWD>/graphify-out/graph.json` AND `graph.html` exist, plus the store copy.

## Step 2.5 — Additional context tools (the socket)

`graphify` gives the macro map. Other tools can drill deeper (e.g. a deep call-graph tracer, a security scanner, a test-coverage mapper). They plug in here through a generic socket. **This addon ships one active tool — `code-test-patterns` (conventions & test patterns) — and the team adds their own.**

Mechanism:

1. List `~/.claude/project-context-tools/*.md`. **Ignore** any `*.example.md` and any file without a `name:` front-matter key (those are docs like `CONTRACT.md`, not tools). If nothing remains, skip this step.
2. For each tool file, read it and follow its instructions. A tool file declares (see `project-context-tools/CONTRACT.md` in this addon):
   - `when:` — a one-line condition (e.g. "only for legacy PHP/Ruby repos"); skip the tool if it does not apply to `<CWD>`.
   - a **Run** block — shell command(s) to execute from `<CWD>`.
   - a **Section** block — how to turn the command output into a markdown section.
3. Append each tool's section to the README under `## Additional analysis — <tool name>` (Step 4).

Keep the socket honest: if a tool fails or is skipped, note it in the README rather than silently omitting it.

## Step 3 — Read and filter the analysis

Read `CONTEXT_DIR/graphify-out/GRAPH_REPORT.md`. Structured markdown with these sections:

- `## Summary` — node/edge/community counts, extraction quality (% EXTRACTED / INFERRED / AMBIGUOUS), token cost (0 if no LLM phase)
- `## Community Hubs (Navigation)` — flat list of communities (report-internal navigation, low value for the curated README)
- `## God Nodes (most connected)` — top gods with their `degree`, as a numbered list
- `## Surprising Connections` — anti-patterns as `source --relation--> target [EXTRACTED|INFERRED]` with `source_file` below
- `## Communities (N total, M thin omitted)` — per community, a `### Community X - "label"` block with cohesion + a sample of the first nodes
- `## Knowledge Gaps` — isolated nodes + thin communities (noise or missing docs)
- `## Suggested Questions` — questions generated on critical bridges (useful for agent notes)

Filter to keep only what matters:

- **Communities kept**: top 10 by descending size (`Nodes (N)` in each `### Community X`), **after pre-filtering deps/doc communities**. **No cohesion threshold** — absolute cohesion values vary wildly across projects, so a hard cutoff would exclude everything. Cohesion is shown in the README as clustering-quality info, not a selection criterion.

  **deps/doc pre-filter**: on large projects, the top communities by size are often polluted by dependencies (composer.json, package.json) and doc blocks (`code:block1`, `code:sql`). Heuristic: if **≥ 70% of a community's sample nodes** match one of the patterns below, mark it "deps/doc" and skip it for the top 10:
  - prefix `code:` (doc blocks parsed as nodes)
  - prefix `@` or contains `/` (npm scope or composer namespace: `@angular/core`, `vendor/lib`)
  - exact match on standard manifest tokens: `name`, `version`, `description`, `private`, `dependencies`, `devDependencies`, `require`, `require-dev`, `autoload`, `psr-4`, `scripts`, `repositories`, `prefer-stable`

  If fewer than 5 usable communities remain, take the raw top 10 and note in the README that noise is unavoidable.

- **Gods kept**: top 10 (the numbered list is already ranked by descending `degree`). **If a label appears several times**, it is probably several entities in different namespaces. Read `graph.json` for each occurrence's `source_file` and **show the namespace/path in the table** to disambiguate.

- **Surprises kept**: all, but **filter out pure doc↔image bridges** (e.g. a README pointing to screenshots) — trivial and non-actionable. Heuristic: if the `source_files` contain a `.md` and a `.jpg/.png/.jpeg/.svg`, ignore that surprise.

  **Fallback if "Surprising Connections" says "None detected"** (large/dense graphs): graphify becomes conservative. Extract cross-community bridges from "Suggested Questions" instead — each *"Why does `X` connect Community A to B, C, D?"* identifies a god node bridging several sub-domains. Present them as "Potential anti-patterns — verify manually" with a note that graphify did not formally detect them.

- **Suggested Questions kept**: those mentioning cross-community bridges on gods (useful for agent notes, or as anti-pattern fallback) or INFERRED edges to verify. Ignore questions on isolated nodes (`name`, `version` noise).

For occasional drill-down (e.g. inferring a community's business role from its nodes' real `source_file`), read `CONTEXT_DIR/graphify-out/graph.json`:
- `.nodes[]`: `id`, `label`, `norm_label`, `file_type`, `source_file`, `source_location`, `community`
- `.links[]`: `source`, `target`, `relation` (∈ contains, imports_from, imports, method, calls, extends), `confidence` (EXTRACTED, INFERRED, AMBIGUOUS)

Read `graph.json` only when `GRAPH_REPORT.md` is not enough to name a cluster or justify a god — never dump it whole.

## Step 3.5 — Resolve project ADRs (live link)

Project ADRs written by the `create-context-adr` skill live in `CONTEXT_DIR/ADR/` (next to this context). They are decisions already made — surfaced to the agent as a **live link**: not copied into the README (which would go stale on every new ADR), but an instruction line + path the agent reads at runtime.

Procedure:

1. If `CONTEXT_DIR/ADR/` exists and contains at least one `*.md` (other than `INDEX.md`) → include the `## ADR` section in the README (Step 4), pointing to `CONTEXT_DIR/ADR/`.
2. Otherwise → **omit** the `## ADR` section.

No vault, no external mapping: the ADRs live in the same context folder as everything else, so the link is a stable absolute path.

## Step 4 — Generate the curated README (mechanical + LLM)

Write `CONTEXT_DIR/README.md` using `template-readme.md` (in this skill's folder) as the structure. "[mechanical]" sections are direct table fills from the JSON; "[LLM]" sections need a written sentence/paragraph grounded in the nodes and their `source_file`.

Strip every bracketed instruction from the final README — they are guidance for you, not content.

## Step 5 — Confirm

Tell the user:

> Context generated for `<SLUG>`:
> - README: `~/.claude/project-contexts/<SLUG>/README.md`
> - Raw graphify analysis: `~/.claude/project-contexts/<SLUG>/graphify-out/`
> - ADRs (if any): `~/.claude/project-contexts/<SLUG>/ADR/`
>
> The SessionStart hook `load-project-context.sh` will load this README automatically when a session opens from this repo (expected acknowledge: "Project context loaded.").

## Absolute rules

- **Zero files in the target codebase.** Everything goes to `~/.claude/project-contexts/<SLUG>/`. This is the skill's reason to exist — an agent that prepares its ground without leaving traces in the client repo.
- **No graphify LLM enrichment phase.** Measured at ~$0.85/run for limited value (doc↔image bridges), explicitly skipped. We stay AST-only + Leiden clustering: ~10s, $0, enough for an actionable context.
- **Normally run once per project.** Regeneration possible with explicit confirmation at Step 1.
- **No silent fallback on graphify error.** Better to stop and report than to ship a partial context that misleads later sessions.

## Known limits

- **Incomplete tree-sitter on some languages.** On Rust for example, `impl Foo` blocks are poorly extracted. The skill works but the result on Rust-heavy projects is less precise.
- **No multi-repo support.** One project = one cwd = one slug. For a multi-repo workspace, invoke the skill separately in each sub-repo.
- **Slug collisions accepted.** Two different projects with the same folder name overwrite each other's context. Accepted convention for V1.
- **graphify format is versioned.** Tested on graphify 0.8.16. The `GRAPH_REPORT.md` sections may evolve. If an update breaks parsing, inspect the new report structure before adjusting the skill — do not extrapolate.
