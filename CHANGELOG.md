# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-03-23

### Added

- **review-copilot** skill — triage and respond to GitHub Copilot PR review comments (inline threads and suppressed low-confidence comments)
- **pr-announce** skill — generate a Slack-ready PR review announcement and copy to clipboard
- One-liner install script (`install.sh`) that clones the repo and symlinks skills into `~/.claude/skills/`
- Uninstall script (`uninstall.sh`) to cleanly remove symlinks
- Contributing guide (`CONTRIBUTING.md`)
- GitHub issue templates for bug reports and feature requests
- Branch protection ruleset on `main` requiring PR reviews
