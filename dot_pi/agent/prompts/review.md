---
description: Second-opinion review of the current changes by another model - /review [kimi|opus|fable|local|all] [what to review]
---
Get an independent code review using the subagent tool. Do NOT review the code yourself and do NOT change any files in this turn.

Reviewer choice: "$1" (if empty, use "kimi").
- kimi  -> agent "reviewer-kimi"
- opus  -> agent "reviewer-opus"
- fable -> agent "reviewer-fable"
- local -> agent "reviewer"
- all   -> run "reviewer-kimi", "reviewer-opus" and "reviewer-fable" with the subagent tool's parallel (tasks) mode

What to review: ${@:2}
If that is empty, the target is the uncommitted working-copy changes in this repository (or the latest commit if the working copy is clean).

Give each reviewer this task, filling in the blanks from this session: the repository path, what to review (above), and two or three sentences on what the change was supposed to accomplish, so it can check the diff against the intent. Do not include your own opinion of the code or tell it what you think is correct.

When the review comes back:
1. Show the findings as returned, grouped by reviewer. For "all", add a short merged list first, marking findings that more than one reviewer raised.
2. If a reviewer failed (for example a 403 token_scope_denied or a missing API key), say exactly that and which environment variable it needs (LLM_ROUTER_API_KEY with ZDR scope for kimi and opus; ANTHROPIC_API_KEY for fable). Do not silently fall back to another model.
3. Stop and ask me which findings to fix. Do not start fixing.
