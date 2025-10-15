---
description: Feature branch creation workflow with mainline sync and validation
---

# Branch Creation Workflow

[Extended thinking: This workflow creates feature branches from a synchronized mainline. The philosophy is to always start from latest mainline state unless explicitly overridden. Syncing mainline first (Phase 3) prevents creating branches from stale base, reducing future merge conflicts. Branch naming uses sequential-thinking to transform natural descriptions into conventional names (feat/, fix/, refactor/, etc.). Working tree must be clean to avoid confusion about which changes belong on which branch. The workflow enforces best practices while remaining flexible via flags.]

You are executing the **branch creation workflow**. Follow this deterministic, phase-based procedure exactly. Do not deviate from the specified steps or validation gates.

## Workflow Configuration

**Required Input:**
- Branch name (from user description or direct request)

**Optional Input:**
- `--from <branch>`: Create from specific branch instead of mainline
- `--no-sync`: Skip syncing mainline before creation

## Phase 1: Current State Validation

**Objective**: Verify working tree is clean and ready for branch operations.

**Steps:**
1. **Check working tree status using MCP for IAM control**:
   - Use `mcp__git__git_status`
   - repo_path: Current working directory
   - Rationale: Enables users to auto-approve status checks in settings.json for autonomous operation

2. **Get current branch** using bash:
   - `git branch --show-current`

**Validation Gate: Clean Working Tree**
```
IF working tree has uncommitted changes:
  STOP: "Cannot create branch with uncommitted changes"
  PROPOSE: "Commit or stash changes first using /commit"
  WAIT for user to resolve
ELSE:
  PROCEED to Phase 2
```

**Required Output (JSON):**
```json
{
  "phase": "current-state-validation",
  "status": "success",
  "data": {
    "working_tree_clean": true,
    "current_branch": "<branch-name>",
    "has_uncommitted_changes": false
  },
  "next_phase": "mainline-detection"
}
```

## Phase 2: Mainline Detection

**Objective**: Determine the mainline branch to use as base.

**Steps:**
1. **Check if `--from <branch>` flag was provided**:
   - IF provided: Use specified branch as base
   - ELSE: Detect mainline

2. **Detect mainline branch** (§ git-ops.md Mainline Detection):
   - This returns the repository's default branch (main/master)

**Validation Gate: Mainline Exists**
```
IF mainline branch cannot be determined:
  STOP: "Cannot determine mainline branch"
  ASK: User to specify base branch with --from flag
  WAIT for user input
ELSE:
  PROCEED to Phase 3
```

**Required Output (JSON):**
```json
{
  "phase": "mainline-detection",
  "status": "success",
  "data": {
    "base_branch": "main",
    "is_mainline": true,
    "user_specified": false
  },
  "next_phase": "mainline-sync"
}
```

## Phase 3: Mainline Sync (Conditional)

**Objective**: Ensure base branch is up-to-date with remote.

**Skip Condition:**
- IF `--no-sync` flag present: Skip to Phase 4
- ELSE: Execute sync

**Validation Gate: Plan Mode Check** (before sync)
```
IF in plan mode:
  STOP: "Cannot sync branch in plan mode"
  EXPLAIN: This workflow would sync mainline branch:
    - Checkout base branch [base branch name]
    - Execute sync command (git sync or git sync-upstream)
    - Push changes to remote
  INFORM: "Exit plan mode to execute branch creation workflow"
  EXIT workflow
ELSE:
  PROCEED to sync
```

**Steps:**
1. **Checkout base branch using MCP for IAM control**:
   - Use `mcp__git__git_checkout`
   - repo_path: Current working directory
   - branch_name: Base branch from Phase 2
   - Rationale: Requires user approval for state changes; maintains explicit control over branch switching

2. **Detect upstream remote using bash**:
   - `git remote get-url upstream >/dev/null 2>&1`
   - IF exit code 0: upstream exists
   - ELSE: upstream does not exist

3. **Sync base branch using bash** (no MCP equivalent):
   - **IF upstream exists**:
     - `git sync-upstream` (custom alias) OR
     - `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push $(git config --get branch.$(git branch --show-current).remote) $(git branch --show-current)`
   - **ELSE**:
     - `git fetch --prune && git merge --ff-only @{u}`
     - Fetches and fast-forwards current branch from tracking remote

4. **Verify sync successful**:
   - Check command exit code
   - IF non-zero: Sync failed

**Validation Gate: Sync Success**
```
IF sync command failed:
  STOP: "Failed to sync base branch"
  THINK about error (consider using sequential-thinking)
  EXPLAIN error to user
  PROPOSE solution
  WAIT for user decision
ELSE:
  PROCEED to Phase 4
```

**Required Output (JSON):**
```json
{
  "phase": "mainline-sync",
  "status": "success",
  "data": {
    "sync_executed": true,
    "upstream_exists": false,
    "sync_command": "git sync",
    "sync_successful": true
  },
  "next_phase": "branch-naming"
}
```

## Phase 4: Branch Naming

**Objective**: Generate or validate branch name following conventions.

**Thinking Checkpoint (RECOMMENDED):**
THINKING CHECKPOINT: Use `mcp__sequential-thinking` to:
1. Understand the purpose/description of the work
2. Extract key concepts and scope
3. Transform into descriptive kebab-case name
4. Ensure name is clear and follows project conventions
5. Verify 95%+ confidence in name appropriateness

**Branch Naming Rules:**
- Use kebab-case (lowercase with hyphens)
- Be descriptive but concise (under 50 characters)
- Include type prefix if Conventional Commits is used:
  - `feat/` - New features
  - `fix/` - Bug fixes
  - `refactor/` - Code refactoring
  - `docs/` - Documentation
  - `test/` - Tests
  - `chore/` - Maintenance

**Examples:**
- `fix-authentication-bug`
- `feat/add-metrics-export`
- `refactor/cleanup-api-handlers`

**Steps:**
1. **IF user provided explicit branch name**:
   - Validate format (kebab-case, no spaces)
   - Use as-is if valid

2. **ELSE generate from description**:
   - Extract work description from user request
   - Transform to kebab-case
   - Add type prefix if applicable

3. **Check if branch already exists using MCP**:
   - Use `mcp__git__git_branch` (repo_path: cwd, branch_type: "local")
   - Parse output for branch name

**Validation Gate: Branch Name Unique**
```
IF branch name already exists locally:
  STOP: "Branch '<name>' already exists"
  PROPOSE: Alternative name or switch to existing branch
  WAIT for user decision
ELSE:
  PROCEED to Phase 5
```

**Required Output (JSON):**
```json
{
  "phase": "branch-naming",
  "status": "success",
  "data": {
    "branch_name": "feat/add-metrics-export",
    "generated": true,
    "type_prefix": "feat",
    "already_exists": false
  },
  "next_phase": "branch-creation"
}
```

## Phase 5: Branch Creation

**Objective**: Create and checkout new feature branch using MCP tools.

**Validation Gate: Plan Mode Check**
```
IF in plan mode:
  STOP: "Cannot create branch in plan mode"
  EXPLAIN: This workflow would perform write operations:
    - Create new branch: [branch name from Phase 4]
    - Checkout new branch
  INFORM: "Exit plan mode to execute branch creation"
  EXIT workflow
ELSE:
  PROCEED to branch creation
```

**Steps:**
1. **Create branch using MCP for IAM control**:
   - Use `mcp__git__git_create_branch`
   - repo_path: Current working directory
   - branch_name: Branch name from Phase 4
   - base_branch: Base branch from Phase 2
   - Rationale: Requires user approval for write operations; prevents accidental branch creation

2. **Checkout new branch using MCP for IAM control**:
   - Use `mcp__git__git_checkout`
   - repo_path: Current working directory
   - branch_name: Branch name from Phase 4
   - Rationale: Requires user approval for state changes; maintains explicit control
   - Note: MCP git_create_branch does NOT automatically checkout

**Error Handling:**
```
IF MCP tool fails:
  STOP immediately
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error clearly to user
  PROPOSE solution with reasoning
  ASK for confirmation before retry
  EXPLAIN why any defaults were overridden
ELSE:
  PROCEED to Phase 6
```

**Required Output (JSON):**
```json
{
  "phase": "branch-creation",
  "status": "success",
  "data": {
    "branch_created": true,
    "branch_checked_out": true,
    "mcp_tools_used": true,
    "bash_fallback_used": false
  },
  "next_phase": "verification"
}
```

## Phase 6: Verification

**Objective**: Confirm new branch was created and checked out successfully.

**Steps:**
1. **Verify current branch using bash**:
   - `git branch --show-current`
   - Should match branch name from Phase 4

2. **Report success to user**:
   ```
   Feature branch created successfully

   Branch: feat/add-metrics-export
   Base: main
   Status: Ready for development

   You can now start making changes to this branch.
   ```

**Validation Gate: Branch Active**
```
IF current branch != expected branch:
  STOP: "Branch creation succeeded but checkout failed"
  EXPLAIN discrepancy to user
  PROPOSE manual checkout
ELSE:
  WORKFLOW COMPLETE
```

**Required Output (JSON):**
```json
{
  "phase": "verification",
  "status": "complete",
  "data": {
    "current_branch": "feat/add-metrics-export",
    "verified": true,
    "ready_for_work": true
  },
  "workflow_complete": true
}
```

## Critical Constraints

**YOU MUST FOLLOW THESE RULES:**

1. **MCP Tools Required for IAM Control**:
   - `mcp__git__git_status` - Status checks (read-only, safely auto-approved)
   - `mcp__git__git_checkout` - Branch switching (state change, requires approval)
   - `mcp__git__git_create_branch` - Branch creation (write operation, requires approval)
   - `mcp__git__git_branch` - List branches (read-only, safely auto-approved)
   - Rationale: Enables users to configure autonomous operation for read-only tasks while maintaining explicit approval for state changes

2. **Bash Allowed ONLY** for operations without MCP equivalent:
   - `git branch --show-current` - Get current branch
   - `git ls-remote` - Get mainline branch (§ git-ops.md Mainline Detection)
   - `git sync-upstream` - Sync with upstream (custom alias, fallback: `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push ...`)
   - `git fetch --prune && git merge --ff-only @{u}` - Simple sync with tracking remote
   - `git remote get-url` - Check for upstream (§ git-ops.md Upstream Detection)

3. **Validation Gates are MANDATORY**:
   - DO NOT proceed if gate condition fails
   - STOP and explain to user
   - Propose corrective action
   - Wait for user decision

4. **Structured State Required**:
   - Output JSON after each phase
   - Pass data to next phase
   - Maintain state throughout workflow

5. **Thinking Checkpoints**:
   - Use `mcp__sequential-thinking` for:
     - Branch name generation (Phase 4)
     - Error analysis (Phase 5)
   - Aim for 95%+ confidence in all decisions

6. **Error Transparency**:
   - Explain WHY any error occurred
   - Explain WHY any default was overridden
   - Provide clear path forward
   - Never silently fail or proceed

## Success Criteria

- All phases completed successfully
- All validation gates passed
- Working tree was clean before operation
- Base branch synced with remote (unless --no-sync)
Branch name follows conventions
- New branch created and checked out using MCP tools
- Structured JSON state maintained throughout

## Failure Scenarios

- Uncommitted changes present → Ask user to commit or stash
- Cannot determine mainline → Ask user for base branch
- Sync fails → Analyze error, propose solution
- Branch name already exists → Propose alternative or switch
- MCP tool unavailable → Stop and report error (no bash fallback)
- Branch creation succeeds but checkout fails → Manual intervention needed
