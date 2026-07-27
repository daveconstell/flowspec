#!/usr/bin/env bash
# Install the FlowSpec authoring skill into both agent skill directories.
# Usage: ./install-skill.sh [root]    root defaults to $HOME (global); pass a
#                                     project path for a project-local install.
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)/public/SKILL.md"
root="${1:-$HOME}"

for dir in .claude/skills .agents/skills; do
  dest="$root/$dir/flowspec"
  mkdir -p "$dest"
  cp "$src" "$dest/SKILL.md"
  echo "installed → $dest/SKILL.md"
done
