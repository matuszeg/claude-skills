---
name: session-wrap
description: Use at the end of any working session before context is abandoned or a new session starts — when handing off, "wrapping up", running low on context, or switching tasks/sessions and the next session must continue with zero carry-over confusion.
---

# Session Wrap

## Overview

Closes a session so the next one starts cold with zero residual confusion. The
failure this prevents: a wrap that *summarizes* the session instead of
*durably persisting* its state — leaving stale memory, unverified git claims,
and a handoff the user can't actually act on.

**Core principle:** Anything the next session needs must live in a durable
channel (CLAUDE.md, the memory directory, the issue tracker) **or** in the one
copyable handoff block — never only in this session's prose, never in invented
throwaway files.

**Project-agnostic.** This skill assumes nothing about planning-doc layout. If
the project has planning/spec/decision docs, discover them (ask or inspect)
and treat them as another durable channel. Do not invent project structure.

## When to Use

- Ending a session; user says "wrap up", "hand off", "new session", "we're done for now"
- Context budget running low and work must continue elsewhere
- Switching to an unrelated task and want a clean break

Not for: mid-task checkpoints where work continues in the same session.

## The Checklist

Create a TodoWrite item per step. Work them in order. Do not skip.

### 1 — CLAUDE.md current state
Open CLAUDE.md (and AGENTS.md/GEMINI.md if present). Find or add a brief
"current state / next" note: what just completed, what's in progress, the
exact next action. Make it accurate to *now*. Edit in place (CLAUDE.md is
typically not committed — confirm the project's convention, don't assume).

### 2 — Capture new facts to memory
For everything decided/learned this session not already in memory, write a
memory file of the right type — `user` (who they are/preferences),
`feedback` (how you should work + why), `project` (state/decisions/constraints
not derivable from code or git), `reference` (external resource pointer).
Convert relative dates to absolute. Add one pointer line per file to the
memory index (`MEMORY.md`); never write memory content into the index itself.
If the project has no memory directory, say so and put durable facts in the
agreed docs instead — do not silently skip capture.

### 3 — Memory audit & deletion candidates (single pass)
**Default scope:** Only audit memory files that were read, written, or
referenced during this session — these are the ones most likely to be stale.
Skim MEMORY.md to identify them.

**Full scope (`--full-audit` arg):** Inspect every memory file body. Use this
periodically (e.g. every few sessions) to catch drift in files untouched by
recent work.

For each file in scope, read its **body** (not just the index line) and in one
pass determine:
- Whether the body is current — fix stale claims (merged PRs still marked
  "pending", completed actions still marked "in progress", renamed fields,
  outdated "as of" dates) by editing in place.
- Whether the file is a deletion candidate — superseded snapshots, vigilance
  notes for failure modes now structurally prevented, spent per-iteration
  artifacts. For each candidate: file, one-line content, why eligible, risk of
  keeping, where the value survives otherwise.

**Required output:** a per-memory disposition list — one line per file
inspected, each marked `unchanged` / `body-updated` / `index-updated` /
`deletion-candidate`. If you cannot produce this list you did not do the audit.

**Hard rule: never delete a memory or section without explicit per-item user
approval.** "Yes earlier" does not carry across files. If the user is absent,
record candidates as a `project` memory and move on.

### 4 — Loose threads & informal decisions
List every thread raised but unresolved: open questions, decisions discussed
not made, work identified not started, follow-ups mentioned in passing, and
any in-the-moment implementation/tooling/naming choices not formally recorded.
For each, either resolve now, file it in the project's tracker/decision doc,
or capture it in a `project` memory. A thread is only "not loose" once you
confirm it is tracked somewhere durable.

### 5 — Git hygiene (verify, never assert)
Run the commands; do not state status from memory:
`git status --porcelain`, `git branch -vv`, and `gh pr list` (or the host
equivalent) for the repo(s) touched. **Surface findings in your response now**
— dirty tree, branches, open PRs waiting on the user — the present user can
act; memory is for the future. Auto-delete cleanly-merged branches with
`git branch -d` (it refuses unmerged work, so it is safe; never `-D`; never
the current branch or default branch). Report per repo: deleted branches, or
"none". Any branch `-d` refuses, or any open PR, is surfaced explicitly, not
just logged.

### 6 — Next-session handoff (single copyable block)
Emit ONE ` ```text ` fenced block, nothing required after it, written as an
imperative directive prompt addressed to the next session (not a status
report about this one). It contains exactly:
1. The first concrete action (specific skill/command/task).
2. Gating: PRs that must merge / sign-offs needed before that action, or "none".
3. Context NOT already in CLAUDE.md / project docs / memory, or "none".
Anything already durably captured gets at most a one-line pointer — the block
is the pendulum that starts the next session, not a re-summary. Do not write
this block to a file; it is a one-use artifact that expires when pasted.

## Red Flags — you are doing it wrong

| Symptom | Correction |
|---|---|
| "Nothing important happened, skip memory" | Every session yields ≥1 `feedback`/`project` memory. Capture it. |
| Memory audit done as a filename/topic scan | Inspect file *bodies*. The per-memory disposition list is the proof. |
| "No deletion candidates" without looking | Actually inspect first; then "no candidates" is allowed. |
| Deleting memory because rationale "seems airtight" | Never without explicit per-item user approval. |
| `git status` clean ⇒ git hygiene done | Also check branches and PRs; verify by running, not asserting. |
| Stating git/PR state without running commands | Fabricated certainty. Run the commands. |
| Handoff as prose, or split prose+code, or written to a file | One copyable ```text block, in the response, nothing after it. |
| Inventing `SESSION_WRAP.md`/throwaway docs for handoff | Durable channels + the one block only. No invented files. |
| "We'll pick this up later" with no tracking | Every loose thread lands in tracker/decision doc/memory before ending. |
| Findings written only to memory and called "flagged" | User is present now — surface in the response. |

## Definition of Done

All 6 steps done. Next session can start from CLAUDE.md + project docs +
memory + the handoff block alone, with no need to read this session. Every
item needing user action was surfaced in the response, not only in memory.
