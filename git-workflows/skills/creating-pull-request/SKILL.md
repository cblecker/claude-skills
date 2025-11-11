---
name: creating-pull-request
description: Standard workflow for all PR operations ('create PR', 'open PR', 'pull request', 'commit and PR'): replaces bash-based gh/git workflows with end-to-end orchestration—handles uncommitted changes (auto-invokes creating-commit/creating-branch), analyzes commit history, generates convention-aware content, detects fork/origin. Canonical PR implementation for git-workflows.
---

# Skill: Creating a Pull Request

## When to Use This Skill

Use this skill for pull request creation requests: "create a PR", "open a PR", "submit for review", or similar.

Use other skills for: viewing existing PRs (GitHub MCP directly), updating PRs (GitHub MCP update), or only committing changes (creating-commit).

## Workflow Description

Creates GitHub pull requests with automatic commit handling, repository detection, PR content generation, branch pushing, and GitHub PR creation via MCP.

Extract from user request: draft status ("draft"/"WIP" → true, default false), PR title/description (if provided), target branch (if specified, else mainline)

---

## Phase 1: Pre-flight Checks

**Objective**: Verify all prerequisites for PR creation.

**Step 1: Check for uncommitted changes**

Check status:
```bash
git status --porcelain
```

IF output is not empty (uncommitted changes exist):
  EXPLAIN: "You have uncommitted changes that need to be committed before creating a PR"
  ASK: "Would you like me to create a commit for these changes?"
  WAIT for user decision

  IF user approves:
    INVOKE: creating-commit skill
    WAIT for creating-commit to complete

    IF creating-commit succeeded:
      Continue to Step 2

    IF creating-commit failed:
      STOP immediately
      EXPLAIN: "Cannot create PR without committing changes"
      EXIT workflow

  IF user declines:
    STOP immediately
    EXPLAIN: "Cannot create PR with uncommitted changes"
    EXIT workflow

IF no uncommitted changes:
  Continue to Step 2

**Step 2: Validate feature branch usage**

Invoke mainline-branch skill:
  - Request comparison against current branch
  - Receive structured result with is_mainline flag

IF is_mainline = false (on feature branch):
  Continue to Step 3

IF is_mainline = true (on mainline):
  WARN: "Currently on mainline branch"
  EXPLAIN: "Pull requests should be created from feature branches"
  PROPOSE: "Create a feature branch for this PR"
  ASK: "Would you like me to create a feature branch now?"
  WAIT for user decision

  IF user approves:
    INVOKE: creating-branch skill
    WAIT for creating-branch to complete

    IF creating-branch succeeded:
      VERIFY: Now on feature branch (not mainline)
      Continue to Step 3

    IF creating-branch failed:
      STOP immediately
      EXPLAIN: "Branch creation failed, cannot proceed with PR"
      EXIT workflow

  IF user declines:
    ASK: "Continue with PR from mainline anyway? (not recommended)"
    WAIT for explicit confirmation

    IF user confirms:
      INFORM: "Proceeding with PR from mainline (not recommended)"
      Continue to Step 3

    IF user declines:
      STOP immediately
      EXPLAIN: "Cannot create PR without feature branch"
      EXIT workflow

**Step 3: Detect repository structure**

Invoke repository-type skill:
  - Receive structured result with repository information
  - Store for later phases:
    - is_fork: Fork vs origin flag
    - upstream/origin owner and repo names
    - Remote URLs

Continue to Phase 2.

---

## Phase 2: Determine PR Base Branch

**Objective**: Identify target branch for pull request.

**Step 1: Check user request for target branch**

Analyze user's request for target branch specification:
- Look for phrases like: "create PR to <branch>", "base on <branch>", "merge into <branch>", "target <branch>"
- Common branch names: develop, staging, main, master, release, etc.

IF target branch mentioned in user request:
  Use specified branch as PR base

IF no target branch mentioned:
  Invoke mainline-branch skill to get mainline branch
  Use mainline as PR base

Store pr_base for later phases.

Phase 2 complete. Continue to Phase 3.

---

## Phase 3: Generate PR Content

**Objective**: Create compelling PR title and description.

**THINKING CHECKPOINT**: Use `mcp__sequential-thinking__sequentialthinking` to:
- Review commits and diff:
  ```bash
  git log --pretty=format:"%H %s" -n 50
  git diff <base>...HEAD
  ```
- Invoke detect-conventional-commits skill for title format detection
- Analyze purpose, scope, key changes, breaking changes
- Draft title (<72 chars, imperative) and description
- Validate quality and completeness

**Steps**:
1. Check user request for explicit title/description; use if provided
2. If not provided:
   - Title: Use Conventional Commits format if detected by detect-conventional-commits skill
   - Description: Generate with sections (Summary, Changes, Motivation, Testing, Additional Notes)
3. Populate from commit/diff analysis

Continue to Phase 4.

---

## Phase 4: PR Content Review

**Objective**: Present generated PR content for user review and approval.

**Steps**:
1. Present: Generated PR title and description from Phase 3
2. Request approval using AskUserQuestion tool:
   - Question: "How would you like to proceed with this pull request?"
   - Header: "PR Content"
   - Options:
     - **Proceed**: "Create PR with this title and description" - Continues to Phase 5
     - **Edit title**: "Modify the PR title" - Allows title customization
     - **Edit description**: "Modify the PR description" - Allows description customization
     - **Edit both**: "Modify both title and description" - Allows full customization

**Validation Gate: Content Approval**
HANDLE user selection:
- IF "Proceed": Continue to Phase 5
- IF "Edit title":
  - User provides custom title via "Other" option
  - Validate: Title ≤ 72 chars, non-empty
  - IF invalid: Re-prompt with validation message
  - Update title, return to Step 1 to show updated PR
- IF "Edit description":
  - User provides custom description via "Other" option
  - Validate: Non-empty, markdown formatted
  - Update description, return to Step 1 to show updated PR
- IF "Edit both":
  - User provides custom title and description via "Other" option
  - Format expected: "TITLE: <title>\n\nDESCRIPTION:\n<description>"
  - Validate both components
  - Update both, return to Step 1 to show updated PR

Continue to Phase 5.

---

## Phase 5: Push to Remote

**Objective**: Push current branch to remote.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Get current branch:
   ```bash
   git branch --show-current
   ```

2. Push branch with upstream tracking:
   ```bash
   git push -u origin <branch-name>
   ```

**Validation Gate**: IF push fails:
- Analyze error:
  - "fatal: could not read Username": Authentication required
  - "error: failed to push": Rejected, may need force
  - "error: src refspec": Branch doesn't exist
  - Network errors: Connection issues
- Explain error clearly
- Propose solution:
  - Auth: "Set GITHUB_TOKEN or configure git credentials"
  - Rejected: "Check branch protection rules, may need PR approval"
  - Network: "Check internet connection and retry"
- Wait for user to resolve

Continue to Phase 6.

---

## Phase 6: Create Pull Request

**Objective**: Create PR on GitHub using MCP.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Prepare: owner, repo, head (from Phase 1), base (Phase 2), title/body (Phase 3)
2. Determine draft: Check user request for "draft", "WIP", "work in progress"
3. Create: `mcp__github__create_pull_request` with all parameters

**Error Handling**: IF failure:
- Use `mcp__sequential-thinking__sequentialthinking` to analyze
- Explain: Auth, permissions, invalid params, duplicate PR, rate limit, or network
- Propose solution and wait for retry approval

Continue to Phase 7.

---

## Phase 7: Return PR URL

**Objective**: Provide PR URL and confirm success with standardized output.

**Steps**:
1. Extract from Phase 6: PR number, URL, state, title

2. Format output using standardized template:
   ```markdown
   ✓ Pull Request Created Successfully

   **PR Number:** #<number>
   **Title:** <title>  
   **URL:** <pr_url>  
   **Status:** <Open|Draft>  
   **Base Branch:** <base_branch>  
   **Head Branch:** <head_branch>  

   [If draft: **Notes:** Mark as 'Ready for review' when ready: <pr_url>]
   [If open: **Notes:** The pull request is ready for review.]
   ```
