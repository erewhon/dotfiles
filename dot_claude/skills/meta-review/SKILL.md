---
name: meta-review
description: Run the multi-model PR review ENSEMBLE (the erewhon pr_review_ensemble agent) on a diff — Claude + the local router + other providers review independently, aggregated into one advisory with quorum labeling. Use when the user wants a second-opinion / multi-model / ensemble review of pending changes, a working-copy diff, a git or jj range, or a GitHub PR. Triggered by /meta-review. Distinct from the built-in /review (single-pass GitHub PR review by Claude) and /code-review (single-pass local bug-hunt by Claude) — this is the multi-provider ensemble. Supports review / digest / supply-chain lenses via --pass.
---

# meta-review

> Front-door skill for the **pr_review_ensemble** agent. Triggered by `/meta-review`.
> Supersedes the old `/pr-review` skill — same engine, routed through the unified `meta` front door.

## Overview

Runs the advisory PR review ensemble at `~/Projects/erewhon/forge/forge/pr_review_ensemble/` via the
`meta` front door. Multiple providers (Anthropic Claude, the local LiteLLM router on Euclid, OpenCode
Zen) review the same diff **independently**; an aggregator synthesizes a unified advisory with quorum
labeling. Output is markdown. Every run appends a record to
`forge/pr_review_ensemble/logs/runs.jsonl` for longitudinal provider-health analysis.

## When to invoke vs. the built-in review skills

This skill is the **multi-model ensemble** — its whole value is independent second opinions reconciled
into one advisory. Reach for the built-ins instead when you want a single-pass Claude review:

- **`/meta-review`** (this) — multi-provider ensemble + quorum. "Second opinion", "ensemble review",
  "what do several models think of this diff?"
- **built-in `/review`** — single Claude pass over a **GitHub PR**.
- **built-in `/code-review`** — single Claude pass over the **local diff** for bugs + cleanups (with a
  cloud `ultra` mode).
- **built-in `/security-review`** — security-focused single pass over branch changes.

Invoke `/meta-review` from inside the repo whose changes you want reviewed — it operates on the
**current working directory's repo**.

## Arguments (`$ARGUMENTS`)

An optional **target** plus optional flags:

| Target form | Meaning |
|-------------|---------|
| *(none)* | Review the working-copy diff (uncommitted changes vs the parent commit). |
| `PR-<number>` (e.g. `PR-123`, case-insensitive) | Fetch and review that GitHub PR via `gh`. |
| `<git-range>` (e.g. `main..HEAD`) | Review that range. |
| `--from <ref>` (jj) | Review since branching from `<ref>`. |
| `<path>.diff` / `<path>.patch` | Use a pre-existing diff file directly (skip capture). |

| Lens flag | Meaning |
|-----------|---------|
| `--pass review` *(default)* | Fan-out + synthesize the advisory. |
| `--pass digest` | Navigational digest of a large PR (size-guarded map-reduce). |
| `--pass supply-chain` | Deterministic pre-scan + focused audit of dependency / hook / CI / obfuscation changes. |

## Steps

### Special case: GitHub PR mode

If `$ARGUMENTS` matches `^PR-\d+$` (case-insensitive):

1. Verify `gh` is on PATH. If not, tell the user `gh` is required for PR fetching and stop.
2. Extract the PR number (`PR-123` → `123`).
3. Capture the diff: `gh pr diff <number> > /tmp/meta-review-pr-<number>.diff`. The cwd must be inside
   a clone of the GitHub-hosted repo so `gh` can resolve the remote. If `gh` errors (PR not found, not
   a GitHub repo, auth failure), surface the error verbatim and stop.
4. If the captured diff is empty, tell the user the PR has no changes and stop.
5. Build a label: `gh repo view --json nameWithOwner -q .nameWithOwner` combined with the PR number as
   `<owner>/<repo>#<number>`. If that fails, fall back to `PR-<number>`.
6. **Skip to step 4 (Run the ensemble).**

### 1. Detect VCS in the current working directory

- `.jj/` exists → use jj commands.
- `.git/` exists (and not jj) → use git commands.
- Neither → tell the user the cwd isn't a tracked repo and stop.

### 2. Capture the diff

- If `$ARGUMENTS` is a path ending in `.diff`/`.patch` and the file exists → use it directly, skip to
  step 3.
- Otherwise write to `/tmp/meta-review-$(date +%s).diff` using:
  - **jj, no args:** `jj diff --git`
  - **jj with revision:** `jj diff --git -r <rev>`
  - **jj with range:** `jj diff --git --from <base> --to <head>`
  - **git, no args:** `git diff HEAD`
  - **git with range:** `git diff <range>`

If the resulting diff is empty, tell the user there's nothing to review and stop.

### 3. Build a `--pr-ref` label

Short label used in the output header and the JSONL log so the user can find the run later.

- **jj:** `jj log -r @ --no-graph --no-pager -T 'change_id.short() ++ " " ++ description.first_line()'`
  (fall back to just the change ID if the description is empty).
- **git:** `git rev-parse --abbrev-ref HEAD` (current branch); if `HEAD` (detached), fall back to
  `git rev-parse --short HEAD`.

### 4. Run the ensemble (through the `meta` front door)

```
uv run --directory /home/erewhon/Projects/erewhon/forge \
  forge review \
    --diff-file <captured-diff-path> \
    --pr-ref "<label>" \
    [--pass review|digest|supply-chain] \
    [--output <path>]
```

The advisory markdown goes to stdout (or `--output`) — show it to the user. The JSONL run record is
appended automatically.

### 5. Surface quorum state

`forge review` exits with code **2** if quorum failed (fewer than 2 reviewers responded). When that
happens:

- Tell the user explicitly that the run was **degraded below quorum** — no aggregated advisory was
  produced.
- The output still shows what each provider attempted (and why each failed), so they can decide
  whether to top up credits, fix a config, etc.
- This is a real degraded state, not a code bug — don't "fix" it by re-running.

## Notes

- `PR_REVIEW_ENSEMBLE_OPENCODE_ZEN_API_KEY` not set → that provider is gracefully skipped (counts as
  "skipped" in the quorum label, not an error).
- Anthropic credit issues → that provider returns "error". The ensemble may still produce advisory
  output if quorum is met (current floor: 2 of 3).
- Ad-hoc overrides are env-driven — see `forge/pr_review_ensemble/config.py` for the full list of
  `PR_REVIEW_ENSEMBLE_*` env vars (model selection, aggregator choice, quorum floor, etc.).
- Grep historical runs: `jq -c . forge/pr_review_ensemble/logs/runs.jsonl` from the meta repo root.
- This agent is **not** exposed over the MCP server's typed wrappers in the same way — the `review`
  MCP tool (`mcp__meta-agents__review`) takes a diff string directly. This skill is the interactive,
  VCS-aware ergonomics shell over the CLI.
- The CLI (`forge review`) is the load-bearing tool — it can also be run straight from a terminal,
  cron, a jj/git hook, or a webhook without this skill.
