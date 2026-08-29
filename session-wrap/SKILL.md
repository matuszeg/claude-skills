---
name: session-wrap
description: Use at the end of any working session before context is abandoned or a new session starts — when handing off, "wrapping up", running low on context, or switching tasks/sessions and the next session must continue with zero carry-over confusion.
allowed-tools: Bash(git status*), Bash(git branch*), Bash(gh pr list*)
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

**Memory holds durable, non-derivable facts** — decisions + their rationale, ops
techniques, conventions, gotchas. **Status, work, and history belong to the issue
tracker, VCS, and CI — memory POINTS to them, never re-narrates them.** Do NOT
write "PR #X open → merged → deployed", commit SHAs, gate/coverage numbers, or an
enumerated issue backlog into a memory file; the tracker and `git log` already
own those, and they churn every session. Smell test: if you'd find a fact via
`git log` / `gh` / the project board, link to it, don't copy it. When a fact's
*status* changes, **edit the existing line in place — never append a new stanza.**
A "state" memory must read as current state, not a session-by-session changelog;
that drift is the single biggest source of memory bloat.

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
- Whether the file has **drifted into a changelog** — a "state" memory that has
  accumulated session-by-session status narration (PR/issue transitions, SHAs,
  gate numbers, a duplicated backlog) is bloated by construction. Flag it as a
  **consolidation candidate**: keep the durable core (decisions/ops/gotchas),
  replace the status narration with pointers to the tracker/VCS. A heavy
  consolidation is high-impact, so surface it for approval like a deletion
  candidate (the per-item-approval rule applies before a big rewrite).

**Required output:** a per-memory disposition list — one line per file
inspected, each marked `unchanged` / `body-updated` / `index-updated` /
`deletion-candidate` / `consolidation-candidate`. If you cannot produce this list
you did not do the audit.

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

### 5b — Push the memory repo (multi-machine sync)
If the project's memory directory is a git working tree, the memories written in
steps 2–3 exist only on this machine until they are pushed. Commit and push
them, and surface the result:

```
git -C <memory-dir> add -A
git -C <memory-dir> commit -m "<session topic>: <what changed>"
git -C <memory-dir> pull --rebase --autostash && git -C <memory-dir> push
```

A `SessionStart` hook pulls at the start, so the common case is fast-forward.
`MEMORY.md` carries a `merge=union` attribute, so index appends from two
machines auto-merge — **read the merged index afterwards** and remove any
duplicate or contradictory pointer lines the union produced. A genuine conflict
in a memory *body* is Actionable: surface it, do not resolve it by picking a
side silently.

If the directory is not a git tree, skip this step without comment.

### 6 — Present the wrap in two sections (Actionable, then Informational)
Everything surfaced by steps 1–5 goes into the response under two
clearly-labeled headings, in this order:

**Actionable** — anything the user must do, must decide, or must see because it
is or could be acted upon. Route here: deletion candidates awaiting per-item
approval (step 3), loose threads still needing a decision or an owner (step 4),
a dirty working tree, any branch `git branch -d` refused, open PRs waiting on
the user (step 5), any failing test the user should know about (including
pre-existing or unrelated ones — surface it, do not bury it as "not mine"), and
any open question raised this session. If there is genuinely nothing, write
"Actionable: none" — but only after checking.

**Informational** — state now durably captured that needs no action, for
awareness only. Route here: the CLAUDE.md current-state note (step 1), memories
written (step 2), the per-memory audit disposition list (step 3), branches
auto-deleted (step 5), and where each loose thread was filed (step 4).

Put each item under exactly one heading. When unsure which, put it under
**Actionable** so it cannot be missed.

### 6b — Walk the Actionable items ONE AT A TIME
Do not end the wrap on the list. After presenting both sections, take the
Actionable items in order, one per message: state the item, what you think
should happen, and stop for the user's answer. Move to the next only when they
say so. A list of five decisions delivered at once gets skimmed and half of it
is silently dropped; one at a time is how each actually gets a decision.

- **Re-check each item the moment you reach it.** Anything that resolved itself
  since you wrote the list — a hook that has now fired, a check that has since
  passed — is reported as resolved and closed, not re-raised. Repeating an item
  you already have the evidence against is how the section loses its meaning.
- **Say what you would do**, do not just re-read the item back. Each one ends in
  a decision, a "yours to run", or a closure.
- If an item is genuinely the user's to run elsewhere, confirm that and move on;
  do not stall the walk waiting for them to do it.
- Emit the handoff block (step 7) only after the last item is closed, so it
  reflects the decisions just made rather than the state before them.

### 7 — Next-session handoff (single copyable block)
After both sections, emit ONE ` ```text ` fenced block, nothing required after
it, written as an imperative directive prompt addressed to the next session
(not a status report about this one). It contains exactly:
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
| One undifferentiated list of findings | Split the response into **Actionable** then **Informational** before the handoff block. |
| Actionable item buried under Informational | When unsure, it goes under Actionable. Decisions, approvals, dirty git, open PRs are always Actionable. |
| Actionable list presented as one block and the wrap ends | Walk the items one at a time (step 6b). Each gets its own message and its own decision. |
| Re-raising an item that resolved itself before you reached it | Re-check at the moment you reach it; report it resolved and close it. |
| Handoff as prose, or split prose+code, or written to a file | One copyable ```text block, in the response, nothing after it. |
| Inventing `SESSION_WRAP.md`/throwaway docs for handoff | Durable channels + the one block only. No invented files. |
| "We'll pick this up later" with no tracking | Every loose thread lands in tracker/decision doc/memory before ending. |
| Findings written only to memory and called "flagged" | User is present now — surface in the response. |
| State memory reads as a session-by-session changelog (PR/issue status, SHAs, gate numbers, duplicated backlog) | The tracker + `git`/CI own status & history. Memory holds durable facts and *points*. Edit a "current" line in place; never append a per-session log. |

## Definition of Done

All 7 steps done. The response presents an **Actionable** section then an
**Informational** section; every Actionable item has been walked one at a time
and closed; the handoff block comes last. Next session can
start from CLAUDE.md + project docs + memory + the handoff block alone, with no
need to read this session. Every item needing user action appears in the
Actionable section, not only in memory.
