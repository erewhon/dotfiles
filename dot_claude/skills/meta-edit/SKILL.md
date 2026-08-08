---
name: meta-edit
description: Run one prompt against a jj repo with N candidate models in parallel (the erewhon parallel_edit agent), each in its own isolated workspace, then produce a side-by-side comparison report of their diffs. Use when the user wants to compare how several models implement the same change in a real jj working copy and pick the best. Triggered by /meta-edit. Requires a jj repo. CLI-only — it mutates a working copy and spawns model subprocesses.
---

# meta-edit

> Front-door skill for the **parallel_edit** agent. Triggered by `/meta-edit`.

## Overview

Runs the parallel-edit harness at `~/Projects/erewhon/forge/forge/parallel_edit/`. It takes a single
prompt, fans it out to 2–26 candidate models (each working in its own isolated jj workspace off the
same base), and renders a markdown report comparing their diffs so the user can pick a winner. This
is a **generate-and-compare** tool, not a review tool.

## When to invoke

- `/meta-edit` typed by the user (primary trigger).
- The user wants to "try this change with several models", "compare model outputs on this edit", or
  "race the models on this prompt" against a real repo.

## Prerequisites

- The target must be a **jj repo** (the agent forks jj workspaces). Default target is the current
  working directory; override with `--repo`.

## Arguments (`$ARGUMENTS`)

| Flag | Meaning |
|------|---------|
| `--prompt "..."` / `--prompt-file PATH` | The change to make (inline or from a file). One is required. |
| `--models "a,b,c"` | 2–26 comma-separated candidates as `[kind:]model` — bare or `claude:<id>` runs `claude -p`; `opencode:<ref>` runs against the router (e.g. `claude-opus-4-8,opencode:glm-5.1,opencode:qwen3.6-plus`). Defaults to `PARALLEL_EDIT_DEFAULT_CANDIDATE_MODELS`. |
| `--repo PATH` | jj repo to edit (default: cwd). |
| `--base REVSET` | jj revset to diff against (default: `@` at launch). |
| `--output PATH` | Write the comparison report here (default: stdout). |
| `--keep-workspaces` | Keep all candidate workspaces on disk after the run. |

## Steps

1. Confirm the target is a jj repo (check for `.jj/`). If not, tell the user and stop.
2. Run the front door, passing `--repo` explicitly when the target isn't the cwd:

   ```
   uv run --directory /home/erewhon/Projects/erewhon/forge \
     forge edit --repo <target-jj-repo> --prompt "<change>" [--models "..."] [--output report.md]
   ```

3. Surface the comparison report (or its path). It lays each candidate's diff side by side; help the
   user pick. Workspaces are cleaned up unless `--keep-workspaces` was passed.

## Notes

- This agent is intentionally **CLI-only** — it isn't exposed over the MCP server, because it mutates
  a real repo and the model subprocesses' stdout would corrupt the MCP stdio stream.
- The CLI is the load-bearing tool; this skill is a thin ergonomics wrapper over `forge edit`.
