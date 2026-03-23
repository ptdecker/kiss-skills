# KISS Skills

Shareable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| [review-copilot](skills/review-copilot/SKILL.md) | `/kiss:review-copilot [PR]` | Triage GitHub Copilot PR review comments — evaluate, fix valid issues, dismiss the rest, and respond on GitHub |
| [pr-announce](skills/pr-announce/SKILL.md) | `/kiss:pr-announce [PR]` | Generate a Slack-ready announcement that a PR is ready for review and copy it to your clipboard |
| [update](skills/update/SKILL.md) | `/kiss:update` | Update locally installed skills to the latest version from GitHub |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ptdecker/kiss-skills/main/install.sh | bash
```

This clones the repo to `~/.kiss-skills/` and symlinks each skill into `~/.claude/skills/`. The skills will be available the next time you start Claude Code.

### Update

Run the update skill from within Claude Code:

```
/kiss:update
```

Or manually pull from the clone:

```bash
cd ~/.kiss-skills && git pull
```

### Uninstall

```bash
~/.kiss-skills/uninstall.sh
```

This removes the symlinks from `~/.claude/skills/`. The cloned repo is left in place — delete `~/.kiss-skills/` to fully remove it.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- [GitHub CLI (`gh`)](https://cli.github.com/) authenticated — required by both skills
- `pbcopy` (macOS) — used by `pr-announce` to copy to clipboard

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on reporting issues, suggesting new skills, and submitting pull requests.

## License

[Unlicense](LICENSE) — public domain.
