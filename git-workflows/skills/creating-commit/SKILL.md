---
name: creating-commit
description: Standard workflow for all commit operations ('commit', 'save changes', 'create commit', 'check in'): replaces bash-based git add/commit workflows with automated Git Safety Protocol—analyzes changes, drafts convention-aware messages, enforces mainline protection, handles pre-commit hooks safely. Canonical commit implementation for git-workflows.
---

# Skill: Creating a Commit

## When to Use This Skill

Use this skill for commit requests: "commit these changes", "create a commit", "save my work", "commit with message X".

Use other skills for: creating PRs (creating-pull-request), viewing history (git log directly).

## Workflow Description

Executes atomic commit workflow with analysis and validation gates using optimized scripts for maximum performance.

Extract from user request: commit message format ("use conventional commits" → force, default auto-detect), explicit message (if provided, else auto-generate)

---

## Phase 1: Gather Context (Optimized)

**Objective**: Collect all commit context in a single atomic operation.

**Steps**:
1. Use the gather-commit-context.sh script to collect all commit context

2. Parse the JSON response and handle results:

**IF `success: false`**:

Handle error based on `error_type`:

- **`clean_working_tree`**:
  - STOP: "Working tree is clean, nothing to commit"
  - Display: `message` field from response
  - EXIT workflow

- **`not_git_repo`**:
  - STOP: "Not in a git repository"
  - Display: `message` and `suggested_action` from response
  - EXIT workflow

- **`git_status_failed`**:
  - STOP: "Failed to retrieve git status"
  - Display: `message` from response
  - Suggested action: "Check repository integrity"
  - EXIT workflow

- **Other errors**:
  - STOP: Display error details
  - EXIT workflow

**IF `success: true`**:

Extract and store context:
```json
{
  "current_branch": "branch name",
  "mainline_branch": "main",
  "is_mainline": false,
  "uses_conventional_commits": true,
  "conventional_commits_confidence": "high",
  "working_tree_status": {...},
  "staged_files": [...],
  "unstaged_files": [...],
  "untracked_files": [...],
  "file_categories": {...},
  "recent_commits": [...],
  "diff_summary": {...}
}
```

### Validation Gate: Branch Protection

IF `is_mainline: false` (on feature branch):
  Continue to Phase 2

IF `is_mainline: true` (on mainline):
  Check user request and context:

  IF user explicitly stated commit to mainline is acceptable:
    Examples: CLAUDE.md allows mainline commits, request says "commit to main"
    INFORM: "Proceeding with mainline commit as authorized"
    Continue to Phase 2

  IF no explicit authorization:
    INVOKE: creating-branch skill
    WAIT for creating-branch skill to complete

    IF creating-branch succeeded:
      VERIFY: Now on feature branch (not mainline)
      RE-RUN Phase 1 (gather context again on new branch)
      Continue to Phase 2

    IF creating-branch failed:
      STOP immediately
      EXPLAIN: "Branch creation failed, cannot proceed with commit"
      EXIT workflow

Phase 1 complete. Continue to Phase 2.

---

## Phase 2: Commit Message Generation

**Objective**: Draft a concise, informative commit message using context from Phase 1.

**THINKING CHECKPOINT**: Use `mcp__sequential-thinking__sequentialthinking` to:
- Review file categories and diff summary from context
- Identify core purpose of changes
- Determine commit type if `uses_conventional_commits: true`
- Review recent commits for style consistency
- Draft subject (<50 chars, imperative mood) and optional body
- Review the message for conciseness and clarity
- Validate accuracy and completeness

**Commit Message Format**:
- **Conventional Commits** (if `uses_conventional_commits: true`):
  - `<type>[scope]: <description>`
  - Example: `feat(auth): add JWT token refresh`
  - Common types: feat, fix, docs, style, refactor, perf, test, chore

- **Standard** (if `uses_conventional_commits: false`):
  - `<Subject line>`
  - Example: `Add JWT token refresh mechanism`

- **Body** (optional):
  - Add only if it provides meaningful context
  - Wrap at 72 chars
  - Explain why not how

**Co-Authored-By**:
- Respect the `includeCoAuthoredBy` setting in Claude Code configuration
- IF enabled: Append trailer with Claude attribution
- Finalize: Subject + body (if any) + co-authored-by (if configured)

**Context Available** for message generation:
- `file_categories`: Types of files changed (code, tests, docs, config)
- `diff_summary`: Scale of changes (files, insertions, deletions)
- `recent_commits`: Recent commit messages for style matching
- `uses_conventional_commits`: Whether to use conventional format
- `staged_files`, `unstaged_files`, `untracked_files`: What's being committed

Continue to Phase 3.

---

## Phase 3: User Approval

**Objective**: Present commit details for user review and approval.

**Steps**:
1. Present commit details:
   - **Files to commit**: List from `staged_files` (or all if staging all)
   - **Proposed commit message**: Generated in Phase 2
   - **Change summary**: From `diff_summary` (files changed, +insertions, -deletions)

2. Display change summary (not full diff):
   - List of files changed with status (added/modified/deleted)
   - Insertions/deletions statistics from `diff_summary`
   - Do NOT show full diff content

3. Request approval using AskUserQuestion tool:
   - Question: "How would you like to proceed with this commit?"
   - Header: "Commit"
   - Options:
     - **Proceed**: "Create the commit with this message" - Continues to Phase 4
     - **Edit message**: "Modify the commit message" - Returns to Step 1 with user's custom message
     - **Cancel**: "Don't create this commit" - Stops workflow

### Validation Gate: User Approval

HANDLE user selection:
- IF "Proceed": Continue to Phase 4
- IF "Edit message":
  - User provides custom message via "Other" option
  - Apply custom message (replace generated message)
  - Return to Step 1 to show updated commit details
- IF "Cancel": STOP: "Commit cancelled by user"

---

## Phase 4: Execution

**Objective**: Stage files and create commit.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:

1. Stage files:
   ```bash
   git add .
   ```
   Or stage specific files from context if user requested selective staging.

2. Create commit with approved message:
   ```bash
   git commit -m "<approved message from Phase 3>"
   ```

**Pre-commit Hooks**:
- Git hooks execute normally
- If hooks modify files, the commit may need to be amended

**Error Handling**:

IF commit fails:
- Analyze error output
- Common issues:
  - **Pre-commit hook failed**: Review hook output for required changes
  - **Empty commit**: No staged changes, verify staging succeeded
  - **Author not set**: Configure `git config user.email` and `git config user.name`
- Explain failure and propose solution

Continue to Phase 5.

---

## Phase 5: Verification

**Objective**: Confirm commit was created successfully and provide standardized report.

**Steps**:

1. Use the verify-operation.sh script with "commit" parameter to verify the operation

2. Parse the JSON response:
   ```json
   {
     "success": true,
     "operation": "commit",
     "details": {
       "commit_hash": "abc123...",
       "short_hash": "abc123d",
       "branch": "feature-branch",
       "subject": "feat: add logging",
       "author": "User Name",
       "date": "2025-11-25 10:30:00 -0800",
       "files_changed": 3
     },
     "formatted_report": "✓ Commit Completed Successfully\n\n..."
   }
   ```

3. Display the `formatted_report` to user:
   ```markdown
   ✓ Commit Completed Successfully

   **Commit:** <short_hash>\
   **Subject:** <subject>\
   **Branch:** <branch_name>\
   **Files Changed:** <file_count>\
   **Author:** <author_name>
   ```

4. Verify: Compare subject to approved message from Phase 3; warn if differs (indicates hook modification)

Workflow complete.
