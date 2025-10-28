---
name: rebasing-branch
description: Rebase git branches to incorporate latest changes from base branch. Use when rebasing, updating branch history, or when you say 'rebase my branch', 'rebase on main', 'rebase onto', or 'update my branch' (for rebase not merge).
allowed-tools: [mcp__git__git_status, mcp__git__git_checkout, mcp__git__git_log, mcp__git__git_branch, Bash(git ls-remote:*), Bash(git merge-base:*), Bash(git rebase:*)]
---

# Skill: Rebasing a Branch

## When to Use This Skill

**Use this skill when the user requests:**
- "rebase my branch"
- "rebase on main/master"
- "rebase onto X"
- "update my branch with main" (if intent is to rebase, not sync)
- Any variation requesting git rebase operation

**Use other skills instead when:**
- Syncing is requested → Use syncing-branch skill for fetch+merge (preserves history)
- User is on mainline branch → Cannot rebase mainline (mainline should never be rebased)
- Viewing rebase status → Use git status directly

**Disambiguation Note**: If user says "update my branch", ask whether they want to sync (fetch+merge, preserves history) or rebase (rewrites history), as these are fundamentally different operations.

---

## Workflow Description

This skill rebases a feature branch onto updated mainline, rewriting commit history to incorporate latest changes from the base branch. It handles state preservation, conflict resolution, and optional author date reset.

**Information to gather from user request:**
- Target branch: Extract if specified (e.g., "rebase onto develop" or "rebase on staging"), otherwise use mainline
- Author date preference: Detect if user wants to preserve dates (e.g., "keep author dates" or "preserve dates"), default is to reset dates

---

## Phase 1: Pre-flight Checks

**Objective**: Verify environment is ready for rebase operation.

**Step 1: Get current branch**

Tool: `mcp__git__git_branch`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_type`: "local"
Permission: Auto-approved (read-only MCP tool)
Expected output: List of local branches with current branch indicated
Capture: Current branch name (the branch marked as current)

**Step 2: Get mainline branch**

Command: `git ls-remote --exit-code --symref origin HEAD | sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'`
Permission: Matches `Bash(git ls-remote:*)` in allowed-tools
Purpose: Get repository's default branch name (main/master/develop/etc)
Expected output: Single line with mainline branch name (e.g., "main")
Capture: Mainline branch name

**Step 3: Compare current branch to mainline**

Compare captured branch names to determine if on mainline.

**Step 4: Check working tree status**

Tool: `mcp__git__git_status`
Parameters:
- `repo_path`: Current working directory absolute path
Permission: Auto-approved (read-only MCP tool)
Expected output: Status showing working tree state
Capture: Working tree clean status

**Validation Gate: Safe to Rebase**

IF current branch equals mainline:
  STOP immediately
  EXPLAIN: "Cannot rebase the mainline branch. Mainline should never be rebased as it's the stable reference point for all feature branches."
  INFORM: "Rebasing mainline would rewrite its history and break all feature branches based on it."
  PROPOSE: "Create a feature branch first if you need to test changes"
  EXIT workflow

IF current branch is not mainline AND working tree has uncommitted changes:
  STOP immediately
  EXPLAIN: "Cannot rebase with uncommitted changes. Rebase rewrites history and requires a clean working tree."
  PROPOSE: "Choose how to proceed:"
  SHOW options:
    1. "Commit changes using creating-commit skill"
    2. "Stash changes temporarily with `git stash push -u`"
    3. "Cancel workflow"
  WAIT for user to resolve uncommitted changes

IF current branch is not mainline AND working tree is clean:
  PROCEED to Phase 2

Phase 1 complete. Continue to Phase 2.

---

## Phase 2: Save State

**Objective**: Remember current branch for later checkout.

**CRITICAL**: Store SAVED_BRANCH = current branch from Phase 1
- Must preserve through all phases
- After Phase 4, ALWAYS use SAVED_BRANCH (not "current branch")

Continue to Phase 3.

---

## Phase 3: Determine Rebase Base

**Objective**: Identify which branch to rebase onto.

**Step 1: Determine rebase target from user request**

Analyze user's request for target branch specification:
- Look for phrases like: "rebase onto <branch>", "rebase on <branch>", "rebase against <branch>"
- Common branch names: main, master, develop, staging, release, etc.

IF target branch mentioned in user request:
  Use specified branch as rebase base
  Set user_specified = true

IF no target branch mentioned:
  Use mainline branch from Phase 1 as rebase base
  Set user_specified = false

**Step 2: Store rebase base**

REBASE_BASE = specified branch or mainline from Phase 1

Phase 3 complete. Continue to Phase 4.

---

## Phase 4: Checkout Base Branch

**Objective**: Switch to base branch for syncing.

**Step 1: Checkout base branch**

Tool: `mcp__git__git_checkout`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_name`: Rebase base from Phase 3
Permission: Requires user approval (state change operation)
Expected output: Confirmation of branch switch

**Error Handling**

IF checkout succeeds:
  PROCEED to Phase 5

IF checkout fails:
  STOP immediately

  EXPLAIN error clearly to user:
  - IF branch doesn't exist: "Base branch '<rebase-base>' does not exist locally"
  - IF permission denied: "Permission denied accessing repository or branch"

  PROPOSE solution:
  - IF branch doesn't exist: "Verify branch name spelling with `git branch -a` or create it"
  - IF permission: "Check repository access and file permissions"

  WAIT for user decision

Phase 4 complete. Continue to Phase 5.

---

## Phase 5: Sync Base Branch

**Objective**: Ensure base branch is up-to-date with remote.

**Plan Mode Handling**

Plan mode is automatically enforced by the system. IF currently in plan mode:
- Sync operation will be read-only
- Skills invoked will operate in read-only mode
- Continue through workflow for demonstration purposes

**Step 1: Invoke syncing-branch skill**

INVOKE: syncing-branch skill
WAIT for skill completion

**Validation Gate: Sync Success**

IF syncing-branch skill succeeded:
  INFORM: "Base branch synced successfully with remote"
  PROCEED to Phase 6

IF syncing-branch skill failed:
  STOP immediately
  EXPLAIN: "Failed to sync base branch with remote"
  SHOW: Error reported by syncing-branch skill
  PROPOSE solution:
    - "Check network connectivity"
    - "Review remote branch status"
    - "Retry sync operation"
  WAIT for user decision

Phase 5 complete. Continue to Phase 6.

---

## Phase 6: Return to Feature Branch

**Objective**: Switch back to feature branch for rebase.

**CRITICAL: Use Saved State**

Retrieve saved branch from Phase 2:
- Use SAVED_BRANCH from preserved state
- DO NOT use "current branch" (we're on base branch now)
- This is why state preservation in Phase 2 is critical

**Step 1: Checkout feature branch**

Tool: `mcp__git__git_checkout`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_name`: SAVED_BRANCH from Phase 2 (NOT current branch)
Permission: Requires user approval (state change operation)
Expected output: Confirmation of checkout

**Error Handling**

IF checkout succeeds:
  PROCEED to Phase 7

IF checkout fails:
  STOP immediately (CRITICAL FAILURE)

  EXPLAIN: "Cannot return to feature branch - workflow interrupted mid-operation"
  INFORM: "You are currently on base branch: [rebase base name from Phase 3]"
  INFORM: "Your feature branch: [saved branch from Phase 2]"
  PROPOSE: "Manually checkout your feature branch with: `git checkout [saved branch]`"

  WORKFLOW FAILED - Manual intervention required

Phase 6 complete. Continue to Phase 7.

---

## Phase 7: Rebase Execution

**Objective**: Perform the actual rebase operation.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Execute: `git rebase <rebase-base>` (from Phase 3)
2. Check exit code

**Validation Gate**:
- IF success (exit 0): Continue to Phase 8
- IF conflicts: PAUSE workflow (normal, not failure)
  - Guide: Edit files, remove markers, `git add`, `git rebase --continue` or `--abort`
  - Wait for user resolution
- IF other error: Explain and propose solution

**Note**: Conflicts are normal, not failures. Workflow PAUSED ≠ FAILED.

Continue to Phase 8.

---

## Phase 8: Reset Author Dates (Conditional)

**Objective**: Update author dates to current time.

**Skip**: IF user requested preserving dates

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Find fork point: `git merge-base --fork-point <rebase-base>` (from Phase 3)
2. Reset dates: `git rebase <fork-point> --reset-author-date`
3. Check exit code

**Validation Gate**: IF reset fails:
- Warn: Rebase succeeded but date reset failed
- Ask to continue without reset or abort

Continue to Phase 9.

---

## Phase 9: Verification

**Objective**: Confirm rebase completed successfully.

**Steps**:
1. Verify: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
2. Compare to SAVED_BRANCH from Phase 2
3. Check status: `mcp__git__git_status` with `repo_path` (cwd)
4. Get recent: `mcp__git__git_log` with `repo_path` (cwd), `max_count: 5`
5. Report: Branch, rebased onto, author dates status, recent commits (SHAs changed)

**Validation Gate**: IF current ≠ SAVED_BRANCH:
- STOP: Branch state inconsistent
- Propose manual checkout

**Important**: Inform user force push required: `git push --force-with-lease origin [branch]`

Workflow complete.
