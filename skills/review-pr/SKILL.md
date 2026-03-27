---
name: kiss:review-pr
description: Review a peer's PR — analyze changes, build observations interactively, and create a pending GitHub review with inline and file-level comments.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Agent
argument-hint: "[owner/repo PR-number]"
---

# Review a Peer's PR

You are conducting a thorough code review of a pull request authored by someone else. Work through the
following steps in order. Be methodical — do not skip steps or combine them.

## Step 1: Identify the repository and PR

This skill can run from any directory — it does not require the user to be inside the target
repository's checkout.

### Determine the repository

If `$ARGUMENTS` contains a value that looks like `owner/repo` (a string with exactly one slash and no
spaces), use that. Otherwise, ask the user:

> Which repository contains the PR you want to review? (format: `owner/repo`)

Once you have the repository, verify that it exists and is accessible:

```
gh repo view {owner}/{repo} --json name,owner --jq '{owner: .owner.login, repo: .name}'
```

If this command fails, the repository either does not exist or the user does not have access. Display
the error and stop here.

### Determine the PR number

If `$ARGUMENTS` contains a numeric value, use that as the PR number. Otherwise, ask the user:

> What is the PR number you want to review?

Once you have both the repository and PR number, fetch the PR details. Use the `--repo` flag so the
command works regardless of the current working directory:

```
gh pr view {number} --repo {owner}/{repo} --json number,title,url,headRefName
```

Display the PR number, title, and URL. Ask the user to confirm this is the correct PR before proceeding.

Also capture two values needed later when creating the review:

```
gh pr view {number} --repo {owner}/{repo} --json commits --jq '.commits[-1].oid'
gh pr view {number} --repo {owner}/{repo} --json id --jq '.id'
```

The first is the head commit SHA (needed for inline comments). The second is the PR's GraphQL node ID
(needed for the GraphQL review creation mutation).

**Important**: All `gh pr` commands in subsequent steps must include `--repo {owner}/{repo}` so they
target the correct repository.

## Step 2: Verify the PR is open

Check that the PR has not already been merged or closed:

```
gh pr view {number} --repo {owner}/{repo} --json state,mergedAt --jq '{state: .state, mergedAt: .mergedAt}'
```

If the state is not `OPEN`, display a message explaining why the review cannot proceed:

- If `mergedAt` has a value: "PR #{number} has already been merged. Only open PRs can be reviewed."
- Otherwise: "PR #{number} is closed. Only open PRs can be reviewed."

Stop here. Do not proceed to Step 3.

## Step 3: Fetch and analyze the PR changes

Gather the diff, changed file list, and PR metadata:

```
gh pr diff {number} --repo {owner}/{repo}
gh pr diff {number} --repo {owner}/{repo} --name-only
gh pr view {number} --repo {owner}/{repo} --json body,title,baseRefName,headRefName
```

For each changed file, read the full file content — not just the diff hunks — to understand the broader
context surrounding each change. When the PR touches many files, use `Agent` sub-agents to parallelize
the analysis across different files.

Perform a thorough review. Consider each of the following dimensions:

- **Correctness** — logic errors, off-by-one mistakes, unhandled edge cases, race conditions
- **Security** — injection risks, credential exposure, unsafe operations, improper input validation
- **Performance** — unnecessary allocations, O(n²) patterns, missing indexes, redundant computation
- **Readability** — unclear naming, overly complex logic, misleading comments
- **Maintainability** — code duplication, tight coupling, fragile assumptions
- **Testing gaps** — untested edge cases, missing error-path coverage, new code without corresponding tests
- **API design** — inconsistent interfaces, breaking changes, poor error messages
- **Documentation** — missing or stale doc comments, README updates needed for user-facing changes

Build an enumerated list of observations. Each observation must be classified as one of three types:

| Type | Description | GitHub mapping |
|------|-------------|----------------|
| **Code-specific** | Tied to a specific file and line or line range | Inline review comment (part of the pending review) |
| **File-specific** | About a file as a whole, not a particular line | File-level review comment (part of the pending review) |
| **General** | About the PR overall — architecture, approach, cross-cutting concerns | Posted as a separate PR comment |

For code-specific observations, record the file path, the full line range of the enclosing code block,
and the observation text. The line range should span the entire relevant block — for example, a full
function definition, a complete struct or enum, an entire const declaration group, or a whole if/else
chain — not just the narrow lines that triggered the observation. This gives the PR author full context
when reading the inline comment. For file-specific observations, record the file path and observation
text. For general observations, record only the observation text.

## Step 4: Present observations

Display a summary table of all observations:

```
| #  | Type          | Location              | Synopsis                              |
|----|---------------|-----------------------|---------------------------------------|
| 1  | Code-specific | src/main.rs:30-55     | Potential panic on unwrap()            |
| 2  | Code-specific | src/main.rs:70-95     | Missing error handling in loop         |
| 3  | File-specific | src/utils.ts          | New module has no corresponding tests  |
| 4  | General       | —                     | PR description omits breaking change   |
```

Below the table, list the full text of each observation, numbered to match the table. Each observation
should be a clear, actionable paragraph that a developer can understand and act on without additional
context.

## Step 5: Interactive observation review

Walk through each observation one at a time. For each observation:

1. Display the observation number, type, location, and full text.
2. If the observation is code-specific, also display the relevant code snippet from the diff for
   context.
3. Ask the user:

   > **Observation #{n}: {location or "General"}**
   >
   > {full observation text}
   >
   > **Action?** (accept / edit / ignore)

4. If the user says **accept**: record the observation as approved and move to the next one.

5. If the user says **edit**: enter an edit cycle:
   - Ask the user for their revised wording or modification instructions.
   - Update the observation accordingly.
   - Present the updated observation and ask: **accept**, **edit**, or **ignore**.
   - Repeat until the user either accepts or ignores.

6. If the user says **ignore** (at any point — initial prompt or during an edit cycle): remove the
   observation from the final list and move to the next one.

After processing all observations, display a summary:

```
Accepted: #1, #3, #5, #7
Ignored:  #2, #4, #6
```

If every observation was ignored, inform the user that there is nothing to submit and stop here.

## Step 6: Final approval and disposition

Present the complete list of accepted observations one more time, in the same format as Step 4 (summary
table followed by full text). Renumber them sequentially starting from 1.

Then ask the user two questions:

### Final approval

> Are you satisfied with these observations, or would you like to make further changes?

If the user wants changes, allow them to specify which observations to modify or remove. Apply the
changes, present the updated list, and ask for approval again. Repeat until the user is satisfied.

### Disposition

Once the user approves the final list, ask:

> What disposition should this review have?
>
> 1. **Comment** — general feedback without an explicit approval or rejection
> 2. **Approve** — approve the PR along with these comments
> 3. **Request changes** — request that the author address the observations before merging

Explain that the review will be created as a pending draft. When the user opens the PR in GitHub and
clicks "Submit review," they will confirm their chosen disposition at that time.

## Step 7: Create the pending review

Separate the accepted observations into three groups based on their type:

1. **Code-specific observations** — these become inline review comments as part of the pending
   review. Always use both `startLine` and `line` to highlight the full enclosing code block (e.g.,
   the entire function, the complete const group, or the whole conditional chain), not just the
   narrow lines that triggered the observation.
2. **File-specific observations** — these become file-level review comments as part of the same
   pending review.
3. **General observations** — these are posted as a standalone PR comment. The review body set via
   the API gets overwritten when the user clicks "Submit review" in the GitHub UI, so general
   observations must be posted separately to remain visible.

### Step 7a: Create the pending review with inline comments

Use the GraphQL `addPullRequestReview` mutation to create the pending review. This mutation accepts
a `threads` array for inline comments and returns the review's node ID (needed for Step 7b).

```
gh api graphql -f query='
  mutation($prId: ID!, $body: String!, $threads: [DraftPullRequestReviewThread!]!) {
    addPullRequestReview(input: {
      pullRequestId: $prId,
      body: $body,
      threads: $threads
    }) {
      pullRequestReview { id }
    }
  }
' -f prId="$PR_NODE_ID" -f body="$REVIEW_BODY" -f threads="$THREADS_JSON"
```

Set `$PR_NODE_ID` to the GraphQL node ID captured in Step 1. Set `$REVIEW_BODY` to a brief message
like "See inline and file-level comments for detailed feedback." (This body may be overwritten when
the user submits, which is fine.)

The `$THREADS_JSON` variable is a JSON array of inline comment threads. Each element must include
`path`, `line`, `startLine`, `side`, `startSide`, and `body`:

```json
[
  {"path": "src/main.rs", "startLine": 30, "line": 55, "side": "RIGHT", "startSide": "RIGHT", "body": "Observation text."}
]
```

**Important**: The `threads` array in `addPullRequestReview` does **not** support `subjectType`, so
only code-specific (line-level) observations go here. File-specific observations are added in Step 7b.

If there are no code-specific observations, still create the review with an empty `threads` array so
that file-level comments can be attached in Step 7b.

Capture the review's node ID from the response (the `id` field under `pullRequestReview`).

#### Error handling

If the API returns an error indicating that a pending review already exists for this user on this PR,
display:

> You already have a pending review on PR #{number}. Please open the PR in GitHub and either submit or
> discard your existing pending review before running this skill again.
>
> PR link: {PR URL}

Stop here. Do not attempt to modify the existing review.

### Step 7b: Add file-level comments to the pending review

For each file-specific observation, use the GraphQL `addPullRequestReviewThread` mutation with
`subjectType: FILE`. This adds a file-level comment to the pending review created in Step 7a.

```
gh api graphql -f query='
  mutation($reviewId: ID!, $path: String!, $body: String!) {
    addPullRequestReviewThread(input: {
      pullRequestReviewId: $reviewId,
      path: $path,
      body: $body,
      subjectType: FILE
    }) {
      thread { id }
    }
  }
' -f reviewId="$REVIEW_NODE_ID" -f path="$FILE_PATH" -f body="$OBSERVATION_TEXT"
```

Run this mutation once for each file-specific observation.

### Step 7c: Post general observations as a PR comment

If there are general observations (not tied to any specific file), post them as a standalone PR
comment so they are immediately visible.

Construct the comment body as Markdown:

```markdown
## General Review Observations

1. **{synopsis}.** {full observation text}

2. **{synopsis}.** {full observation text}
```

Post the comment:

```
gh pr comment {number} --repo {owner}/{repo} --body "$COMMENT_BODY"
```

Skip this step if there are no general observations.

### Error handling

If the review creation in Step 7a fails, do not proceed to Steps 7b or 7c. If Step 7b or 7c fails,
display the error and suggest the user post the comment manually.

## Step 8: Summary and next steps

Display a final summary:

> **Pending review created on PR #{number}.**
>
> The review contains:
> - {N} inline code comment(s) (in the pending review)
> - {N} file-level comment(s) (in the pending review)
> - {N} general observation(s) (posted as a PR comment)
>
> **The review has NOT been submitted.** It is saved as a pending draft on GitHub.
>
> To complete the review:
> 1. Open the PR: {PR URL}
> 2. Click the green **Review changes** button (you should see a badge indicating pending comments)
> 3. Select your disposition: **{the disposition the user chose in Step 6}**
> 4. Click **Submit review**
>
> The general observations are already visible as a PR comment. The inline and file-level comments
> will become visible to the PR author once you submit the review.

## Step 9: Slack summary

Generate a short, single-paragraph Slack-ready message the user can post to notify the PR author that
the review is complete. Format it as:

> I've completed my review of PR #{number} ({PR title}): {PR URL} — disposition is **{Comment,
> Approve, or Request Changes}** with {total observation count} observation(s) across {N} inline,
> {N} file-level, and {N} general.

Display this message and tell the user they can copy it to Slack.
