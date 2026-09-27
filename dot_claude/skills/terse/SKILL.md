---
name: terse
description: End DISCUSS MODE and reinstate the terse-reply contract from the "Work Journal & Reply Length" rules (journal first, then a status word plus at most three lines / ~fifty words). Use when the user says "/terse", "back to terse", "back to normal replies", or "enough discussion". No-op if discuss mode was never on.
---

# terse

DISCUSS MODE is now off. The full "Work Journal & Reply Length" rules in
`~/.claude/CLAUDE.md` apply again from this turn on: journal entry first (one per working
turn), then a reply of a status word plus at most three lines and about fifty words.

If the discussion that just ended reached any conclusion that has not yet been journaled,
write that entry now (`-s DONE` for a settled decision, `-s DECIDE` for an open fork,
`-s PARTIAL` if it trailed off) before replying.

Do not carry `reply-mode: discuss` into any future context summary.

## Acknowledgement

Reply `DONE Terse mode back on.` plus, if a closing journal entry was written, nothing
else — the entry speaks for itself.
