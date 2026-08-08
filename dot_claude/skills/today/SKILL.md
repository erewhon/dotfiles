---
name: today
description: The morning briefing over the weekly themes — where each theme stands, what landed overnight, what's waiting on the user, and one suggested first block. Use when the user says "/today", "what's the plan today", "morning briefing", "what did I say we need to do for <project/job>", or "let's start on <theme>". Read-only over the Weekly Themes database (written by /week) plus Forge task activity. Distinct from /week, which plans and replans; /today never writes theme rows.
---

# today

> The morning half of the weekly-themes system (design: meta/architecture-discussion.md,
> 2026-07-30). Answers two questions with zero warm-up: *"what did I say we need to do
> for X?"* and *"what should I start on?"* — then gets out of the way.

## Contract

- **Read-only** on the Weekly Themes database. If the situation calls for changing the
  plan, say one line and hand off: "that's a replan — run `/week replan`."
- **≤40 lines of output.** Directional, not a dashboard dump. Every line earns its place.
- **Gentle on drift.** At most one neutral sentence about off-theme work, ever, and only
  when yesterday's activity was clearly outside every active theme. Offer file-or-continue
  once; drop it after the user chooses.
- **After-hours work isn't drift.** Off-theme activity timestamped outside the 8am–6pm
  weekday band (evenings, early mornings, weekends) is ad-hoc time — report it in
  Overnight as plain information, no drift sentence, no file-or-continue. Only
  working-hours off-theme activity is a drift candidate.

## Build the briefing

1. **Themes.** `get_database(notebook="Forge", database="Weekly Themes")`, filter to the
   current week (most recent Monday). No rows → two lines: say so, suggest `/week plan`,
   stop. Parked/superseded rows get one combined line at the end of this section, not
   paragraphs.
2. **Overnight.** `recent_task_activity(since="24h")` (use `"72h"` on Mondays), grouped
   under the theme whose Projects match; landings (Done transitions) first. Activity
   matching no theme AND timestamped inside working hours is the drift candidate — see
   Contract (including the after-hours exemption) before mentioning it.
3. **Waiting on you.** The oversight queue, in order:
   - Open **waitpoints**, once Waitpoint tokens ships (Wave Control Primitives) — that
     becomes the primary source. Until then, fall back to:
   - `query_tasks(status="Spec Needed")` rows whose pages say "Escalated by the pipeline"
     (limit to theme projects), and
   - `query_tasks(status="In Progress", execution_mode="Manual")` in theme projects —
     work parked on the user's own plate.
   For `check-ins`-oversight themes this section IS the review queue; lead with it when
   non-empty.
4. **First block.** ONE suggestion, chosen by: hard deadline in a theme's Outcome/Notes >
   non-empty review queue > the highest-priority theme with an unblocked task
   (`get_next_task(project=...)`). Name the concrete task, not the theme. If the user
   says "start on <theme>" instead, resolve it the same way for that theme and go.

## Section shape (target)

```
Week of <date> — <n> active themes
● <Theme> — <one-line status: outcome progress, overnight landings>
● <Theme> — …
  (parked: <theme>; superseded: <theme> — see /week review)

Waiting on you (<n>): <item> · <item>

Overnight: <2-4 lines, grouped by theme, only if anything happened>

First block → <task title> (<project>): <why in one clause>
```

## Answering the direct questions

- *"What did I say we need to do for X?"* — quote X's theme row (Outcome, Oversight,
  Status, relevant Notes) plus its Ready-task count. Don't re-interview; if X has no row
  this week, say so and offer `/week replan` to add it.
- *"Let's start on X"* — `get_next_task` for X's project(s), restate the task's
  acceptance in one line, and begin. That's the whole handoff.

## Contract-job live signals (CFA)

When an active theme's Projects include the contract job (CFA), pull live tracker state
into that theme's paragraph. Everything routes through the `work-cfa` VM — the local
machine's `gh` token is not SSO-authorized for the `cfacorp` org, and the Jira token only
exists there. The Jira token loads via interactive zsh only, hence `zsh -ic` and the
`2>/dev/null` (which also eats zle noise from non-tty sessions).

**Preflight** (skip everything below on failure, with one line in the theme paragraph —
"work-cfa VM unreachable — no live CFA signals"; never break the briefing):

```
ssh -o BatchMode=yes -o ConnectTimeout=8 work-cfa.m.bcc.sh true
```

**Jira — my open issues** (show ≤5, In Progress first, as `KEY summary`):

```
ssh -o BatchMode=yes work-cfa.m.bcc.sh 'zsh -ic "jira issue list \
  --jql \"assignee = currentUser() AND statusCategory != Done\" \
  --plain --no-headers --columns key,status,summary" 2>/dev/null'
```

**GitHub — PRs awaiting my review, then my open PRs** (≤5 each; flag my PRs only when
`updatedAt` is within ~3 days — fresh activity, not a stale backlog dump):

```
ssh -o BatchMode=yes work-cfa.m.bcc.sh 'zsh -ic "gh search prs --owner cfacorp \
  --state open --review-requested @me --limit 5 \
  --json repository,number,title --jq \
  \".[] | .repository.nameWithOwner + \\\"#\\\" + (.number|tostring) + \\\" \\\" + .title\"" 2>/dev/null'

ssh -o BatchMode=yes work-cfa.m.bcc.sh 'zsh -ic "gh search prs --owner cfacorp \
  --state open --author @me --limit 5 \
  --json repository,number,title,updatedAt --jq \
  \".[] | .repository.nameWithOwner + \\\"#\\\" + (.number|tostring) + \\\" \\\" + .title + \\\" ~\\\" + .updatedAt[:10]\"" 2>/dev/null'
```

Render inside the CFA theme's paragraph, compressed: `Jira: ROHQ-1788, ROHQ-1741 in
progress (+3 open) · Review queue: 5 PRs on food-safety-report-api`. A command that
returns nothing means an empty queue — say nothing, don't pad. A command that errors
gets one per-source clause ("Jira unreachable"), same never-break rule.

## Full-time job signals (work journal)

The full-time job has no reliable trackers (Jira unreliable, much work untracked,
email/Teams browser-only) — the feed is the user's own journal, written from the
personal laptop via `work-eod` and stored at `~/Projects/erewhon/work-journal/journal.md`
(flat `- YYYY-MM-DD (Day) HH:MM: text` lines, append-only; this laptop is the only
writer, so read the file directly — no pull, no network):

```
tail -5 ~/Projects/erewhon/work-journal/journal.md
```

When an active theme is the full-time job, render the most recent entry into its
paragraph: `last note (Thu): migration PR up; blocked on DBA review`. Staleness is a
signal, not an error: if the newest entry is 2+ weekdays old, add one neutral clause —
"no journal note since Tue — `work-eod` a line when you get a chance" — at most once,
same never-nag contract as drift. File missing → one-line notice ("work journal not
found"), never break the briefing. The journal is also cloneable read-only at work over
the usual code-mesh HTTP channel; that's for reading there, never a write path.

## Failure modes to avoid

- A 100-line briefing. Compression is the feature; the user can always ask for more.
- Mentioning drift twice, or mentioning it at all when the day simply had urgent work.
- Suggesting a first block from a blocked or Spec Needed task — `get_next_task` exists
  precisely to avoid this.
- Writing anything to the themes DB (that's /week's job, including all replans).
- Fabricating a briefing when the daemon is down — say the store is unreachable and
  fall back to `recent_task_activity` alone if it works, or stop cleanly.
