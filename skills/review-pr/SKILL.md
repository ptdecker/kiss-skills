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

Also capture the head commit SHA (needed later for inline comments):

```
gh pr view {number} --repo {owner}/{repo} --json commits --jq '.commits[-1].oid'
```

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
| **Code-specific** | Tied to a specific file and line or line range | Inline review comment |
| **File-specific** | About a file as a whole, not a particular line | File-level review comment |
| **General** | About the PR overall — architecture, approach, cross-cutting concerns | Included in the review body |

For code-specific observations, record the file path, line number (or start and end line for a range),
and the observation text. For file-specific observations, record the file path and observation text. For
general observations, record only the observation text.

## Step 4: Present observations

Display a summary table of all observations:

```
| #  | Type          | Location              | Synopsis                              |
|----|---------------|-----------------------|---------------------------------------|
| 1  | Code-specific | src/main.rs:42        | Potential panic on unwrap()            |
| 2  | Code-specific | src/main.rs:78-85     | Missing error handling in loop         |
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
   - Present the updated observation and ask again: **accept** or **edit**.
   - Repeat until the user accepts the revised version.

6. If the user says **ignore**: remove the observation from the final list and move to the next one.

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

1. **Code-specific observations** — these become entries in the `comments` array with `path`, `line`
   (and optionally `start_line` for multi-line ranges), `side: "RIGHT"`, and `body`.
2. **File-specific observations** — these become entries in the `comments` array with `path`,
   `subject_type: "file"`, and `body`.
3. **General observations** — these are concatenated into the review `body` field as a numbered
   Markdown list under a `## Review Observations` heading.

If there are no general observations, set the body to "See inline comments for detailed feedback."

### Construct and send the review

Use `jq` to build the JSON payload. This avoids shell escaping issues with observation text that may
contain quotes, newlines, or special characters.

```
jq -n \
  --arg event "PENDING" \
  --arg body "$REVIEW_BODY" \
  --arg commit_id "$HEAD_COMMIT_SHA" \
  --argjson comments "$COMMENTS_JSON" \
  '{event: $event, body: $body, commit_id: $commit_id, comments: $comments}' \
| gh api repos/{owner}/{repo}/pulls/{number}/reviews --input -
```

The `COMMENTS_JSON` variable is a JSON array built from the code-specific and file-specific
observations. Each element follows one of these shapes:

**Code-specific (single line):**
```json
{"path": "src/main.rs", "line": 42, "side": "RIGHT", "body": "Observation text here."}
```

**Code-specific (line range):**
```json
{"path": "src/main.rs", "start_line": 78, "line": 85, "side": "RIGHT", "body": "Observation text here."}
```

**File-specific:**
```json
{"path": "src/utils.ts", "subject_type": "file", "body": "Observation text here."}
```

### Error handling

If the API returns an error indicating that a pending review already exists for this user on this PR,
display:

> You already have a pending review on PR #{number}. Please open the PR in GitHub and either submit or
> discard your existing pending review before running this skill again.
>
> PR link: {PR URL}

Stop here. Do not attempt to modify the existing review.

## Step 8: Summary and next steps

Display a final summary:

> **Pending review created on PR #{number}.**
>
> The review contains:
> - {N} inline code comment(s)
> - {N} file-level comment(s)
> - {N} general observation(s) in the review body
>
> **The review has NOT been submitted.** It is saved as a pending draft on GitHub.
>
> To complete the review:
> 1. Open the PR: {PR URL}
> 2. Click the green **Review changes** button (you should see a badge indicating pending comments)
> 3. Select your disposition: **{the disposition the user chose in Step 6}**
> 4. Click **Submit review**
>
> Until you submit, the PR author cannot see your comments.
