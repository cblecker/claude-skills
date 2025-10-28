---
name: syncing-branch
description: Automates branch sync with remote changes: detects fork vs origin scenarios, fetches from correct remotes, safely merges with fast-forward checks, and handles upstream remotes. Use for syncing branches or when you say 'sync branch', 'pull latest', 'get latest changes', 'sync with upstream'.
allowed-tools: [mcp__git__git_status, mcp__git__git_checkout, mcp__git__git_log, mcp__git__git_branch, Bash(git remote get-url:*), Bash(git fetch:*), Bash(git merge:*), Bash(git pull:*), Bash(git push:*)]
---

# Skill: Syncing a Branch

## When to Use This Skill

**Use this skill when the user requests:**
- "sync my branch"
- "pull latest changes"
- "sync with remote"
- "update my branch" (if intent is to pull from remote, not rebase)
- "get latest from origin/upstream"
- "sync with upstream"
- Any variation requesting to fetch and merge remote changes

**Use other skills instead when:**
- Rebasing is requested → Use rebasing-branch skill instead
- Creating a PR → Use creating-pull-request skill (which handles pushing)
- Viewing remote branches → Use git commands directly

**Disambiguation Note**: If user says "update my branch", ask whether they want to sync (fetch+merge) or rebase (rewrite history), as these are different operations with different outcomes.

---

## Workflow Description

This skill updates a branch with remote changes, automatically detecting fork vs origin scenarios and executing the appropriate sync strategy.

**Information to gather from user request:**
- Target branch: Extract if user specified a specific branch to sync (e.g., "sync develop branch" or "sync the main branch"), otherwise use current branch

---

## Phase 1: Branch Identification

**Objective**: Determine which branch to sync.

**Steps**:
1. Check user request for specific branch (e.g., "sync main")
2. If not specified: Get current via `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
3. Set target branch (specified or current)

Continue to Phase 2.

---

## Phase 2: Checkout Target Branch (Conditional)

**Objective**: Switch to target branch if needed.

**Skip**: If target equals current, skip to Phase 3

**Steps**: `mcp__git__git_checkout` with `repo_path` (cwd), `branch_name` from Phase 1

**Validation Gate**: IF checkout fails:
- Analyze: Dirty tree, branch doesn't exist, or permission issue
- Propose solution and wait for user

Continue to Phase 3.

---

## Phase 3: Detect Upstream Remote

**Objective**: Determine if repository has upstream remote (fork scenario).

**Steps**: Execute `git remote get-url upstream`
- Exit 0: Set is_fork = true, capture URL
- Exit non-zero: Set is_fork = false

Continue to Phase 4.

---

## Phase 4: Sync Execution

**Objective**: Fetch and merge changes from remote.

**Plan Mode**: Auto-enforced read-only if active

**Fork Scenario** (if is_fork = true):
Execute: `git fetch --prune --all && git pull --stat --rebase upstream <target-branch> && git push $(git config --get branch.<target-branch>.remote) <target-branch>`
Where <target-branch> is from Phase 1

**Origin-Only Scenario** (if is_fork = false):
Execute: `git fetch --prune && git merge --ff-only @{u}`
Where @{u} = upstream tracking branch

**Validation Gate**: IF sync fails:
- Explain: Network, conflicts, divergence, auth, missing branch, or no tracking
- Propose solution and wait for user

Continue to Phase 5.

---

## Phase 5: Verification

**Objective**: Confirm sync completed successfully.

**Steps**:
1. Check status: `mcp__git__git_status` with `repo_path` (cwd)
2. Verify: Working tree clean, branch up-to-date, no conflicts
3. Get recent: `mcp__git__git_log` with `repo_path` (cwd), `max_count: 5`
4. Report: Branch synced, status, recent commits

Workflow complete.
