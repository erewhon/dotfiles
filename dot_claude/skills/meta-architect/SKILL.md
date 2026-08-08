---
name: meta-architect
description: Run the coding pipeline's ARCHITECT role interactively — the session is the strong model. Inventory the repo (A0), author a framing proposal that may push back on the goal (A1), stop for explicit human approval, then decompose into a worker-shaped Forge task tree (A2) and emit it idempotently (A3). Use when the user wants to plan/decompose a big build ("architect this", "plan this epic", "decompose feature X into a task tree") for the forge coding pipeline. Triggered by /meta-architect. Distinct from `forge build plan`, which runs the same stages headlessly through the LLM router — this skill IS the interactive strong-tier path.
---

# meta-architect

> The interactive architect for the coding pipeline (`forge/coding_pipeline/` in
> `~/Projects/erewhon/forge`). Triggered by `/meta-architect`. Design:
> `meta/coding-pipeline-design.md`. **This session is the strong model** — you author the
> framing and the tree yourself; the library provides inventory, validation, persistence,
> and idempotent emission. Never hand-roll `create_task` calls.

## The iron rules

1. **Never emit before the human approves the framing.** The A1→A2 gate is absolute: file
   nothing into Forge — not even `--dry-run-emit` output presented as done — until the user
   has explicitly approved the framing in conversation AND `approved: true` is persisted.
2. **Push-back is your job, not an edge case.** If the inventory shows the goal duplicates
   existing work or solves the wrong problem, say so and propose the better framing
   (`rescoped: true`). The Nous "web parity" → Tauri-shim re-scope is the canonical example.
3. **Comma-free titles, always.** Forge `Depends On` cells split on commas; the models and
   emitter enforce it, but write titles clean from the start.
4. **Conservative autonomy tagging.** Routine mechanical leaves in well-tested areas →
   `Ready` + `Auto-OK` + `requires_tests=True` + `max_files ≤ 5` + `model_tier="auto"`.
   For any `requires_tests` leaf, `max_files` = named files + at least 2 headroom (its test
   file + one incidental), never below 3 — a budget at the named-file count reverts correct
   work the moment it adds its own test (deps-v2 waves 1-3, live; the library floors at
   `max(3, len(file_scope)+1)`).
   Anything with design latitude, on a safety path, or novel → `Manual`. Underspecified →
   `Spec Needed`. Known auto-tier failure signature: sound structure with plausible semantic
   inversions and tests asserting the bug — so safety-path code is never Auto.

## Steps

### A0 — Inventory

Work from the target repo. Collect and persist the inventory bundle (set `epic_slug` in the
goal spec — it keys the run dir and all refs):

```bash
uv run --directory ~/Projects/erewhon/forge python -c "
from pathlib import Path
from forge.coding_pipeline.inventory import collect_inventory, run_dir_for, write_inventory
from forge.coding_pipeline.models import GoalSpec
goal = GoalSpec.load(Path('<goal-spec.yaml>'))   # or construct inline
inv = collect_inventory(goal, repo=Path('<repo>').resolve())
print(write_inventory(inv, run_dir_for(goal)))
print(f'{len(inv.overlaps)} overlap(s), {len(inv.existing_tasks)} existing task(s)')
"
```

Read the written `inventory.md`. Study **Goal-term overlaps** and **Forge tasks already
filed** hard — they are the push-back evidence.

### A1 — Framing (author it yourself, then STOP)

Write the `FramingProposal` in-session: goal as stated vs your restated goal, `rescoped`
flag, inventory summary, gap analysis, 2–4 genuinely different options with tradeoffs, a
recommendation, **value ordering** (user-visible value ships first; polish last), risks, and
the epic slug. Persist via `persist_framing(proposal, run_dir)` (refuses to clobber an
existing framing without `force=True`) — construct the model in a `python -c` snippet or
write `framing.json` matching the schema plus `render_framing` for the `.md`.

**Then stop and present `framing.md` to the user.** Including — especially — when your
recommendation is "the goal as stated is wrong". Only after their explicit yes:

```python
from forge.coding_pipeline.architect import approve_framing
approve_framing(run_dir)   # the ONLY way approved flips to true
```

### A2 — Decompose (worker-shaped or human-owned, nothing in between)

Author the `LeafSpec` list yourself. Every leaf's `content` is a complete worker spec —
what/why, testable acceptance criteria, a files hint, test expectations — because the worker
sees nothing else. Self-check each leaf against the five worker-shaped criteria (single
concern; diff fits `max_files`; estimate ≤ m; suite-checkable acceptance; files named); a
leaf that fails is split further or terminally tagged `novel` + `Manual`. Wire `depends_on`
by exact title; group with a `Feature` name. Persist with `persist_tree(leaves, run_dir)`
and sanity-check `tree.md`. (The headless `decompose()` also runs an LLM boundedness panel —
in-session, your own judgment fills that seat, honestly.)

### A2.5 — Test-as-spec leaves (optional, routine leaves only)

For **routine** leaves with precisely testable behavior, prefer the test-as-spec variant:
the spec IS a committed failing test file, and the leaf's prose shrinks to a pointer.
Piloted 2026-07-30 (Pipeline-Smoke, 5/5 landed); do NOT use it for refactors, docs,
design-latitude, or safety-path leaves — those keep full prose specs.

**Authoring rules for the spec test file (each one is load-bearing):**

- One file per leaf (`tests/test_<leaf>.py`), with a module-level marker:
  `pytestmark = pytest.mark.xfail(reason="spec: pipeline:{epic}:{leaf} not implemented yet", strict=False)`
  — non-strict, so pre-existing-true assertions xpass instead of failing the suite.
- **Imports inside test bodies**, never at module level (an ImportError at collection
  bypasses xfail and breaks the whole suite).
- **Assertions ordering-independent across sibling leaves** — supersets, not exact sets;
  no counts a sibling's landing would change. Leaves must land in any order.
- A short docstring stating the worker rules: remove the pytestmark line, don't modify
  any test, full suite stays green.
- Commit ALL spec files in **one architect commit** on the epic bookmark
  (`pipeline/{epic_slug}`); verify `uv run pytest` stays green (xfailed/xpassed are fine).

**The leaf's `content` then becomes the canonical pointer block** — the first sentence is
parsed by the worker's objective gate, so keep it verbatim:

> **The spec for this task is the test file: `tests/test_<leaf>.py`.** Objective: make every
> test in that file pass.
> 1. Remove the module-level `pytestmark = pytest.mark.xfail(...)` line.
> 2. Implement until `uv run pytest` is fully green.
> 3. Do not modify, weaken, or delete any test in the spec file.

plus minimal notes (idiom pointers, known lint traps). An explicit `Spec-Test: <path>` line
works too. The objective gate (`forge/task_worker/objective.py`) enforces the rest:
marker gone, spec-file diff is marker-removal-only, and the file passes under
`pytest --runxfail` — suite-green alone is NOT objective-met (pilot escape: a side-effect
write landed a no-op session as Done before this gate existed).

### A3 — Emit (idempotent, dry-run first)

```python
from forge.coding_pipeline.emit import dry_run_emit, emit_tree
# 1. dry_run_emit(...) — show the user created/skipped/capped counts first
# 2. emit_tree(TaskTree(leaves=leaves), project='<Project>', epic_slug='<slug>',
#              runs_dir=settings.runs_dir)
```

Refs are `pipeline:{epic_slug}:{leaf-slug}` — re-emission only creates genuinely new leaves,
which is what makes replans cheap.

**A3 is not complete until the post-emit verification passes.** After `emit_tree` (every
time, even when the `EmitSummary` looks clean — this is the embedded verification loop):

1. `mcp__nous__lint_dependencies(project=...)` — catches unresolved, ambiguous, and
   comma-fragmented Depends-On cells.
2. `mcp__nous__resolve_tasks(refs=..., project=...)` over every Depends-On ref you just
   filed — each must resolve to exactly one row.
3. Repair any issue via `mcp__nous__update_task_fields` (`depends_on_remove` the damaged
   entries, `depends_on_add` the canonical `uuid:Title` form). Re-run the lint until clean.
4. Report the lint result (clean, or what was repaired) in your final summary.

Then finish with the handoff:
`forge build run <epic_slug> --project <Project>` runs the wave loop; `forge build gate
<epic_slug>` is the final sign-off; **a human merges to main — always**.

## Failure modes to avoid

- Emitting a tree for a framing the user "probably would approve". No. Stop and ask.
- Umbrella leaves ("implement the backend") — if you can't name the files, it isn't a leaf.
- Auto-OK on safety-path or shared-plumbing code because it "looks routine".
- Titles that collide with existing Forge tasks — check `inventory.md`'s existing-tasks list;
  emission dedups by ref, not by title.
