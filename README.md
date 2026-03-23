# KISS Skills

Shareable skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| [review-copilot](skills/review-copilot/SKILL.md) | `/review-copilot [PR]` | Triage GitHub Copilot PR review comments — evaluate, fix valid issues, dismiss the rest, and respond on GitHub |
| [pr-announce](skills/pr-announce/SKILL.md) | `/pr-announce [PR]` | Generate a Slack-ready announcement that a PR is ready for review and copy it to your clipboard |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ptdecker/kiss-skills/main/install.sh | bash
```

This clones the repo to `~/.kiss-skills/` and symlinks each skill into `~/.claude/skills/`. The skills will be available the next time you start Claude Code.

### Update

Because the skills are symlinked from the clone, updating is just a pull:

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

Contributions are welcome. Each skill lives in its own directory under `skills/` and consists of a single `SKILL.md` file. See the [Claude Code skill documentation](https://docs.anthropic.com/en/docs/claude-code/skills) for the format.

To add a new skill:

1. Create `skills/<skill-name>/SKILL.md`
2. Use the `kiss:` namespace prefix in the skill's `name` field
3. Add an entry to the table in this README
4. Open a PR

## License

[Unlicense](LICENSE) — public domain.
