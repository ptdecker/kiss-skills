---
name: kiss:pr-announce
description: Generate a Slack-ready announcement that a PR is ready for review. Summarizes the PR and copies the message to the clipboard.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[PR-number]"
---

# PR Review Announcement

Generate a short Slack post announcing that a PR is ready for review.

## Step 1: Identify the PR

If the user provided a PR number as `$ARGUMENTS`, use that. Otherwise, determine the PR from the
current branch:

```
gh pr view --json number,title,url,headRefName
```

Display the PR number, title, and URL. Ask the user to confirm this is the correct PR before
proceeding.

## Step 2: Gather PR context

Fetch the PR description and diff summary:

```
gh pr view --json number,title,body,url
gh pr diff --name-only
```

Read the PR body and the list of changed files to understand the scope and purpose of the changes.

## Step 3: Write the announcement

Compose a message in this exact format:

```
PR #<number> is ready for review. <short paragraph summary>

<PR URL>
```

The PR URL goes on its own line at the end so Slack auto-links it. Do not attempt Slack link
markup (`<url|text>`) as it does not work when pasting into the message input box.

The summary paragraph should be 2-4 sentences. It should describe what the PR does and why, at a
level appropriate for teammates who have not seen the code. Do not include file lists, line
counts, or implementation details -- focus on the intent and impact of the change.

## Step 4: Present and copy

Display the composed message to the user. Then copy it to the system clipboard:

```
echo "<message>" | pbcopy
```

Let the user know the message has been copied to their clipboard and is ready to paste into Slack.
