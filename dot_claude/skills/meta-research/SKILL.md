---
name: meta-research
description: Run the local iterative research harness (the erewhon general_researcher agent) on a question — plan → research → verify with an adversarial panel → synthesize — over the on-prem LLM router, writing a cited synthesis.md. Use when the user wants a deep, multi-sprint, verified answer to a factual or analytical question via the erewhon agents. Triggered by /meta-research. Distinct from the web-based `research`/`deep-research` skills, which search the live web with Claude; this one drives local models through the sprint harness.
---

# meta-research

> Front-door skill for the **general_researcher** agent. Triggered by `/meta-research`.

## Overview

Runs the iterative research harness at `~/Projects/erewhon/forge/forge/general_researcher/`. Each
sprint plans sub-questions, researches them, then an **adversarial perspective-diverse panel**
verifies the findings (each seat takes a distinct lens — source quality, claim verification,
counter-narrative, depth, actionability) before a judge-pick-and-graft synthesizer writes the final
answer. It runs against the local LiteLLM router on Euclid, not the live web.

**Use this** for a researched, cited answer to a real question. For live-web fact-finding with Claude,
use the separate `deep-research` / `research` skills instead.

## When to invoke

- `/meta-research` typed by the user (primary trigger).
- The user wants a "deep researched answer", "run the research agent", or a multi-sprint
  investigation of a factual/analytical question via the erewhon harness.

## Arguments (`$ARGUMENTS`)

The first argument is the **question** (quote it) or a path to a topic YAML/JSON file. Optional flags
are forwarded to the agent's own parser:

| Flag | Meaning |
|------|---------|
| `--max-sprints N` | Cap sprints this run (default from config). |
| `--always-deepen` | Keep running sprints even after one passes verification. |
| `--dry-run` | Plan sprints only — no LLM research/verify/synthesis calls. |
| `--summary` | Print existing research status for this topic and exit. |
| `--slug NAME` | Override the auto-derived output directory name. |

## Steps

1. Run the front door (works from any cwd — it targets the meta repo explicitly):

   ```
   uv run --directory /home/erewhon/Projects/erewhon/forge \
     forge research "<question>" [--max-sprints N] [--dry-run] [...]
   ```

2. The agent streams sprint progress to stdout — relay the highlights. The synthesized answer is
   written to:

   ```
   ~/Projects/erewhon/forge/research/<slug>/synthesis.md
   ```

   (`synthesis.json` alongside it has the structured form: answer, confidence, key sources, open
   questions.) Show the user the synthesis and the path.

3. Re-running the same question **resumes** — existing sprints/findings are scanned and the run
   continues from where it left off. Use `--summary` first if you only want current status.

## Notes

- Output dirs under `research/` are gitignored — they're run artifacts, not source.
- The MCP server exposes the same agent as the `research` tool (`mcp__meta-agents__research`) for
  programmatic/synchronous calls; this skill is the interactive ergonomics shell over the CLI.
- The CLI is the load-bearing tool. This skill is a thin wrapper — `forge research` can also be run
  straight from a terminal or cron without it.
