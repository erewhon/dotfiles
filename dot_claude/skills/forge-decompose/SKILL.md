---
name: forge-decompose
description: Decompose a goal, epic, or feature into a worker-shaped Forge task tree (epic → features → routine leaves) and file it via create_task — project-agnostic, no coupling to `forge build`. Use when the user wants to break a big or under-spec'd piece of work into tasks and file them into Forge ("decompose this into tasks", "break this epic into features and leaves", "spec this out into Forge", "turn this into a task tree"). Triggered by /forge-decompose. Distinct from /meta-architect, which runs the same decomposition but is bolted to the forge coding pipeline (inventory/emit library, `pipeline:{epic}:{leaf}` refs meant for `forge build run`). Use THIS one for any project whose tasks won't flow through `forge build`.
---

# forge-decompose

> The portable decomposition rubric, extracted from the coding pipeline's ARCHITECT A2 stage
> (`forge/coding_pipeline/architect.py:DECOMPOSE_SYSTEM` in `~/Projects/erewhon/forge`). It files
> straight into Forge with plain `create_task` — **no** pipeline library, **no** `pipeline:*` refs,
> **no** `forge build` coupling. **This session is the strong model**: you author the tree yourself;
> the rubric below is your standard, and `create_task` is your only filing tool.
>
> For work that WILL be driven by `forge build run` (the forge coding pipeline), use `/meta-architect`
> instead — it adds A0 inventory, a persisted human-approval gate, and idempotent `emit_tree`.

## The iron rules

1. **Comma-free titles, always.** Forge's `Depends On` cell splits on commas; a title with a comma
   silently breaks dependency wiring. Write every title clean.
2. **Conservative autonomy tagging.** Only routine, mechanical leaves in well-tested areas get
   `Auto-OK`. Anything with design latitude, on a safety path, on shared plumbing, or novel →
   `Manual`. Underspecified → `Spec Needed` + `Manual`. The known auto-tier failure signature is
   *sound structure with plausible semantic inversions and tests that assert the bug* — so
   safety-path code is never Auto, however routine it looks.
3. **Confirm before filing.** `create_task` writes real rows. Present the full tree in
   conversation and get an explicit yes before you file anything. (There's no persisted-approval
   file here — the confirmation is conversational, unlike /meta-architect's hard gate.)
4. **`create_task` only — never `update_database_rows` for tasks.** It resolves the `Depends On`
   `uuid:Name` form for you and enforces the comma rule; the row-UUID path does neither.

## How the three levels map onto Forge

Forge has no separate "epic" or "feature" row type. The tree is expressed as:

- **Epic** → the shared framing. Represent it either as the common `feature` string, or (for
  something big and long-lived) as one umbrella tracking task tagged `Manual` that the real work
  depends on. Don't over-engineer this — usually a shared `feature` name is enough.
- **Feature** → the `feature=` field on each leaf. Leaves with the same `feature` group together.
- **Leaf** → one `create_task` call. This is the unit of work. Everything below is about making
  each leaf *worker-shaped*.

`depends_on` (a comma-separated string of exact leaf titles) encodes ordering across the whole tree,
depth 3 max: epic → features → leaves.

## Steps

### 1 — Scope check (lightweight)

Before decomposing, make sure you're not duplicating or mis-scoping. Search Forge for the target
project:

- `mcp__nous__task_summary(project=...)` — counts and shape.
- `mcp__nous__query_tasks(project=..., ...)` and `mcp__nous__search_pages(query=...)` — look for
  leaves that already cover this, or a feature that's already partly planned.
- `mcp__nous__get_feature_tasks(project=..., feature=...)` if a matching feature already exists.

If the inventory shows the goal already exists, fights the wrong battle, or is scoped wrong,
**say so and propose the better framing before decomposing** — don't silently plan the stated goal.
(This is the compressed A0+A1 — no persisted artifact, just an honest paragraph in chat.) If the
project doesn't exist yet, note it; you'll `create_project(name)` in step 3.

### 2 — Decompose (the rubric)

Author a flat list of leaves whose `depends_on` encodes the tree (depth 3 max). Every leaf must be
**WORKER-SHAPED — all five criteria:**

1. **single concern**, no unresolved design choice left inside it;
2. expected diff fits `max_files` (**≤ 5 files**);
3. `estimate` is **xs, s, or m**;
4. acceptance criteria **checkable by the project's test suite**;
5. the spec **names its target files/modules**.

A leaf that can't meet all five is tagged `complexity="novel"` + `execution_mode="Manual"` — *"a
human does this one"* is a valid terminal state, not a failure. **No vague umbrella leaves** — if
you can't name the files, it isn't a leaf; split it or mark it novel/Manual.

Each leaf's `content` is a **complete worker spec** (the worker sees nothing else):
- what/why — one short paragraph;
- acceptance criteria — bulleted, testable;
- a files hint — which files/modules it touches;
- test expectations — what proves it done.

**Conservative autonomy tagging** (see iron rule 2):
- routine mechanical leaf in a well-tested area → `status="Ready"`, `execution_mode="Auto-OK"`,
  `requires_tests=True`, `max_files ≤ 5`, `model_tier="auto"`;
- design latitude / safety path / shared plumbing / novel → `execution_mode="Manual"`;
- underspecified → `status="Spec Needed"` + `execution_mode="Manual"`.

**max_files headroom for test-bearing leaves:** when `requires_tests=True`, set `max_files` to
the files the spec names **plus at least 2** (its test file + one incidental — a fixture, an
`__init__`, a config touch), never below 3. A budget equal to the named-file count reverts
correct work the moment it adds its own test (deps-v2 waves 1-3, live). The library floors this
at `max(3, len(file_scope)+1)`, but write it right rather than lean on the floor.

**Ordering:** `priority` encodes value ordering — user-visible value first (priority 2–3), the
infrastructure it depends on the same, polish last (5–6). Group related leaves under one short
`feature` name. Sibling leaves that share an interface should say so in their specs (a leaf can't
see its siblings), so name the contract in the `content` rather than assuming the worker infers it.

### 3 — Present, then file

Show the user the tree first: titles, `feature` groups, `depends_on` edges, and the autonomy tag on
each leaf (Ready+Auto-OK vs Manual vs Spec Needed). **Get an explicit yes.** Then, and only then:

- `mcp__nous__create_project(name)` if the project doesn't exist yet.
- One `mcp__nous__create_task(...)` per leaf. Pass the real params — the signature is:
  `create_task(project, title, content, priority=5, phase="Feature", depends_on=None,
  status="Ready", feature=None, external_ref=None, tags=None, execution_mode=None,
  model_tier=None, estimate=None, complexity=None, task_type=None, max_files=None,
  requires_tests=None)`. `depends_on` is a **comma-separated string of exact titles** (comma-free
  titles make this unambiguous). `phase` is one of Feature/Infrastructure/Polish/Bugfix/Launch.
- **File in dependency order** — a leaf's `depends_on` titles must already exist as rows when you
  create it, so create prerequisites first (topological order). It returns a `row_id`.

### 4 — Verify the filing (mandatory — filing is not done until this passes)

Run this after every filing pass, even when every `create_task` returned clean (the warnings
field can be empty while a dep still resolved wrong):

1. `mcp__nous__lint_dependencies(project=...)` — unresolved, ambiguous, and comma-fragmented
   Depends-On cells across the rows you just wrote.
2. `mcp__nous__resolve_tasks(refs=..., project=...)` over every Depends-On ref you filed —
   each must resolve to exactly one row.
3. Repair via `mcp__nous__update_task_fields` (`depends_on_remove` the damaged entries,
   `depends_on_add` the canonical `uuid:Title` form). Re-run the lint until it reports zero
   issues.

Report the created rows back (count, and which are Ready+Auto-OK vs Manual vs Spec Needed)
**and the dependency-lint result** (clean, or what was repaired), then point at what's next:
`mcp__nous__get_next_task(project=...)` surfaces the highest-priority unblocked leaf.

## Failure modes to avoid

- **Filing before the user says yes.** These are real rows. Present, confirm, then file.
- **Umbrella leaves** ("implement the backend") — if you can't name the files, it isn't a leaf.
- **Auto-OK on safety-path or shared-plumbing code** because it "looks routine". Tag it Manual.
- **Titles with commas** — they break `Depends On` wiring silently.
- **Reaching for `update_database_rows`** to set deps or status — use `create_task`'s params.
- **Planning the stated goal when the inventory says it already exists** — push back first.
