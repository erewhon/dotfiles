---
name: discuss
description: Switch the session into DISCUSS MODE — suspend the terse-reply budget (status word, three lines, ~fifty words) from the "Work Journal & Reply Length" rules and hold a normal conversational back-and-forth for working out architecture, trade-offs, or design. Use when the user says "/discuss", "let's talk this through", "let's think about the design", or wants a conversation rather than a work order. Stays on for the rest of the session until "/terse" is invoked. The journal rule stays on; only its cadence changes.
---

# discuss

DISCUSS MODE is now on. It stays on for the rest of this session until the user invokes
`/terse`. If a context summary is ever written, carry the line `reply-mode: discuss` into it
so the mode survives compaction.

## What changes

The reply-length rules in `~/.claude/CLAUDE.md` ("Work Journal & Reply Length" → "The
reply", "Questions and explanations") are **suspended**:

- No status word, no three-line / fifty-word budget.
- Talk the way you would with a colleague at a whiteboard: lay out the options, name the
  trade-offs, give an opinion and the reasoning behind it, ask a question when the answer
  actually changes the design. Push back when something looks wrong.
- Length matches the question. A one-line question still gets a one-line answer; a
  design question gets the full argument in chat, not a pointer to the journal.
- Do not open with a recap of what was just said, and do not close with a menu of
  offers. Markdown headings and tables only when they carry structure the prose cannot.

## What does not change

- **The journal stays on.** Its cadence changes: append one entry when the discussion
  reaches a conclusion, a decision, or a fork the user has to resolve — not every turn.
  Use `-s DECIDE` for an open fork and `-s DONE` for a settled decision; put the options
  considered and the reasoning under `**Found:**` so the record can be reread later. If
  the session ends mid-discussion with nothing settled, write one `PARTIAL` entry
  capturing where it stands.
- **"What the reply must still carry"** still applies: a failing test, a skipped step, an
  unrequested change, an external action, or a destructive action stopped short of is
  said in chat, in discuss mode as in terse mode.
- **Mid-turn text** rule still applies while running tools: no "I'll now…", no progress
  narration between tool calls.
- If the user hands over concrete work mid-discussion ("ok, build it"), do the work,
  report it conversationally, and stay in discuss mode. They will invoke `/terse` when
  they want the terse contract back.

## Acknowledgement

On invocation, reply with one short line confirming discuss mode is on, then answer
whatever the user asked in the same message, if anything.
