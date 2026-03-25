---
name: kiss:review-peer
description: Respond to unresolved peer PR review comments. Triages threads interactively, plans and implements fixes, and replies on GitHub.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
argument-hint: "[PR-number]"
---

# Review Peer PR Comments

You are reviewing unresolved PR review comments from human peer reviewers. Work through the
following steps in order. Be methodical – do not skip steps or combine them.

## Step 1: Identify the PR

If the user provided a PR number as `$ARGUMENTS`, use that. Otherwise, determine the PR from the
current branch:

```
gh pr view --json number,title,url,headRefName
```

Display the PR number, title, and URL. Ask the user to confirm this is the correct PR before
proceeding.

Also capture the repository owner and name:

```
gh repo view --json owner,name --jq '{owner: .owner.login, repo: .name}'
```

And capture the current authenticated user's login (needed later for reaction management):

```
gh api user --jq '.login'
```

## Step 2: Fetch unresolved peer review threads

Use the GitHub GraphQL API to fetch all review threads with their resolution status, comments,
authors, and reactions:

```
gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr={number} -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            path
            line
            startLine
            diffSide
            comments(first: 50) {
              nodes {
                id
                databaseId
                body
                author {
                  login
                  ... on Bot { id }
                }
                createdAt
                url
              }
            }
          }
        }
      }
    }
  }
'
```

If `pageInfo.hasNextPage` is true, paginate using the `endCursor` value until all threads are
retrieved.

### Filter to unresolved peer threads

From the results, keep only threads that meet **both** criteria:

1. **Unresolved**: `isResolved` is `false`
2. **From a human peer reviewer**: The **first comment** in the thread was authored by a human,
   not a bot. Exclude threads where the first comment's author:
   - Has a GraphQL type of `Bot` (the `... on Bot { id }` fragment returned a value)
   - Has a login matching common bot patterns (case-insensitive): `copilot`, `github-actions`,
     `dependabot`, `renovate`, `codecov`, `sonarcloud`, `netlify`, `vercel`
   - Has a login ending with `[bot]`

### Display summary

Present a numbered table of all unresolved peer threads:

```
| # | Reviewer | File:Line | Synopsis |
|---|----------|-----------|----------|
| 1 | alice    | src/main.rs:42 | Suggests extracting helper function |
| 2 | bob      | lib/utils.ts:15 | Questions null check necessity |
```

### No peer review threads found

If the filtered list is empty, tell the user:

> No unresolved peer review comments found on PR #<number>.
>
> This usually means one of:
> - All peer review threads have already been resolved
> - The PR has no human reviewer comments (only bot comments, if any)
> - The PR has not been reviewed yet
>
> Nothing to do – stopping here.

Stop here. Do not proceed to Step 3.

## Step 3: Interactive triage

Walk through each unresolved peer thread one at a time. For each thread:

1. Display the full conversation – all comments in the thread with author, timestamp, and body
2. Ask the user:

   > **Thread #<n>: <file>: <line> -- <reviewer>**
   >
   > **Address this thread?** (yes / no)

3. If the user says **yes**:
   - Ask: "Any discussion notes or context I should incorporate when fixing this?"
   - The user may type notes (reasoning, pushback, questions, additional context) or skip
   - Record the thread as "to address" along with any user-provided notes

4. If the user says **no**:
   - Record the thread as "to skip"

After processing all threads, display a decision summary:

```
Threads to address: #1, #3, #5
Threads to skip: #2, #4
```

## Step 4: Mark threads in GitHub (manual step)

If there are threads to address, instruct the user:

---

**Manual step required**: For each thread you want addressed, please open the PR in your browser
and add the :eyes: (eyes) emoji reaction to the **last comment** in that thread. This marks
which threads have been triaged for action.

Here is the PR link: `<PR URL>`

Threads to mark with :eyes::

| # | File:Line       | Last comment by | Comment link |
|---|-----------------|-----------------|--------------|
| 1 | src/main.rs:42  | alice           | <url>        |
| 3 | lib/utils.ts:87 | alice           | <url>        |

Let me know when you have finished adding the emoji reactions.

---

Wait for the user to confirm they have added the emoji reactions.

If there are no threads to address (all were skipped), skip ahead to Step 6.

## Step 5: Verify emoji markers

Re-run the GraphQL query to check which threads now have :eyes: reactions on their last comment.
Use a targeted query that includes reactions:

```
gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr={number} -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(last: 1) {
              nodes {
                databaseId
                reactions(first: 100, content: EYES) {
                  nodes {
                    databaseId
                    user { login }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
'
```

For each thread the user said to address, verify that:
- The last comment has at least one :eyes: reaction from the current user's login

If there is a mismatch (user said address but no :eyes: found), warn:

> Thread #<n> (<file>:<line>) was marked to address, but I could not find an :eyes: reaction
> on the last comment. Would you like to proceed anyway or go back and add the reaction?

Allow the user to proceed or correct.

## Step 6: Build the plan

Enter plan mode. Write a plan that contains two sections:

### Threads to Address

For each thread the user wants addressed:
- The file and line reference
- The reviewer's comment (summarized)
- The user's discussion notes (if any were provided)
- An assessment of what needs to change and why
- The specific implementation steps to fix the issue

### Threads to Skip

For each thread the user wants skipped:
- The file and line reference
- The reviewer's comment (summarized)
- A draft of the reply to be posted on GitHub explaining why the feedback is not being addressed
  in this cycle. The reply should be:
  - **Contextual**: reference what the reviewer specifically raised
  - **Respectful**: acknowledge the feedback before explaining
  - **Specific**: give a real reason, not boilerplate
  - Example tones:
    - "Thanks for flagging this. The current approach is intentional because [reason]. Happy to
      discuss further if you'd like to revisit."
    - "Good observation. This is planned for a follow-up in [context]. Keeping the current
      approach for now to keep this PR focused."
    - "Appreciate the review. We considered this but opted for [alternative] because [reason]."

Exit plan mode and wait for the user to approve the plan.

## Step 7: Execute the plan

Implement all code fixes described in the plan. After all changes are made:

1. Run the project's lint command to verify the changes compile cleanly
2. Run the project's test command to verify nothing is broken
3. Show the user a summary of what was changed

## Step 8: User review and commit

Before committing, prompt the user with the following message:

---

**Before I commit, please review the changes in your IDE.** Use your editor's diff view to
verify each fix looks correct. Confirm when you're satisfied and ready to commit, or let me know
if anything needs adjustment.

---

Wait for the user to confirm. Once confirmed:

1. Stage the changed files (be specific -- do not use `git add -A`)
2. Write a commit message that summarizes the peer review fixes. Format:

   ```
   Address peer review feedback on PR #<number>

   <bullet list of what was fixed and why>

   Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
   ```

3. Create the commit
4. Push to origin
5. Save the commit hash for use in the next step

## Step 9: Respond on GitHub

There are two response paths depending on the triage decision.

### Addressed threads

For each thread that was addressed:

1. Post a reply to the thread explaining what was fixed and how, including the commit hash.
   Reply to the **first comment** in the thread (the root comment that identifies the thread):
   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments/{first_comment_database_id}/replies \
     -f body="<response describing the fix and referencing the commit hash>"
   ```

2. Remove the :eyes: emoji reaction from the last comment. First, find the reaction ID for the
   current user:
   ```
   gh api repos/{owner}/{repo}/pulls/comments/{last_comment_database_id}/reactions \
     --jq '.[] | select(.content == "eyes" and .user.login == "{current_user}") | .id'
   ```
   Then delete it:
   ```
   gh api -X DELETE repos/{owner}/{repo}/pulls/comments/{last_comment_database_id}/reactions/{reaction_id}
   ```

### Skipped threads

For each thread that was skipped:

1. Post a reply with the contextual explanation crafted in Step 6:
   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments/{first_comment_database_id}/replies \
     -f body="<contextual response from the plan>"
   ```

### Important

Do **NOT** resolve any threads. Unlike review-copilot, this skill deliberately leaves threads
open. The human peer reviewer who opened the thread should be the one to resolve it after seeing
the response.

## Step 10: Summary

Display a final summary showing:
- How many threads were addressed vs. skipped?
- The file:line references for each group
- The commit hash of the fix (if any changes were made)
- Confirmation that all threads have been replied to on GitHub
- Confirmation that :eyes: emoji markers have been removed from addressed threads
- Note that no threads were resolved – the peer reviewers will resolve after reviewing responses
