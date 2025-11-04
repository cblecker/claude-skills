---
name: creating-branch
description: Automates feature branch creation with safety checks: syncs base branch first, generates convention-based names (detects Conventional Commits for type prefixes), handles dirty working trees with stash/commit options. Use when creating branches or when you say 'create branch', 'new branch', 'start branch for', 'make feature branch'.
---

## MCP Fallback Warning

When an MCP tool (mcp__git__*, mcp__github__*, mcp__sequential-thinking__*) is unavailable, warn user and proceed with Bash equivalent: "[Tool] unavailable - using Bash fallback (no IAM control)"

# Skill: Creating a Branch

## When to Use This Skill

**Use this skill when the user requests:**
- "create a branch"
- "make a new branch"
- "create a feature branch"
- "start a branch for X"
- "create branch called/named X"
- Any variation requesting git branch creation

**Use other skills instead when:**
- Switching to existing branches → Use mcp__git__git_checkout directly
- Listing branches → Use mcp__git__git_branch directly
- User is creating a PR and happens to be on mainline → Use creating-pull-request skill (which may invoke this skill)

---

## Workflow Description

This skill creates feature branches from a synchronized mainline base. It ensures working tree is clean, syncs the base branch, generates conventional branch names, and handles stashing if needed.

**Information to gather from user request:**
- Branch purpose/description: Extract from user's natural language (e.g., "create branch for adding metrics" → "adding metrics")
- Branch name: If user provided explicit name (e.g., "create branch called fix-auth-bug"), use it; otherwise generate from description
- Base branch: Extract if specified (e.g., "create branch from develop" or "based on staging"), otherwise use mainline
- Sync preference: Detect if user wants to skip sync (e.g., "without syncing" or "skip sync"), default is to sync

---

## Phase 1: Current State Validation

**Objective**: Check working tree status and prepare for branch creation.

**Steps**:
1. Check status: `mcp__git__git_status` with `repo_path` (cwd)
2. Get current: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
3. Note uncommitted changes: Set `has_uncommitted_changes` flag (true/false)

**Note**: Uncommitted changes will be brought forward to the new branch. If syncing the base branch is required (Phase 3), changes will be automatically stashed and restored.

Continue to Phase 2.

---

## Phase 2: Mainline Detection

**Objective**: Determine the mainline branch to use as base.

**Step 1: Determine base branch from user request**

Analyze user's request for base branch specification:
- Look for phrases like: "from <branch>", "based on <branch>", "branch off <branch>"
- Common branch names: develop, staging, main, master, release, etc.

IF base branch mentioned in user request:
  Use specified branch as base
  Set user_specified = true
  Set is_mainline based on comparison to detected mainline (for informational purposes)
  Skip Step 2

IF no base branch mentioned:
  Proceed to Step 2 to detect mainline

**Step 2: Detect mainline branch**

Command: `git ls-remote --exit-code --symref origin HEAD | sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'`
Permission: Matches `Bash(git ls-remote:*)` in allowed-tools
Purpose: Get repository's default branch (main/master/develop/etc)
Expected output: Single line with mainline branch name (e.g., "main")
Capture: Mainline branch name

Use as base branch:
  Base branch = detected mainline
  Set user_specified = false
  Set is_mainline = true

**Validation Gate: Base Branch Determined**

IF base branch successfully determined:
  PROCEED to Phase 3

IF cannot determine mainline (command failed):
  STOP immediately
  EXPLAIN: "Cannot determine mainline branch from remote"
  ASK: "Please specify which branch to create from (e.g., 'from develop' or 'based on staging')"
  WAIT for user input

Phase 2 complete. Continue to Phase 3.

---

## Phase 3: Mainline Sync (Conditional)

**Objective**: Ensure base branch is up-to-date with remote.

**Skip Condition**

Check user request for sync preference:
- Look for phrases like: "without syncing", "skip sync", "don't sync", "no sync"

IF user requested skipping sync:
  INFORM: "Skipping base branch sync as requested"
  Skip directly to Phase 4

IF no skip preference mentioned:
  Execute sync below (default behavior)

**Plan Mode Handling**

Plan mode is automatically enforced by the system. IF currently in plan mode:
- Sync operation will be read-only
- Skills invoked will operate in read-only mode
- Continue through workflow for demonstration purposes

**Step 1: Checkout base branch**

IF `has_uncommitted_changes` from Phase 1 AND current branch != base branch:
  Execute stash: `git stash push -u -m "Auto-stash before branch sync"`
  Set `stash_created = true`
ELSE:
  Set `stash_created = false`

Tool: `mcp__git__git_checkout`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_name`: Base branch from Phase 2
Permission: Requires user approval (state change operation)
Expected output: Confirmation of branch switch

IF checkout fails:
  IF stash_created: Restore stash with `git stash pop`
  STOP immediately
  EXPLAIN: "Cannot checkout base branch '<base-branch>'"
  ANALYZE error for cause (branch doesn't exist, permission denied)
  PROPOSE solution based on error
  WAIT for user to resolve

**Step 2: Sync base branch**

INVOKE: syncing-branch skill
WAIT for skill completion

**Validation Gate: Sync Success**

IF syncing-branch skill succeeded:
  INFORM: "Base branch synced successfully"
  IF stash_created:
    Note: Stash will be restored after new branch is created in Phase 5
  PROCEED to Phase 4

IF syncing-branch skill failed:
  IF stash_created: Restore stash with `git stash pop`
  STOP immediately
  EXPLAIN: "Failed to sync base branch"
  SHOW: Error reported by syncing-branch skill
  PROPOSE: "Check network connectivity, review remote status, and retry"
  WAIT for user decision

Phase 3 complete. Continue to Phase 4.

---

## Phase 4: Branch Naming

**Objective**: Generate or validate branch name following conventions.

**Steps**:
1. Detect Conventional Commits: `mcp__git__git_log` (10 commits), if 6+ match pattern, set true
2. Extract description from user request
3. Transform to kebab-case (lowercase, hyphens, alphanumerics only)
4. Add type prefix if Conventional Commits (feat/, fix/, docs/, etc. based on keywords)
5. Truncate to 47 chars if > 50, append "..."
6. Request approval using AskUserQuestion tool:
   - Question: "Which branch name would you like to use?"
   - Header: "Branch"
   - Options:
     - **Use generated**: "Use the suggested name: <generated-name>" - Uses generated name
     - **Custom name**: "Provide a different branch name" - User provides alternative
7. IF "Custom name" selected: Use the custom name provided by user via "Other" option
8. Check uniqueness: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`

**Validation Gate**: IF branch exists:
- EXPLAIN: "Branch '<branch-name>' already exists locally"
- PROPOSE: Generate alternative with numeric suffix (e.g., feat/auth-2)
- ASK: "Use alternative name '<alternative-name>' or provide custom name?"
- HANDLE user selection:
  - IF alternative accepted: Use alternative name
  - IF custom provided: Use custom name and re-check uniqueness
  - IF neither: STOP workflow

Continue to Phase 5.

---

## Phase 5: Branch Creation

**Objective**: Create and checkout new feature branch.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Create: `mcp__git__git_create_branch` with `repo_path` (cwd), `branch_name` from Phase 4, `base_branch` from Phase 2
2. Checkout: `mcp__git__git_checkout` with `repo_path` (cwd), `branch_name` from Phase 4
3. IF `stash_created` from Phase 3:
   - Restore stash: `git stash pop`
   - INFORM: "Uncommitted changes restored to new branch"
   - IF conflicts during restore:
     - EXPLAIN: "Stash conflicts detected"
     - GUIDE: Resolve conflicts in files, stage resolved files
     - Stash remains in stash list until manually dropped

**Error Handling**: IF failure:
- IF stash_created: Keep stash (don't pop) for manual recovery
- Explain: Permission, branch exists (shouldn't happen), or base invalid
- Propose solution and wait for retry approval

Continue to Phase 6.

---

## Phase 6: Verification

**Objective**: Confirm new branch was created and checked out.

**Steps**:
1. Verify: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
2. Compare to expected from Phase 4
3. Report: Branch name, base, status

**Validation Gate**: IF current ≠ expected:
- STOP: Checkout verification failed
- Propose manual checkout

IF stash created in Phase 1: Continue to Phase 6.5
ELSE: Workflow complete

---

## Phase 6.5: Stash Restoration (Conditional)

**Objective**: Restore stashed changes if auto-stash was used.

**Skip**: IF stash_created = false

**Steps**:
1. Inform user about stashed changes
2. Ask: "Restore stashed changes? (yes/no)"
3. IF yes: Execute `git stash pop`
   - Success: Report changes restored
   - Conflicts: Guide resolution (edit files, stage, verify)
4. IF no: Inform stash preserved as 'stash@{0}'

Workflow complete.
