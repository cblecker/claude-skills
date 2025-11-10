---
name: creating-branch
description: Automates feature branch creation with safety checks: determines base branch, generates convention-based names, preserves uncommitted changes. Use when creating branches or saying 'create branch', 'new branch', 'start branch for', 'make feature branch'.
---

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
- Switching to existing branches → Use `git checkout` directly
- Listing branches → Use `git branch` directly
- User is creating a PR and happens to be on mainline → Use creating-pull-request skill (which may invoke this skill)

---

## Workflow Description

This skill creates feature branches from the current state, preserving any uncommitted changes. It generates conventional branch names based on repository conventions and validates uniqueness.

**Information to gather from user request:**
- Branch purpose/description: Extract from user's natural language (e.g., "create branch for adding metrics" → "adding metrics")
- Branch name: If user provided explicit name (e.g., "create branch called fix-auth-bug"), use it; otherwise generate from description
- Base branch: Extract if specified (e.g., "create branch from develop" or "based on staging"), otherwise use mainline

---

## Phase 1: Current State Validation

**Objective**: Check current branch state.

**Steps**:
1. Get current branch:
   ```bash
   git branch --show-current
   ```

2. Check working tree status:
   ```bash
   git status --porcelain
   ```

3. Note state:
   - current_branch: Captured branch name
   - has_uncommitted: true if status output not empty, false otherwise

**Note**: Uncommitted changes will automatically carry forward to the new branch when it's created. No stashing is needed.

Continue to Phase 2.

---

## Phase 2: Determine Base Branch

**Objective**: Identify which branch to create from.

**Step 1: Check user request for base branch**

Analyze user's request for base branch specification:
- Look for phrases like: "from <branch>", "based on <branch>", "branch off <branch>"
- Common branch names: develop, staging, main, master, release, etc.

IF base branch specified in user request:
  Use specified branch as base
  Continue to Phase 3

IF no base branch mentioned:
  Invoke mainline-branch skill to detect default branch
  Use detected mainline as base
  Continue to Phase 3

**Validation Gate: Base Branch Determined**

IF base branch successfully determined:
  PROCEED to Phase 3

IF cannot determine base branch:
  STOP immediately
  EXPLAIN: "Cannot determine which branch to create from"
  ASK: "Please specify base branch (e.g., 'from develop' or 'based on main')"
  WAIT for user input

Phase 2 complete. Continue to Phase 3.

---

## Phase 3: Branch Naming

**Objective**: Generate or use branch name following conventions.

**Steps**:
1. Check if user provided explicit branch name:
   - Look for phrases: "called <name>", "named <name>", "create branch <name>"
   - IF explicit name found: Use it, skip to uniqueness check (Step 5)

2. IF no explicit name: Invoke detect-conventional-commits skill
   - Receive structured result with uses_conventional_commits flag

3. Extract description from user request:
   - Example: "create branch for adding metrics" → "adding metrics"
   - Example: "new branch to fix auth bug" → "fix auth bug"

4. Generate branch name:
   - Transform to kebab-case (lowercase, hyphens, alphanumerics only)
   - IF uses_conventional_commits = true: Add type prefix based on keywords
     - "fix", "bug", "error" → fix/
     - "add", "new", "feature" → feat/
     - "docs", "documentation" → docs/
     - "test", "testing" → test/
     - "refactor", "cleanup" → refactor/
     - "perf", "performance" → perf/
     - "ci", "build", "deploy" → ci/
     - "chore", "maintenance" → chore/
   - IF standard format: Use description without prefix
   - Truncate to 47 chars if > 50, append "..."

5. Check uniqueness:
   ```bash
   git rev-parse --verify <branch-name> 2>/dev/null
   ```
   - Exit 0: Branch exists
   - Exit 128: Branch does not exist (good)

**Validation Gate: Branch Availability**

IF branch does not exist:
  Continue to Phase 4

IF branch exists:
  EXPLAIN: "Branch '<branch-name>' already exists locally"
  PROPOSE: Generate alternative with numeric suffix (e.g., feat/auth-2)
  Generate alternative:
    - Append "-2", check again
    - If exists, increment: "-3", "-4", etc.
    - Stop at "-9", ask user for custom name
  Use alternative name
  Continue to Phase 4

Phase 3 complete. Continue to Phase 4.

---

## Phase 4: Branch Creation

**Objective**: Create and checkout new feature branch.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Create and checkout branch:
   ```bash
   git checkout -b <branch-name>
   ```

   This creates the branch from current HEAD and checks it out.
   Uncommitted changes automatically carry forward.

**Error Handling**: IF failure:
- Explain error:
  - "fatal: A branch named '...' already exists": Branch exists (shouldn't happen after uniqueness check)
  - "error: pathspec '...' did not match": Invalid branch name characters
  - Other: Permission issues or repository problems
- Propose solution and wait for retry approval

Continue to Phase 5.

---

## Phase 5: Verification

**Objective**: Confirm new branch was created and checked out.

**Steps**:
1. Verify current branch:
   ```bash
   git branch --show-current
   ```

2. Compare to expected branch name from Phase 3

3. Report:
   - Branch name: <branch-name>
   - Created from: <base-branch from Phase 2>
   - Uncommitted changes: Preserved (if any existed)

**Validation Gate**: IF current branch does not match expected:
- STOP: "Branch creation verification failed"
- SHOW: Expected vs actual branch
- PROPOSE: "Manually checkout branch with: `git checkout <expected-branch>`"

Workflow complete.
