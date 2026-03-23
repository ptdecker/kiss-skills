---
name: kiss:review-copilot
description: Evaluate and respond to GitHub Copilot PR review comments. Triages each comment, plans fixes for valid ones, dismisses invalid ones, and pushes resolved changes.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
argument-hint: "[PR-number]"
---

# Review Copilot PR Comments

You are reviewing GitHub Copilot's automated PR review comments. Work through the following steps
in order. Be methodical -- do not skip steps or combine them.

## Step 1: Identify the PR

If the user provided a PR number as `$ARGUMENTS`, use that. Otherwise, determine the PR from the
current branch:

```
gh pr view --json number,title,url,headRefName
```

Display the PR number, title, and URL. Ask the user to confirm this is the correct PR before
proceeding.

## Step 2: Fetch all Copilot comments

Copilot leaves two kinds of feedback. Collect both.

### 2a: Inline comment threads

Pull all review comments from the PR and filter to only those left by Copilot (author login
contains "copilot"):

```
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate --jq '.[] | select(.user.login | test("copilot"; "i"))'
```

For each comment, capture:
- `id` (the comment ID)
- `path` (file path)
- `line` or `original_line` (line number)
- `body` (the comment text)
- `in_reply_to_id` (to identify threads -- group by this or by `id` if it is a top-level comment)
- `subject_type` and `diff_hunk` (for context)

These are **full-confidence** comments. Copilot created real review threads for them.

### 2b: Suppressed (low-confidence) comments

Copilot also embeds suppressed comments inside the review body itself, under a
`<details>` / `<summary>Comments suppressed due to low confidence</summary>` section. Fetch the
review objects:

```
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[] | select(.user.login | test("copilot"; "i")) | {id, node_id, body}'
```

Parse the review body to extract any suppressed comments. These typically appear as bold
file:line references followed by a description and optional code block.

**Important**: Suppressed comments do NOT have their own comment threads on the PR. Copilot
chose not to create threads for them because it had low confidence. This means:
- There is no comment ID to reply to
- There is no thread to resolve
- There is no comment to react to

These must be handled differently from inline threads (see Steps 3 and 7).

### Display summary

Display a numbered summary of ALL comments found (both inline and suppressed), showing the file,
line, a one-line synopsis, and whether it is an **inline thread** or **suppressed**.

### No Copilot comments found

If both the inline comments (Step 2a) and the suppressed comments (Step 2b) come back empty,
tell the user:

> No Copilot review comments found on PR #<number>.
>
> This usually means one of:
> - Copilot auto-review is not enabled for this repository
>   (check Settings → Code review → Copilot)
> - Copilot has not reviewed this PR yet (it may take a few minutes after pushing)
> - Copilot reviewed the PR but had no comments
>
> Nothing to do — stopping here.

Stop here. Do not proceed to Step 3.

## Step 3: Evaluate each comment

For each Copilot comment:

1. Read the file and surrounding context referenced by the comment
2. Understand what Copilot is suggesting
3. Determine whether the comment is **valid** (the suggestion would genuinely improve the code --
   correctness, safety, clarity, or maintainability) or **ignorable** (the suggestion is
   subjective, incorrect, inapplicable, or would not meaningfully improve the code)

### Extra scrutiny for suppressed comments

Copilot suppressed these comments because it had low confidence in them. Apply a higher bar:

- Read more surrounding context than you would for a full-confidence comment
- Check whether the issue Copilot flagged actually exists in the current code (not just in the
  diff hunk Copilot saw)
- Consider whether the suggestion reflects a misunderstanding of the codebase's conventions
- If the comment is borderline, lean toward dismissing it -- Copilot already doubted it

Keep a running tally of your evaluation as you go, noting which are inline threads vs suppressed.

## Step 4: Enter plan mode and present the plan

Enter plan mode. Write a plan that contains two sections:

### Comments to Address

For each valid comment, include:
- The file and line reference
- Whether it is an **inline thread** or **suppressed** comment
- A paragraph explaining why the comment is valid
- The specific steps to fix the issue
- A paragraph describing how the fix will be implemented

### Comments to Dismiss

For each ignorable comment, include:
- The file and line reference
- Whether it is an **inline thread** or **suppressed** comment
- A paragraph explaining why the comment does not need to be addressed

Exit plan mode and wait for the user to approve the plan.

## Step 5: Execute the plan

Implement all fixes described in the plan. After all changes are made:

1. Run the project's lint command to verify the changes compile cleanly
2. Run the project's test command to verify nothing is broken
3. Show the user a summary of what was changed

## Step 6: Commit and push

Before committing, prompt the user with the following message:

---

**Before I commit, please review the changes in your IDE.** Use your editor's diff view to
verify each fix looks correct -- especially for suppressed low-confidence comments where Copilot
was less certain. Confirm when you're satisfied and ready to commit, or let me know if anything
needs adjustment.

---

Wait for the user to confirm. Once confirmed:

1. Stage the changed files (be specific -- do not use `git add -A`)
2. Write a commit message that summarizes the Copilot review fixes. Format:

   ```
   Address Copilot review feedback on PR #<number>

   <bullet list of what was fixed and why>

   Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
   ```

3. Create the commit
4. Push to origin
5. Save the commit hash for use in the next step

## Step 7: Respond to Copilot on GitHub

There are two response paths depending on comment type.

### 7a: Inline thread comments (full-confidence)

These have real comment threads on the PR. Handle each one individually.

**For threads that were addressed:**

1. Post a reply to the thread explaining what was fixed and how, including the commit hash:
   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<response>"
   ```
2. Add a standard GitHub emoji reaction (+1) to the original comment:
   ```
   gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions -f content="+1"
   ```
3. Resolve the thread. The comment `node_id` is a `PullRequestReviewComment` (PRRC), not a
   thread. To resolve, query for the actual `PullRequestReviewThread` (PRRT) node ID:
   ```
   gh api graphql -f query='query {
     repository(owner: "<owner>", name: "<repo>") {
       pullRequest(number: <number>) {
         reviewThreads(first: 50) {
           nodes {
             id
             isResolved
             comments(first: 1) {
               nodes { body author { login } }
             }
           }
         }
       }
     }
   }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].author.login | test("copilot"; "i"))'
   ```
   Then resolve using the PRRT ID:
   ```
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<PRRT_id>"}) { thread { isResolved } } }'
   ```

**For threads that were dismissed:**

1. Post a reply explaining why the suggestion is not being adopted
2. Add a standard GitHub emoji reaction (-1) to the original comment
3. Resolve the thread using the same approach as above

### 7b: Suppressed comments (low-confidence)

These do NOT have comment threads. Do not attempt to reply to, react to, or resolve individual
comments -- there are no thread IDs or comment IDs to target.

Instead, accumulate all suppressed comment responses (both addressed and dismissed) into a
**single PR comment** posted via:

```
gh pr comment {number} --body "<accumulated response>"
```

Format the comment as follows:

```markdown
Addressing Copilot's suppressed (low-confidence) comments from the review:

**`<file>:<line>` — <short description>**: <paragraph explaining what was done and why,
or why it was dismissed>. [If addressed: Fixed in commit <hash>.]

**`<file>:<line>` — <short description>**: ...

[repeat for each suppressed comment]
```

## Step 8: Copilot feedback buttons (manual step)

**Important**: Copilot's dedicated thumbs-up / thumbs-down feedback buttons (visible on each
Copilot comment in the GitHub web UI) are a proprietary feedback mechanism that trains Copilot's
review model. These are **separate from** the standard GitHub emoji reactions added in Step 7 and
are **not accessible via any public API, GraphQL mutation, or `gh` CLI command**. They can only
be clicked in the GitHub web UI.

After completing all automated steps, prompt the user with a message like:

---

**Manual step required**: Please open the PR in your browser and click the Copilot feedback
buttons on each inline comment:
- **Thumbs up** for comments that were valid and addressed
- **Thumbs down** for comments that were dismissed

These dedicated Copilot feedback buttons (not the emoji reactions I already added) help train
Copilot's review model. They are only available in the GitHub web UI.

Here is the PR link: `<PR URL>`

The inline comments to provide feedback on:

| Comment | File | Action | Feedback |
|---------|------|--------|----------|
| <synopsis> | <file:line> | Addressed / Dismissed | Thumbs up / Thumbs down |
| ... | ... | ... | ... |

Note: Suppressed (low-confidence) comments do not have feedback buttons since Copilot did not
create threads for them.

---

## Step 9: Summary

Display a final summary showing:
- How many inline thread comments were addressed vs dismissed
- How many suppressed comments were addressed vs dismissed
- The commit hash of the fix (if any changes were made)
- Confirmation that all inline threads have been responded to and resolved
- Confirmation that a PR comment was posted for suppressed comments (if any)
- Reminder of whether the user still needs to click Copilot feedback buttons
