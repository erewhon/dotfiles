---
name: week
description: The weekly-themes cadence — plan (Monday interview → theme rows → Forge cross-check → worker tag pass), replan (mid-week course correction with an audit trail), and review (Friday outcomes → retro → seed next week). Use when the user says "/week", "plan my week", "let's plan the week", "replan" / "something got dumped on me", or "weekly review". Reads and writes the Weekly Themes database in the Forge notebook, and promotes Horizon Backlog rows (Nous) into the week. Distinct from /today, which is the morning read-only briefing over what this skill writes.
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
- **Horizon Backlog** (Nous daily-notes notebook, `mcp__nous__backlog_*` tools): the
  personal intention tree by horizon (today → week → month → year → someday). Plan mode
  promotes rows into the week; review mode merges duplicates. Every backlog tool
  raises "has no Backlog configured" when the notebook has none — in both modes that
  is one line (`Backlog: not configured — skipping`) and the step is skipped, never an
  error. Backlog writes (`backlog_update`, `backlog_set_parent`, `backlog_touch`,
  `backlog_rate`) happen only after the user picks or confirms a specific row.

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
3. **Backlog candidates.** Two reads, presented as one short list (≤10 titles, with
   horizon and last touch) for the user to pick from — or pass on:
   - `backlog_query(orphans=True)` — rows with nothing above them, the intentions that
     never got a place;
   - `backlog_query(horizon="someday", stale=True)` — someday items whose review date
     has passed untouched.
   For each row the user picks: `backlog_update(row=<row_id>, horizon="week",
   surface_on=<this week's Monday>)`, then offer a parent from the current month rows
   (`backlog_query(horizon="month")`, titles only) and apply the choice with
   `backlog_set_parent(row=<row_id>, parent=<month row_id>)` — a 409 means a cycle;
   say so and leave the parent as is. A picked row that maps to a theme gets named in
   that theme's Notes (`"backlog: <title>"`). Nothing picked → move on, no write.
4. **Forge cross-check.** For each theme with Projects: `query_tasks(project=...,
   status="Ready")` (plus `get_feature_tasks` when the theme names a feature). A theme
   with no Ready tasks cannot start — either run the /forge-decompose rubric inline to
   file its leaves (with the user's yes), or record in Notes that it is
   interactive-only work. Say which.
5. **Overcommit check.** `recent_task_activity(since="7d")` — compare last week's actual
   landings against what this plan implies. If the plan is ~2× last week's throughput,
   say so plainly and let the user cut or accept knowingly.
6. **Write the rows** (`add_database_rows`, Status `active`).
7. **Worker tag pass.** Remove the `theme-current` tag from every task that still
   carries it (search `query_tasks` per last week's theme projects, then
   `manage_tags(remove="theme-current")` on their pages), then add it to the Ready
   tasks of this week's theme projects/features. The autonomous worker and `get_next_task`
   favor tagged work without any forge changes.
8. **Close.** One-paragraph summary: the themes, what has runway (Ready tasks), what
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
   Forge cross-check (plan step 4) for it.
4. Re-run the tag pass for the new active set.
5. Summarize what moved in ≤5 lines: new theme, what got parked/superseded, and the
   revised first block. No ceremony — a replan is supposed to be fast.

## `/week review`

1. Load the week's rows (all statuses). For each: what actually happened —
   `recent_task_activity(since="7d")` filtered to the theme's projects, plus the user's
   one-line self-report for prose-only themes.
2. Set Status (`done`, or leave `active` with a Notes line for honest carry-over) and
   append one retro sentence per row: what helped, what dragged.
3. **Backlog duplicates.** `backlog_duplicates()` (the weekly cluster pass) once it
   ships; until then, `backlog_query(status="open", limit=10)` newest-first and
   `backlog_similar(text=<title>)` on each — a result with `available: false` means
   the daemon has no vector index; one line and skip. Present each pair as one line
   with a merge suggestion: keep the row with the parent, the earlier due date, or the
   most touches (in that order); the other is the duplicate. On the user's yes per
   pair: `backlog_touch(row=<survivor>)` then `backlog_rate(row=<duplicate>,
   rating="drop")`. Never merge unasked; "not a dup" is a fine answer and needs no
   write.
4. If the Agile Results notebook is in use, offer (don't insist) a `check_alignment`
   pass against the monthly layer.
5. Seed next week: draft 2–4 candidate themes from carry-over + the retro, present as
   a list for Monday's plan interview. Do not write next week's rows — Monday's
   interview owns that.

## Failure modes to avoid

- Writing rows before the interview converges — the DB is the record, not a scratchpad.
- Deleting or rewriting history on replan (supersede/park + Notes, always).
- A tag pass that only adds — stale `theme-current` tags from last week silently steer
  the worker at last week's priorities.
- Planning through vague outcomes because pushing back feels impolite (rule 3).
- Turning review into judgment. Facts, one retro line each, next week.
- Promoting or dropping backlog rows the user didn't point at. Candidates are offered;
  the user picks; then the tool runs — one row at a time, never a batch "clean-up".
