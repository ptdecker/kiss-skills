---
name: kiss:update
description: Update locally installed KISS Skills to the latest version from GitHub. Pulls the latest changes and symlinks any new skills.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Update KISS Skills

Update the locally installed KISS Skills to the latest version from the GitHub repository.

## Step 1: Locate the clone

Check that the kiss-skills clone exists at `~/.kiss-skills/` and is a git repository:

```
test -d ~/.kiss-skills/.git
```

If the directory does not exist or is not a git repo, tell the user:

> KISS Skills clone not found at `~/.kiss-skills/`. Please install first:
> ```
> curl -fsSL https://raw.githubusercontent.com/ptdecker/kiss-skills/main/install.sh | bash
> ```

Stop here if the clone is not found.

## Step 2: Check current state

Capture the current commit hash and show the user where they are:

```
git -C ~/.kiss-skills rev-parse HEAD
git -C ~/.kiss-skills log --oneline -1
```

Save the commit hash — you will need it in Step 4 to compare against the new HEAD.

Display the current commit to the user.

## Step 3: Pull latest

Run a fast-forward pull to get the latest changes:

```
git -C ~/.kiss-skills pull --ff-only
```

If the pull fails (e.g., due to local modifications or merge conflicts), show the error
output to the user and suggest they resolve it manually:

> The pull failed. This usually means there are local modifications in `~/.kiss-skills/`.
> To resolve, run:
> ```
> cd ~/.kiss-skills
> git status
> ```
> Then either stash or discard local changes and retry `/kiss:update`.

Stop here if the pull failed.

## Step 4: Report changes

Capture the new commit hash:

```
git -C ~/.kiss-skills rev-parse HEAD
```

Compare it to the hash saved in Step 2.

**If the hashes are the same**, tell the user:

> Already up to date. No new changes available.

Stop here.

**If the hashes differ**, show what changed:

1. List the new commits:
   ```
   git -C ~/.kiss-skills log --oneline <old-hash>..HEAD
   ```

2. List the changed files:
   ```
   git -C ~/.kiss-skills diff --name-only <old-hash>..HEAD
   ```

3. Read `~/.kiss-skills/CHANGELOG.md` and display the changelog entries for versions newer
   than the previously installed version. To determine which entries are new, find the first
   `## [` heading whose version matches or predates the old commit, and display everything
   above it. This gives the user a human-readable summary of what changed and why.

## Step 5: Symlink new skills

Check for any new skill directories that do not yet have symlinks:

```
for skill_dir in ~/.kiss-skills/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  if [ ! -e ~/.claude/skills/"$skill_name" ]; then
    ln -s "$skill_dir" ~/.claude/skills/"$skill_name"
    echo "Linked new skill: $skill_name"
  fi
done
```

Report any newly linked skills to the user. If no new skills were added, note that all
existing symlinks are intact.

## Step 6: Summary

Display a final summary:

- Number of new commits pulled
- New skills linked (if any)
- A note to restart Claude Code if new skills were added, so they appear in the slash-command
  list
