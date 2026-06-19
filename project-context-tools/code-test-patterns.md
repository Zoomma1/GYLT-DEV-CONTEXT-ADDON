---
name: code-test-patterns
when: always (cheap, read-only, language-agnostic)
---

# Code & test conventions extractor

Surfaces the *conventions* an agent must follow to write code that fits the repo — the things a
topology map (graphify) doesn't capture: how tests are written, naming, where things go, how to add
a feature the way this team does. Read-only: it only reads a handful of files and writes one README
section. No install, no side effects.

## Run

All reads from the repo root (`$CWD`). Keep it light — sample, don't exhaustively scan.

1. **Stack & build** — read the manifest(s): `package.json` (scripts, deps), `composer.json`,
   `go.mod`, `Gemfile`, `pom.xml`, `pyproject.toml`. Note the framework(s) and the scripts that
   matter (build, lint, test, dev).
2. **Test setup** — detect the test framework and config: `jest.config.*` / `vitest.config.*` /
   `phpunit.xml` / `pytest.ini` / `*_test.go` / `*.spec.*`. Find where tests live (e.g. `tests/`,
   `__tests__/`, co-located `*.spec.ts`) and the **run command** (from the manifest scripts).
3. **Sample to infer patterns** — read **2-3 source files** and **2-3 matching test files** (pick
   from different areas). Infer: naming conventions (files, classes, functions), structure
   (layers/folders), error handling, and the shape of a typical test (arrange/act/assert, mocking
   style, fixtures/factories).
4. **Entry points** — identify the main entry (server bootstrap, `main`, CLI, route registration)
   so the agent knows where execution starts.

If the repo is too small or has no tests, say so in the section rather than inventing patterns.

## Section

Write a `## Conventions & tests` section:

- **Stack** — framework(s) + the key scripts (build / lint / test / dev) with their exact commands.
- **Tests** — framework, where tests live, the **command to run them**, and the shape of a typical
  test (1-2 sentences: structure, mocking/fixtures style) so a new test matches the house style.
- **Conventions** — naming + structure rules inferred from the samples (file/class/function naming,
  folder layout, error handling). Concrete, not generic.
- **Entry points** — where execution starts (bootstrap file, main route file, CLI).
- **Adding a feature / a test here** — 2-4 actionable lines: which files to touch, where the test
  goes, what command verifies it. This is the payoff — it lets the agent contribute in-style from
  the first edit.

Ground every claim in a file you actually read; cite paths. If you couldn't infer something, omit it
rather than guess.
