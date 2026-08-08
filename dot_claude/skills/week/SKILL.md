---
name: week
description: The weekly-themes cadence — plan (Monday interview → theme rows → Forge cross-check → worker tag pass), replan (mid-week course correction with an audit trail), and review (Friday outcomes → retro → seed next week). Use when the user says "/week", "plan my week", "let's plan the week", "replan" / "something got dumped on me", or "weekly review". Reads and writes the Weekly Themes database in the Forge notebook. Distinct from /today, which is the morning read-only briefing over what this skill writes.
---

# week

> The cadence half of the weekly-themes system (design: meta/architecture-discussion.md,
> 2026-07-30). Store: the **Weekly Themes** database in the **Forge** notebook — one row
> per theme per week. This skill is the only writer of that database; /today, the
> SessionStart injection, and the worker tag pass are its readers.

## Mode selection

`/week plan`, `/week replan`, `/week review` are explicit. Bare `/week`: infer from
context — "plan"-shaped ask or no rows for the current week → plan; "this landed on my
lap" / "priorities changed" → replan; "how did the week go" or it's Friday → review.
Say which mode you chose in one line.

## The store

- Database: `Weekly Themes` (Forge notebook). Columns: **Week** (Monday date,
  `YYYY-MM-DD` — compute the most recent Monday, or next Monday when planning ahead on
  a weekend), **Theme** (short imperative: "Ship X for Contract A"), **Projects**
  (comma-separated Forge project names; prose-only contexts like the full-time job may
  name no Forge project), **Outcome** (the "done means…" sentence — concrete, checkable),
  **Oversight** (`autonomous` | `check-ins` | `pair`), **Status** (`active` | `done` |
  `parked` | `superseded`), **Notes** (audit trail).
- Read with `mcp__nous__get_database(notebook="Forge", database="Weekly Themes")` —
  it is small; full reads are fine. Write rows with `add_database_rows`; update by row
  UUID with `update_database_rows` (this is NOT the task database — the low-level tool
  is correct here).

## Iron rules

1. **Never delete a row.** Course corrections mark `superseded` or `parked` with a Notes
   line saying what displaced them and when. The history IS the point — review mode and
   future planning read it.
2. **3–4 themes maximum.** More than four active themes for one week is overcommitment
   by construction; say so and make the user choose.
3. **Every Outcome is checkable.** "Make progress on Z" is not an outcome; "Z's ingest
   pipeline handles the sample file end to end" is. Push back on vague outcomes during
   the interview — that is this skill's version of the architect's push-back duty.
4. **Not a nag.** This skill runs when invoked. It never scolds about past weeks; review
   mode states facts and moves to next week.

## `/week plan`

1. **Carry-over read.** Load last week's rows. Anything `active` and unfinished is the
   first interview question: carry, park, or drop (→ `superseded`, with a Notes line).
2. **Interview.** Ask, conversationally and briefly, for this week's must-ships across
   the standing contexts — the contract job, the full-time job, personal projects. For
   each: the outcome sentence, the oversight level, and (where applicable) which Forge
   project(s) it maps to. 3–4 themes total (rule 2).
3. **Forge cross-check.** For each theme with Projects: `query_tasks(project=...,
   status="Ready")` (plus `get_feature_tasks` when the theme names a feature). A theme
   with no Ready tasks cannot start — either run the /forge-decompose rubric inline to
   file its leaves (with the user's yes), or record in Notes that it is
   interactive-only work. Say which.
4. **Overcommit check.** `recent_task_activity(since="7d")` — compare last week's actual
   landings against what this plan implies. If the plan is ~2× last week's throughput,
   say so plainly and let the user cut or accept knowingly.
5. **Write the rows** (`add_database_rows`, Status `active`).
6. **Worker tag pass.** Remove the `theme-current` tag from every task that still
   carries it (search `query_tasks` per last week's theme projects, then
   `manage_tags(remove="theme-current")` on their pages), then add it to the Ready
   tasks of this week's theme projects/features. The autonomous worker and `get_next_task`
   favor tagged work without any forge changes.
7. **Close.** One-paragraph summary: the themes, what has runway (Ready tasks), what
   needs decomposition or the user, and the first suggested block for Monday morning.

## `/week replan` — the Wednesday dump

1. Capture the interruption in the user's words: what landed, what it displaces, hard
   deadline if any.
2. Load the current week's rows. For each displaced theme: `parked` (resumable this
   week) or `superseded` (gone for this week) — set Status and append a Notes line:
   `"YYYY-MM-DD replan: parked for <new theme> — <one-line reason>"`. Never delete
   (rule 1).
3. Add the new theme row (`active`, Notes: `"added by replan YYYY-MM-DD"`), interview
   only for what's missing: outcome sentence, oversight, project mapping. Run the
   Forge cross-check (plan step 3) for it.
4. Re-run the tag pass for the new active set.
5. Summarize what moved in ≤5 lines: new theme, what got parked/superseded, and the
   revised first block. No ceremony — a replan is supposed to be fast.

## `/week review`

1. Load the week's rows (all statuses). For each: what actually happened —
   `recent_task_activity(since="7d")` filtered to the theme's projects, plus the user's
   one-line self-report for prose-only themes.
2. Set Status (`done`, or leave `active` with a Notes line for honest carry-over) and
   append one retro sentence per row: what helped, what dragged.
3. If the Agile Results notebook is in use, offer (don't insist) a `check_alignment`
   pass against the monthly layer.
4. Seed next week: draft 2–4 candidate themes from carry-over + the retro, present as
   a list for Monday's plan interview. Do not write next week's rows — Monday's
   interview owns that.

## Failure modes to avoid

- Writing rows before the interview converges — the DB is the record, not a scratchpad.
- Deleting or rewriting history on replan (supersede/park + Notes, always).
- A tag pass that only adds — stale `theme-current` tags from last week silently steer
  the worker at last week's priorities.
- Planning through vague outcomes because pushing back feels impolite (rule 3).
- Turning review into judgment. Facts, one retro line each, next week.
