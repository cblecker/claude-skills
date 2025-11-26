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

## Phase 1-3: Gather Context (Optimized)

**Objective**: Collect all commit context in a single atomic operation.

**Steps**:
1. Execute gather-commit-context script:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/scripts/gather-commit-context.sh"
   ```

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
  "gpg_signing_enabled": true,
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

**Validation Gate: Branch Protection**

IF `is_mainline: false` (on feature branch):
  Continue to Phase 4

IF `is_mainline: true` (on mainline):
  Check user request and context:

  IF user explicitly stated commit to mainline is acceptable:
    Examples: CLAUDE.md allows mainline commits, request says "commit to main"
    INFORM: "Proceeding with mainline commit as authorized"
    Continue to Phase 4

  IF no explicit authorization:
    INFORM: "Currently on mainline branch - creating feature branch first"
    INVOKE: creating-branch skill
    WAIT for creating-branch skill to complete

    IF creating-branch succeeded:
      VERIFY: Now on feature branch (not mainline)
      RE-RUN Phase 1-3 (gather context again on new branch)
      Continue to Phase 4

    IF creating-branch failed:
      STOP immediately
      EXPLAIN: "Branch creation failed, cannot proceed with commit"
      EXIT workflow

Phase 1-3 complete. Continue to Phase 4.

---

## Phase 4: Commit Message Generation

**Objective**: Draft a concise, informative commit message using context from Phase 1-3.

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

Continue to Phase 5.

---

## Phase 5: User Approval

**Objective**: Present commit details for user review and approval.

**Steps**:
1. Present commit details:
   - **Files to commit**: List from `staged_files` (or all if staging all)
   - **Proposed commit message**: Generated in Phase 4
   - **Change summary**: From `diff_summary` (files changed, +insertions, -deletions)

2. Handle diff display:
   ```bash
   git diff HEAD
   ```
   - If < 100 lines: Show full diff
   - If ≥ 100 lines: Ask user if they want to see it

3. Request approval using AskUserQuestion tool:
   - Question: "How would you like to proceed with this commit?"
   - Header: "Commit"
   - Options:
     - **Proceed**: "Create the commit with this message" - Continues to Phase 6
     - **Edit message**: "Modify the commit message" - Returns to Step 1 with user's custom message
     - **Cancel**: "Don't create this commit" - Stops workflow

**Validation Gate: User Approval**

HANDLE user selection:
- IF "Proceed": Continue to Phase 6
- IF "Edit message":
  - User provides custom message via "Other" option
  - Apply custom message (replace generated message)
  - Return to Step 1 to show updated commit details
- IF "Cancel": STOP: "Commit cancelled by user"

---

## Phase 6: Execution (MCP Tools)

**Objective**: Stage files and create commit using MCP git tools.

**Plan Mode**: Auto-enforced read-only if active

**MCP Tool Usage**:

This phase uses MCP git tools which run outside the sandbox and handle GPG signing, git hooks, and SSH authentication automatically. No sandbox bypass needed!

**Steps**:

1. Stage files using MCP:
   ```
   Use mcp__git-workflows_git__git_add tool
   Parameters: {
     "pathspecs": ["."]  // or specific files from context
   }
   ```

2. Create commit using MCP:
   ```
   Use mcp__git-workflows_git__git_commit tool
   Parameters: {
     "message": "<approved message from Phase 5>"
   }
   ```

**Automatic Features via MCP**:
- ✓ GPG signing (if `gpg_signing_enabled: true` from context) works automatically
- ✓ Git hooks execute normally
- ✓ No sandbox bypass required
- ✓ Secure and reliable

**Error Handling**:

IF MCP tools are unavailable:
- ABORT immediately with clear error:
  ```
  Error: Git MCP server unavailable

  The git-workflows plugin requires the MCP git server to function.

  Please ensure:
  - npx/npm is installed and available
  - MCP server can start (check: npx @modelcontextprotocol/server-git)

  For assistance, see: https://github.com/modelcontextprotocol/servers
  ```
- NO fallback to bash commands

IF commit fails:
- Analyze error output from MCP tool
- Explain: what failed, why, and potential impact
- Common issues: pre-commit hooks failed, empty commit, GPG signing issues
- Propose solution and ask user to retry or handle manually

Continue to Phase 7.

---

## Phase 7: Verification

**Objective**: Confirm commit was created successfully and provide standardized report.

**Steps**:

1. Execute verify-operation script:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/scripts/verify-operation.sh" commit
   ```

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

   **Commit:** <short_hash>

   **Subject:** <subject>

   **Branch:** <branch_name>

   **Files Changed:** <file_count>

   **Author:** <author_name>
   ```

4. Verify: Compare subject to approved message from Phase 5; warn if differs (indicates hook modification)

Workflow complete.

---

## Implementation Notes

### Performance Improvements

This updated skill uses the optimized scripting architecture:

**Tool Call Reduction:**
- Before: ~17 tool calls (Phases 1-3: ~10, Phase 6: 2-3, Phase 7: 3-4)
- After: 4-5 tool calls (Phase 1-3: 1, Phase 4: 1 sequential-thinking, Phase 6: 2 MCP, Phase 7: 1)
- **Reduction: 75-80%**

**Execution Speed:**
- Context gathering: 10-12 operations → 1 atomic script call
- Verification: 3-4 operations → 1 atomic script call
- Overall: 3-5x faster

### MCP vs Bash for Commits

The skill now uses MCP git tools for commit operations instead of bash commands:

**Why MCP?**
1. **No sandbox bypass needed**: MCP tools run outside sandbox with proper permissions
2. **Automatic GPG signing**: Works seamlessly if configured
3. **Git hooks support**: Pre-commit hooks execute normally
4. **SSH authentication**: Works for commit signatures if configured
5. **Structured errors**: Better error handling
6. **Safer**: No dangerouslyDisableSandbox flag required

**Previous Approach (Deprecated)**:
- Used `dangerouslyDisableSandbox: true` for git commands
- Required manual GPG socket handling
- Risk of permission issues

**Current Approach**:
- MCP tools handle all complexity
- Guaranteed to work if MCP is configured
- Simple abort if MCP unavailable

### Context Data Structure

The `gather-commit-context.sh` script provides comprehensive context:

- **Branch info**: Current branch, mainline branch, is_mainline flag
- **Git config**: GPG signing enabled
- **Conventions**: Conventional commits usage and confidence level
- **Working tree**: Staged, unstaged, untracked files
- **File categorization**: Code, tests, docs, config, other
- **Diff summary**: Files changed, insertions, deletions
- **Recent commits**: For style matching

All gathered in a single atomic operation for optimal performance.
