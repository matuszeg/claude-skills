#!/bin/sh
# Symlink every skill in this repo into ~/.claude/skills/ so Claude Code
# sessions discover them. Idempotent: re-run any time.
set -e
repo="$(cd "$(dirname "$0")" && pwd)"
dest="${HOME}/.claude/skills"
mkdir -p "$dest"

for d in "$repo"/*/; do
  name="$(basename "$d")"
  [ -f "$d/SKILL.md" ] || continue
  ln -sfn "$d" "$dest/$name"
  echo "linked $name -> $dest/$name"
done

echo "done. new Claude Code sessions will see these skills."
