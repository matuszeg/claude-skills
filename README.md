# claude-skills

Portable, project-agnostic [Claude Code](https://claude.com/claude-code) skills
— generalized out of real project work so they can be reused anywhere.

## Skills

| Skill | Use when |
|---|---|
| [`session-wrap`](session-wrap/SKILL.md) | Ending a session / handing off / low on context — so the next session starts with zero carry-over confusion. |

## Install

Symlinks every skill here into `~/.claude/skills/` (Claude Code's personal
skills directory). Re-run after adding skills; safe to run repeatedly.

```sh
./install.sh
```

Skills are picked up by new Claude Code sessions. Update a skill by editing it
here and committing — the symlink means installed copies track the repo.
