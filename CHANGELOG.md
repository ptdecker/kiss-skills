# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.0] - 2026-03-25

### Added

- **review-peer** skill – interactively triage and respond to unresolved human peer review comments on a PR. Fixes
  valid issues, replies on GitHub, and leaves threads open for the reviewer to resolve.

## [1.1.2] - 2026-03-23

### Fixed

- The review-copilot skill now provides clear guidance when a PR has no Copilot review comments, instead of silently
  doing nothing ([#3](https://github.com/ptdecker/kiss-skills/issues/3))

## [1.1.1] - 2026-03-23

### Fixed

- Remove `disable-model-invocation: true` from both skills to work around a Claude Code platform bug
  ([anthropics/claude-code#30484](https://github.com/anthropics/claude-code/issues/30484)) that blocks user-initiated
  slash-command invocation when this field is set ([#2](https://github.com/ptdecker/kiss-skills/issues/2))
- Update skill now always reminds the user to restart Claude Code after an update, not only when new skills are added

## [1.1.0] - 2026-03-23

### Added

- **update** skill — update locally installed skills to the latest version from GitHub, with changelog display and
  automatic symlinking of new skills

## [1.0.0] - 2026-03-23

### Added

- **review-copilot** skill — triage and respond to GitHub Copilot PR review comments (inline threads and suppressed
  low-confidence comments)
- **pr-announce** skill — generate a Slack-ready PR review announcement and copy to clipboard
- One-liner install script (`install.sh`) that clones the repo and symlinks skills into `~/.claude/skills/`
- Uninstall script (`uninstall.sh`) that cleanly removes symlinks
- Contributing guide (`CONTRIBUTING.md`)
- GitHub issue templates for bug reports and feature requests
- Branch protection ruleset on `main` requiring PR reviews
