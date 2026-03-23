#!/usr/bin/env bash
#
# KISS Skills uninstaller
#
# Removes symlinks from ~/.claude/skills/ that point into the kiss-skills
# clone, then optionally removes the clone directory itself.
#
# Usage:
#   ./uninstall.sh
#
# Options:
#   KISS_SKILLS_DIR  Override the clone location (default: ~/.kiss-skills)

set -euo pipefail

CLONE_DIR="${KISS_SKILLS_DIR:-$HOME/.kiss-skills}"
SKILLS_TARGET="$HOME/.claude/skills"

info()  { printf '  \033[1;34m->\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m->\033[0m %s\n' "$*"; }

removed=0
for link in "$SKILLS_TARGET"/*/; do
  [ -L "${link%/}" ] || continue
  target="$(readlink "${link%/}")"
  case "$target" in
    "$CLONE_DIR"/*)
      rm "${link%/}"
      ok "Removed $(basename "${link%/}")"
      removed=$((removed + 1))
      ;;
  esac
done

echo ""
ok "Removed $removed symlink(s) from $SKILLS_TARGET"
echo ""
info "The cloned repo at $CLONE_DIR was left in place."
info "To remove it entirely: rm -rf $CLONE_DIR"
