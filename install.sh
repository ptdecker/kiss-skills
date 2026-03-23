#!/usr/bin/env bash
#
# KISS Skills installer
#
# Clones (or updates) the kiss-skills repo and symlinks each skill into
# ~/.claude/skills/ so Claude Code can discover them. Because the skills
# are symlinked rather than copied, running `git pull` inside the clone
# directory is all that's needed to pick up future updates.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ptdecker/kiss-skills/main/install.sh | bash
#
# Or clone the repo yourself and run:
#   ./install.sh
#
# Options:
#   KISS_SKILLS_DIR  Override the clone location (default: ~/.kiss-skills)

set -euo pipefail

REPO_URL="https://github.com/ptdecker/kiss-skills.git"
CLONE_DIR="${KISS_SKILLS_DIR:-$HOME/.kiss-skills}"
SKILLS_TARGET="$HOME/.claude/skills"

# --- helpers ----------------------------------------------------------------

info()  { printf '  \033[1;34m->\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m->\033[0m %s\n' "$*"; }
err()   { printf '  \033[1;31m->\033[0m %s\n' "$*" >&2; }

# --- clone or update --------------------------------------------------------

if [ -d "$CLONE_DIR/.git" ]; then
  info "Updating existing clone at $CLONE_DIR"
  git -C "$CLONE_DIR" pull --ff-only --quiet
else
  if [ -d "$CLONE_DIR" ]; then
    err "$CLONE_DIR exists but is not a git repo. Remove it first."
    exit 1
  fi
  info "Cloning kiss-skills into $CLONE_DIR"
  git clone --quiet "$REPO_URL" "$CLONE_DIR"
fi

# --- symlink skills ---------------------------------------------------------

mkdir -p "$SKILLS_TARGET"

linked=0
for skill_dir in "$CLONE_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_TARGET/$skill_name"

  if [ -L "$target" ]; then
    # Already a symlink — update it in case the clone moved
    rm "$target"
  elif [ -e "$target" ]; then
    err "Skipping $skill_name: $target already exists and is not a symlink"
    continue
  fi

  ln -s "$skill_dir" "$target"
  ok "Linked $skill_name"
  linked=$((linked + 1))
done

echo ""
ok "Done — $linked skill(s) installed."
info "Skills are symlinked from $CLONE_DIR"
info "To update later: cd $CLONE_DIR && git pull"
