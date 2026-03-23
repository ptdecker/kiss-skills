# Contributing to KISS Skills

Thanks for your interest in contributing. This document covers how to report issues, suggest ideas, and submit changes.

## Reporting Issues

Before opening an issue, please check the [existing issues](https://github.com/ptdecker/kiss-skills/issues) to avoid duplicates.

When reporting a bug, include:

- Which skill is affected
- What you expected to happen
- What actually happened
- Any error output from Claude Code
- Your environment (OS, Claude Code version, `gh` CLI version)

Use the [Bug Report](https://github.com/ptdecker/kiss-skills/issues/new?template=bug_report.yml) or [Feature Request](https://github.com/ptdecker/kiss-skills/issues/new?template=feature_request.yml) templates when opening an issue.

## Suggesting New Skills

Have an idea for a new skill? Open a feature request issue describing:

- What the skill would do
- The problem it solves or workflow it improves
- Any tools or APIs it would need (e.g., `gh`, `pbcopy`)

## Submitting Changes

All changes come through pull requests. Direct pushes to `main` are restricted.

### Steps

1. Fork the repository
2. Create a branch from `main` (`git checkout -b my-change`)
3. Make your changes
4. Test the skill locally by symlinking it into `~/.claude/skills/`
5. Push your branch and open a PR against `main`

### Skill Guidelines

- Each skill lives in its own directory under `skills/` with a single `SKILL.md` file
- Use the `kiss:` namespace prefix in the skill's `name` frontmatter field
- Keep skills focused — one skill, one job
- Include clear step-by-step instructions in the SKILL.md so Claude Code can follow them reliably
- List any external tool dependencies (e.g., `gh`, `pbcopy`) in the skill description
- Add an entry to the skills table in `README.md`

### PR Expectations

- Keep PRs focused on a single change
- Describe what the change does and why in the PR body
- New skills should include a brief description of how to test them

## Questions?

Open an issue or start a discussion. Happy to help.
