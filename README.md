# GYLT-DEV-CONTEXT-ADDON

A dev addon for [GYLT](https://github.com/Zoomma1/get-your-life-together): it prepares a
**reusable, codebase-clean project context** for Claude Code so every session starts
already knowing the shape of your repo.

It is the reference example of a GYLT addon — clone it, run `install.sh`, done.

## What you get

| Piece | What it does |
|---|---|
| `/prepare-project-for-agent` | Runs `graphify` on a repo (AST topology + Leiden clustering, ~10s, $0), then writes a curated README (communities, structural god nodes, anti-patterns, agent notes) to `~/.claude/project-contexts/<slug>/`. **Nothing is written into the target repo.** |
| `load-project-context.sh` hook | At every SessionStart, auto-loads that README for the current repo (monorepo-aware). |
| `/create-adr` | Records an Architecture Decision Record into the same context folder. Surfaced back to sessions as a live link. |
| Context-tools socket | A documented extension point: plug deeper analyzers (call-graph tracers, scanners…) to run after graphify. Ships with zero active tools. |

## Install

```bash
git clone https://github.com/Zoomma1/GYLT-DEV-CONTEXT-ADDON
cd GYLT-DEV-CONTEXT-ADDON
bash install.sh
```

Requires the `graphify` CLI: `uv tool install graphifyy` (double `y`).
Optional: `jq` (so the installer registers the SessionStart hook automatically; without it you copy one snippet by hand).

Restart Claude Code once after installing so the hook is picked up.

## Use

From the root of any repo you want an agent to understand:

```
/prepare-project-for-agent
```

That's a one-time prep (regenerable). Every later session opened from that repo gets
the context injected automatically — you'll see `Project context loaded.` as the first line.

Record decisions as you go:

```
/create-adr
```

## Extending — the context-tools socket

`graphify` gives the macro map. To run a deeper analysis after it (e.g. a per-language
call-graph tracer), drop a tool file in `~/.claude/project-context-tools/`. See
[`project-context-tools/CONTRACT.md`](project-context-tools/CONTRACT.md) for the format and
[`lines-of-code.example.md`](project-context-tools/lines-of-code.example.md) for a working shape.
The skill picks it up on the next `/prepare-project-for-agent` run and appends its section to the README.

## Design notes

- **Zero files in the target codebase** — the whole point. Everything lives in `~/.claude/project-contexts/<slug>/`, keyed by `basename "$PWD"`.
- **The hook does a raw `cat`** of the README — it follows no links. So ADRs are surfaced as a *live link* (a path the agent reads itself), always current without regenerating the context.
- **No LLM enrichment** — AST-only + clustering keeps it ~$0 and ~10s.

## License

MIT — see [LICENSE](LICENSE).
