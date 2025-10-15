---
description: Rebase workflow with mainline sync, conflict handling, and author date reset
---

# Rebase Workflow

[Extended thinking: This workflow rebases a feature branch onto updated mainline, a common operation that rewrites commit history. The critical challenge is maintaining context through multiple branch checkouts: we start on feature branch, checkout mainline to sync it, then return to feature branch for rebase. State preservation (Phase 2) is essential to avoid losing track of which branch we're working on. The workflow handles conflicts gracefully by pausing (not failing) to let user resolve, then continues. Author date reset is optional but recommended for cleaner history. Syncing mainline first ensures we're rebasing onto latest upstream state.]

You are executing the **rebase workflow**. Follow this deterministic, phase-based procedure exactly. Do not deviate from the specified steps or validation gates.

## Workflow Configuration

**Optional Input:**
- `--onto <branch>`: Rebase onto specific branch instead of mainline
- `--skip-author-date-reset`: Skip resetting author dates after rebase

## Phase 1: Pre-flight Checks

**Objective**: Verify environment is ready for rebase operation.

**Steps:**
1. **Get current branch** using bash:
   - `git branch --show-current`

2. **Get mainline branch** (§ git-ops.md Mainline Detection)

3. **Check if on mainline**:
   - Compare current branch with mainline

4. **Check working tree status using MCP for IAM control**:
   - Use `mcp__git__git_status`
   - repo_path: Current working directory
   - Rationale: Enables users to auto-approve status checks in settings.json for autonomous operation

**Validation Gate: Safe to Rebase**
```
IF current_branch == mainline:
  STOP: "Cannot rebase mainline branch"
  EXPLAIN: "Mainline should never be rebased"
  EXIT workflow

IF working tree has uncommitted changes:
  STOP: "Cannot rebase with uncommitted changes"
  PROPOSE: "Commit or stash changes first"
  WAIT for user to resolve
ELSE:
  PROCEED to Phase 2
```

**Required Output (JSON):**
```json
{
  "phase": "pre-flight-checks",
  "status": "success",
  "data": {
    "current_branch": "feat/add-metrics",
    "mainline_branch": "main",
    "on_mainline": false,
    "working_tree_clean": true
  },
  "next_phase": "save-state"
}
```

## Phase 2: Save State

**Objective**: Remember current branch for later checkout.

**Steps:**
1. **Store current branch** from Phase 1:
   - CURRENT_BRANCH = current branch name
   - This state MUST be preserved through all phases

**Required Output (JSON):**
```json
{
  "phase": "save-state",
  "status": "success",
  "data": {
    "saved_branch": "feat/add-metrics",
    "state_preserved": true
  },
  "next_phase": "determine-base"
}
```

[Extended thinking: State preservation is the most critical aspect of this workflow. Between Phases 4-6, we checkout mainline, sync it, and return to feature branch. If we lose track of the original feature branch name, we cannot return to it. This would leave the user stranded on mainline with no way to complete the rebase. The saved branch name from Phase 2 must be carried through all subsequent phases and used in Phase 6. Never use "current branch" after Phase 4 - always use saved state.]

## Phase 3: Determine Rebase Base

**Objective**: Identify which branch to rebase onto.

**Steps:**
1. **Check if `--onto <branch>` flag was provided**:
   - IF provided: Use specified branch as rebase base
   - ELSE: Use mainline from Phase 1

2. **Store rebase base branch**:
   - REBASE_BASE = specified branch or mainline

**Required Output (JSON):**
```json
{
  "phase": "determine-base",
  "status": "success",
  "data": {
    "rebase_base": "main",
    "user_specified": false,
    "is_mainline": true
  },
  "next_phase": "checkout-base"
}
```

## Phase 4: Checkout Base Branch

**Objective**: Switch to base branch for syncing.

**Steps:**
1. **Checkout base branch using MCP for IAM control**:
   - Use `mcp__git__git_checkout`
   - repo_path: Current working directory
   - branch_name: Rebase base from Phase 3
   - Rationale: Requires user approval for state changes; maintains explicit control over branch switching

**Error Handling:**
```
IF MCP checkout fails:
  STOP immediately
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error clearly to user
  PROPOSE solution
  WAIT for user decision
ELSE:
  PROCEED to Phase 5
```

**Required Output (JSON):**
```json
{
  "phase": "checkout-base",
  "status": "success",
  "data": {
    "checked_out_branch": "main",
    "mcp_tool_used": true
  },
  "next_phase": "sync-base"
}
```

## Phase 5: Sync Base Branch

**Objective**: Ensure base branch is up-to-date with remote.

**Steps:**
1. **Detect upstream remote using bash**:
   - `git remote get-url upstream >/dev/null 2>&1`
   - IF exit code 0: upstream exists
   - ELSE: upstream does not exist

2. **Sync base branch using bash** (no MCP equivalent):
   - **IF upstream exists**:
     - `git sync-upstream` (custom alias) OR
     - `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push $(git config --get branch.$(git branch --show-current).remote) $(git branch --show-current)`
   - **ELSE**:
     - `git fetch --prune && git merge --ff-only @{u}`
     - Fetches and fast-forwards current branch from tracking remote

3. **Verify sync successful**:
   - Check command exit code

**Validation Gate: Sync Success**
```
IF sync command failed:
  STOP: "Failed to sync base branch"
  THINK about error (consider using sequential-thinking)
  EXPLAIN error to user
  PROPOSE solution
  WAIT for user decision
ELSE:
  PROCEED to Phase 6
```

**Required Output (JSON):**
```json
{
  "phase": "sync-base",
  "status": "success",
  "data": {
    "upstream_exists": false,
    "sync_command": "git sync",
    "sync_successful": true
  },
  "next_phase": "return-to-feature"
}
```

## Phase 6: Return to Feature Branch

**Objective**: Switch back to feature branch for rebase.

**Steps:**
1. **Retrieve saved branch** from Phase 2:
   - CURRENT_BRANCH from saved state

2. **Checkout feature branch using MCP for IAM control**:
   - Use `mcp__git__git_checkout`
   - repo_path: Current working directory
   - branch_name: Saved branch from Phase 2
   - Rationale: Requires user approval for state changes; maintains explicit control over branch switching

**Error Handling:**
```
IF MCP checkout fails:
  STOP immediately
  EXPLAIN: Cannot return to feature branch
  PROPOSE: Manual checkout
  WORKFLOW FAILED
ELSE:
  PROCEED to Phase 7
```

**Required Output (JSON):**
```json
{
  "phase": "return-to-feature",
  "status": "success",
  "data": {
    "returned_to_branch": "feat/add-metrics",
    "state_restored": true,
    "mcp_tool_used": true
  },
  "next_phase": "rebase-execution"
}
```

## Phase 7: Rebase Execution

**Objective**: Perform the actual rebase operation.

**Steps:**
1. **Execute rebase using bash** (no MCP equivalent for interactive rebase):
   - `git rebase <rebase-base>`
   - Where <rebase-base> is from Phase 3
   - Example: `git rebase main` or `git rebase $(git default)`

2. **Check rebase result**:
   - Exit code 0: Rebase successful
   - Exit code != 0: Rebase failed (likely conflicts)

**Validation Gate: Rebase Success**
```
IF rebase successful (exit code 0):
  PROCEED to Phase 8

IF rebase conflicts detected:
  STOP: "Rebase conflicts detected"
  EXPLAIN conflicts to user:
    - List conflicted files
    - Provide conflict resolution guidance
  INSTRUCT user:
    1. Resolve conflicts in listed files
    2. Stage resolved files: git add <files>
    3. Continue rebase: git rebase --continue
    4. OR abort rebase: git rebase --abort
  WAIT for user to resolve manually
  WORKFLOW PAUSED (not failed)

  **After user resolves:**
  - IF user continued successfully: PROCEED to Phase 8
  - IF user aborted: EXIT workflow

IF rebase failed for other reason:
  STOP immediately
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error clearly
  PROPOSE solution or abort
  WAIT for user decision
```

**Required Output (JSON):**
```json
{
  "phase": "rebase-execution",
  "status": "success",
  "data": {
    "rebase_command": "git rebase main",
    "rebase_successful": true,
    "conflicts_detected": false,
    "bash_command_used": true,
    "bash_reason": "No MCP equivalent for interactive rebase"
  },
  "next_phase": "reset-author-dates"
}
```

[Extended thinking: Rebase conflicts are normal and expected, not failures. When git rebase encounters conflicts, it pauses mid-operation waiting for user resolution. The distinction between "WORKFLOW PAUSED" and "WORKFLOW FAILED" is critical. A paused workflow can be resumed once user resolves conflicts and runs git rebase --continue. The workflow provides clear instructions and waits for user to indicate they've resolved conflicts. Never automatically retry or attempt to resolve conflicts programmatically - they require human judgment about which changes to keep.]

## Phase 8: Reset Author Dates (Conditional)

**Objective**: Update author dates to current time for cleaner history.

**Skip Condition:**
- IF `--skip-author-date-reset` flag present: Skip to Phase 9
- ELSE: Execute reset

**Steps:**
1. **Find fork point** (§ git-ops.md Fork Point Detection):
   - This returns the commit where feature branch diverged from base
   - No MCP equivalent

2. **Reset author dates using bash**:
   - `git rebase <fork-point> --reset-author-date`
   - This rewrites commits with current timestamps
   - No MCP equivalent

3. **Verify reset successful**:
   - Check command exit code

**Validation Gate: Reset Success**
```
IF reset author dates failed:
  WARN: "Author date reset failed"
  EXPLAIN error
  PROPOSE: Continue anyway or retry
  ASK user if they want to continue
  WAIT for user decision
ELSE:
  PROCEED to Phase 9
```

**Required Output (JSON):**
```json
{
  "phase": "reset-author-dates",
  "status": "success",
  "data": {
    "skipped": false,
    "fork_point": "abc123def",
    "reset_successful": true,
    "bash_command_used": true,
    "bash_reason": "git fork-point and --reset-author-date have no MCP equivalent"
  },
  "next_phase": "verification"
}
```

## Phase 9: Verification

**Objective**: Confirm rebase completed successfully and branch is ready.

**Steps:**
1. **Verify current branch using bash**:
   - `git branch --show-current`
   - Should match saved branch from Phase 2

2. **Check status using MCP**:
   - Use `mcp__git__git_status` to verify clean state

3. **Get recent commits using MCP**:
   - Use `mcp__git__git_log` (repo_path: cwd, max_count: 3)
   - Verify commits are present and rebased

4. **Report success to user**:
   ```
   Rebase completed successfully

   Branch: feat/add-metrics
   Rebased onto: main
   Author dates: Reset to current time

   Recent commits:
   - abc123 Commit message 1
   - def456 Commit message 2
   - ghi789 Commit message 3

   Branch is ready. You may need to force push to remote:
   git push --force-with-lease origin feat/add-metrics
   ```

**Validation Gate: Branch State Valid**
```
IF current branch != expected branch:
  STOP: "Branch state inconsistent after rebase"
  EXPLAIN discrepancy
  PROPOSE manual verification
ELSE:
  WORKFLOW COMPLETE
```

**Required Output (JSON):**
```json
{
  "phase": "verification",
  "status": "complete",
  "data": {
    "current_branch": "feat/add-metrics",
    "verified": true,
    "rebase_complete": true,
    "needs_force_push": true
  },
  "workflow_complete": true
}
```

## Critical Constraints

**YOU MUST FOLLOW THESE RULES:**

1. **MCP Tools Required for IAM Control**:
   - `mcp__git__git_status` - Status checks (read-only, safely auto-approved)
   - `mcp__git__git_checkout` - Branch switching (state change, requires approval)
   - `mcp__git__git_log` - View commits (read-only, safely auto-approved)
   - Rationale: Enables users to configure autonomous operation for read-only tasks while maintaining explicit approval for state changes

2. **Bash Allowed** for operations without MCP equivalent:
   - `git branch --show-current` - Get current branch
   - `git ls-remote` - Get mainline branch (§ git-ops.md Mainline Detection)
   - `git merge-base` - Find fork point (§ git-ops.md Fork Point Detection)
   - `git remote get-url` - Check for upstream (§ git-ops.md Upstream Detection)
   - `git sync-upstream` - Sync with upstream (custom alias, fallback: `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push ...`)
   - `git fetch --prune && git merge --ff-only @{u}` - Simple sync with tracking remote
   - `git rebase` - Rebase operation (no MCP equivalent)
   - `git rebase --reset-author-date` - Reset dates (no MCP equivalent)

3. **Validation Gates are MANDATORY**:
   - DO NOT proceed if gate condition fails
   - STOP and explain to user
   - Propose corrective action
   - Wait for user decision

4. **State Preservation is CRITICAL**:
   - MUST remember current branch through entire workflow
   - DO NOT lose context between phases
   - Verify state restoration after checkout operations

5. **Structured State Required**:
   - Output JSON after each phase
   - Pass data to next phase
   - Maintain state throughout workflow

6. **Thinking Checkpoints**:
   - Use `mcp__sequential-thinking` for:
     - Error analysis (Phase 4, 5, 6, 7, 8)
     - Conflict resolution guidance (Phase 7)
   - Aim for 95%+ confidence in all decisions

7. **Error Transparency**:
   - Explain WHY any error occurred
   - Explain WHY bash is used (no MCP equivalent)
   - Provide clear path forward
   - Never silently fail or proceed

8. **Conflict Handling**:
   - Detect conflicts immediately
   - Provide clear resolution instructions
   - Pause workflow (don't fail)
   - Allow user to resolve and continue

## Success Criteria

- All phases completed successfully
- All validation gates passed
- Working tree was clean before rebase
- Base branch synced with remote
Feature branch rebased onto base
- Author dates reset (unless skipped)
- Current branch state verified
- User informed about force push requirement
- Structured JSON state maintained throughout

## Failure Scenarios

- On mainline branch → Refuse to rebase, explain why
- Uncommitted changes present → Ask user to commit or stash
- Cannot checkout base branch → Stop and explain
- Sync fails → Analyze error, propose solution
- Cannot return to feature branch → Critical failure, manual intervention
- Rebase conflicts → Pause, guide user through resolution
- Rebase fails → Analyze error, propose abort or retry
- Author date reset fails → Warn user, ask to continue or retry
- MCP tool unavailable for required operations → Stop and report error

## Special Notes

**Force Push Requirement:**
After a successful rebase, the feature branch's history has been rewritten. If the branch was previously pushed to remote, it will need to be force pushed:

```bash
git push --force-with-lease origin <branch-name>
```

**IMPORTANT**: Use `--force-with-lease` instead of `--force` for safety. This ensures you don't overwrite changes others may have pushed.

**Conflict Resolution:**
When conflicts occur during rebase:
1. Git pauses the rebase process
2. Conflicted files are marked with conflict markers
3. User must manually resolve conflicts
4. Stage resolved files with `git add`
5. Continue with `git rebase --continue`
6. OR abort with `git rebase --abort`

The workflow pauses at Phase 7 during conflicts and waits for user resolution before proceeding.
