---
name: meta-book
description: Run the book research harness (the erewhon book_researcher agent) over a book config file — generator–evaluator sprint cycles, verified by an adversarial panel, producing draftable chapter/section research. Use when the user wants iterative, source-backed research for a book or long-form writing project driven by a config that lists chapters and sections. Triggered by /meta-book. Requires a book config YAML/JSON file.
---

# meta-book

> Front-door skill for the **book_researcher** agent. Triggered by `/meta-book`.

## Overview

Runs the book research harness at `~/Projects/erewhon/forge/forge/book_researcher/`. Like
`/meta-research`, it works in sprint cycles with an adversarial verification panel — but it's shaped
for long-form writing: the panel's actionability lens scores **draftability** (could a writer
actually draft this chapter section from the findings?), and it's driven by a book config file that
lays out the chapters/sections to research.

## When to invoke

- `/meta-book` typed by the user (primary trigger).
- The user wants to "research a book", "run the book researcher", or build verified background for
  long-form/chapter writing from a config.

## Prerequisites

- A **book config file** (YAML or JSON). See the worked example at
  `~/Projects/erewhon/forge/forge/book_researcher/examples/sample-book.yaml` for the expected shape
  (title, chapters, sections, etc.). If the user hasn't got one, help them draft it from that
  template before running.

## Arguments (`$ARGUMENTS`)

The first argument is the **path to the book config file**. Optional flags forwarded to the agent:

| Flag | Meaning |
|------|---------|
| `--max-sprints N` | Max research sprints this run (default from config). |
| `--dry-run` | Plan sprints only — no research/verification calls. |
| `--summary` | Print the current knowledge summary for this book and exit. |

## Steps

1. Confirm the config path exists. If the user only described the book, draft a config from the
   `examples/sample-book.yaml` template first and confirm it.
2. Run the front door:

   ```
   uv run --directory /home/erewhon/Projects/erewhon/forge \
     forge book <path/to/book-config.yaml> [--max-sprints N] [--dry-run]
   ```

3. Progress streams to stdout; verified research is written under
   `~/Projects/erewhon/forge/book-research/<slug>/`. Show the user the output location and a summary.
   Re-running resumes from existing sprints.

## Notes

- Output under `book-research/` is gitignored — run artifacts, not source.
- Exposed over MCP as the `book` tool (`mcp__meta-agents__book`) for programmatic calls; this skill
  is the interactive wrapper over `forge book`.
- The CLI is the load-bearing tool; this skill is a thin ergonomics shell.
