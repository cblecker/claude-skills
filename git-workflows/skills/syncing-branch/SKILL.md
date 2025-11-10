---
name: syncing-branch
description: Automates branch sync with remote changes: detects fork vs origin scenarios, fetches from correct remotes, safely merges with fast-forward checks, handles upstream remotes. Use for syncing branches or saying 'sync branch', 'pull latest', 'get latest changes', 'sync with upstream'.
---

# Skill: Syncing a Branch

## When to Use This Skill

Use this skill for sync requests: "sync my branch", "pull latest", "sync with remote", "update my branch", "get latest from origin/upstream".

Use other skills for: rebasing (rebasing-branch), creating PRs (creating-pull-request), viewing remotes (git commands).

**Disambiguation**: "update my branch" → ask if sync (fetch+merge) or rebase (rewrite history).

## Workflow Description

Updates branch with remote changes, auto-detecting fork vs origin scenarios.

Extract from user request: target branch (if specified, else current)

---

## Phase 1: Branch Identification

**Objective**: Determine which branch to sync.

**Steps**:
1. Check user request for specific branch (e.g., "sync main", "sync the develop branch")

2. IF branch specified in request:
     Use specified branch as target
   ELSE:
     Get current branch:
     ```bash
     git branch --show-current
     ```
     Use current as target

Continue to Phase 2.

---

## Phase 2: Checkout Target Branch (Conditional)

**Objective**: Switch to target branch if needed.

**Skip**: If target equals current from Phase 1

**Steps**:
1. Checkout target branch:
   ```bash
   git checkout <target-branch>
   ```

**Validation Gate**: IF checkout fails:
- Analyze error:
  - "error: pathspec '...' did not match": Branch doesn't exist
  - "error: Your local changes": Dirty working tree
  - Other: Permission issues
- Explain error
- Propose solution:
  - Doesn't exist: "Create branch first or verify name"
  - Dirty tree: "Commit or stash changes before switching branches"
  - Permission: "Check repository access"
- Wait for user to resolve

Continue to Phase 3.

---

## Phase 3: Detect Repository Type

**Objective**: Determine sync strategy based on repository structure.

**Steps**:
1. Invoke repository-type skill:
   - Receive structured result with is_fork flag
   - Store for Phase 4 sync strategy selection

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
1. Check status:
   ```bash
   git status --porcelain
   ```

2. Verify working tree clean (empty output)

3. Get recent commits:
   ```bash
   git log --oneline -5
   ```

4. Check upstream status:
   ```bash
   git status -sb
   ```
   Look for: "## <branch>...origin/<branch>" with no ahead/behind indicators

5. Report using template:
   ```text
   ✓ Branch Synced Successfully

   Branch: <branch_name>
   Status: In sync with remote
   Working tree: <Clean|Dirty>
   ```


Workflow complete.
