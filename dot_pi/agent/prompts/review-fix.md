---
description: Review by another model, then apply the Critical and Warning findings - /review-fix [kimi|opus|fable|local|all] [what to review]
---
Do the same as the /review prompt would with reviewer choice "$1" (default "kimi") and target: ${@:2} (default: the uncommitted working-copy changes): dispatch the matching reviewer agent ("reviewer-kimi", "reviewer-opus", "reviewer-fable", "reviewer", or all three cloud reviewers in parallel) with the subagent tool, without reviewing the code yourself.

Then, in this session, fix the Critical and Warning findings you can confirm in the code. For each finding say fixed, or not fixed and why (could not reproduce, disagree, out of scope). Leave Suggestions alone unless trivial. Run the relevant tests afterwards and report the result. Do not commit.
