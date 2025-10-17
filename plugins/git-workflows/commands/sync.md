---
description: Branch sync workflow to update current branch with remote changes
---

# Sync Workflow

[Extended thinking: This workflow updates a branch with remote changes, automatically detecting fork vs origin scenarios. The key insight is that syncing strategy differs based on repository structure: forks need upstream sync, origin-only repos use standard sync. The workflow handles both cases transparently by checking for upstream remote existence. It's designed to be invoked both standalone and as a sub-step in other workflows (/branch, /rebase). Sync operations use bash commands (git sync, git sync-upstream) because they have no MCP equivalent and are custom aliases.]

You are executing the **sync workflow**. Follow this deterministic, phase-based procedure exactly. Do not deviate from the specified steps or validation gates.

## Workflow Configuration

**Optional Input:**
- `--branch <name>`: Sync specific branch instead of current branch

## Phase 1: Branch Identification

**Objective**: Determine which branch to sync.

**Steps:**
1. **Check if `--branch <name>` flag was provided**:
   - IF provided: Use specified branch
   - ELSE: Use current branch

2. **Get current branch using bash** (if needed):
   - `git branch --show-current`

3. **Store target branch**:
   - TARGET_BRANCH = specified or current branch

**Required Output (JSON):**
```json
{
  "phase": "branch-identification",
  "status": "success",
  "data": {
    "target_branch": "main",
    "is_current_branch": true,
    "user_specified": false
  },
  "next_phase": "checkout-target"
}
```

## Phase 2: Checkout Target Branch (Conditional)

**Objective**: Switch to target branch if not already there.

**Skip Condition:**
- IF target branch == current branch: Skip to Phase 3
- ELSE: Execute checkout

**Steps:**
1. **Checkout target branch using MCP**:
   - Use `mcp__git__git_checkout`
   - repo_path: Current working directory
   - branch_name: Target branch from Phase 1

**Validation Gate: Checkout Success**
```
IF checkout fails:
  STOP: "Cannot checkout branch '<target>'"
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error to user
  PROPOSE solution
  WAIT for user decision
ELSE:
  PROCEED to Phase 3
```

**Required Output (JSON):**
```json
{
  "phase": "checkout-target",
  "status": "success",
  "data": {
    "checkout_executed": true,
    "current_branch": "main",
    "mcp_tool_used": true
  },
  "next_phase": "detect-upstream"
}
```

## Phase 3: Detect Upstream Remote

**Objective**: Determine if repository has upstream remote (fork scenario).

**Steps:**
1. **Check for upstream remote using bash**:
   - `git remote get-url upstream`
   - Exit code 0: upstream exists (fork)
   - Exit code 1: no upstream (origin only)

**Required Output (JSON):**
```json
{
  "phase": "detect-upstream",
  "status": "success",
  "data": {
    "upstream_exists": false,
    "is_fork": false
  },
  "next_phase": "sync-execution"
}
```

## Phase 4: Sync Execution

**Objective**: Fetch and merge changes from remote.

**Validation Gate: Plan Mode Check**
```
IF in plan mode:
  STOP: "Cannot sync branch in plan mode"
  EXPLAIN: This workflow would sync [target branch]:
    - Execute: [sync command from Phase 3]
    - Fetch from remote
    - Merge or rebase changes
    - Potentially push to remote
  INFORM: "Exit plan mode to execute sync workflow"
  EXIT workflow
ELSE:
  PROCEED to sync
```

**Steps:**
1. **Execute appropriate sync command using bash** (no MCP equivalent):
   - **IF upstream exists**:
     - `git sync-upstream` (custom alias) OR
     - `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push $(git config --get branch.$(git branch --show-current).remote) $(git branch --show-current)`
     - Fetches from upstream, rebases, and pushes to origin
   - **ELSE**:
     - `git fetch --prune && git merge --ff-only @{u}`
     - Fetches and fast-forwards current branch from tracking remote

2. **Verify sync successful**:
   - Check command exit code
   - Exit code 0: Success
   - Exit code != 0: Failure

**Validation Gate: Sync Success**
```
IF sync command failed:
  STOP: "Failed to sync branch '<target>'"
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error to user:
    - Likely causes: Network issues, merge conflicts, diverged histories
  PROPOSE solution:
    - Check network connectivity
    - Review remote branch status
    - Manual merge if conflicts exist
  WAIT for user decision
ELSE:
  PROCEED to Phase 5
```

**Required Output (JSON):**
```json
{
  "phase": "sync-execution",
  "status": "success",
  "data": {
    "sync_command": "git sync-upstream",
    "sync_successful": true
  },
  "next_phase": "verification"
}
```

## Phase 5: Verification

**Objective**: Confirm sync completed successfully and branch is up-to-date.

**Steps:**
1. **Check status using MCP**:
   - Use `mcp__git__git_status` (repo_path: cwd)
   - Verify working tree is clean
   - Check if branch is ahead/behind remote

2. **Get recent commits using MCP**:
   - Use `mcp__git__git_log` (repo_path: cwd, max_count: 3)
   - Show latest commits to confirm sync

3. **Report success to user**:
   ```
   Branch synced successfully

   Branch: main
   Synced with: origin/main (or upstream/main)
   Status: Up to date

   Recent commits:
   - abc123 Commit message 1
   - def456 Commit message 2
   - ghi789 Commit message 3
   ```

**Required Output (JSON):**
```json
{
  "phase": "verification",
  "status": "complete",
  "data": {
    "branch_synced": "main",
    "up_to_date": true,
    "recent_commits": [...],
    "verified": true
  },
  "workflow_complete": true
}
```

## Critical Constraints

**YOU MUST FOLLOW THESE RULES:**

1. **MCP Tools Only** for git operations where available:
   - `mcp__git__git_checkout` - Branch switching
   - `mcp__git__git_status` - Status checks
   - `mcp__git__git_log` - View commits
   - **FAILURE**: Using bash for these is a FAILURE

2. **Bash Allowed** for operations without MCP equivalent:
   - `git branch --show-current` - Get current branch
   - `git remote get-url` - Check for upstream remote (§ git-ops.md Upstream Detection)
   - `git fetch --prune && git merge --ff-only @{u}` - Simple sync with tracking remote
   - `git sync-upstream` - Sync with upstream (custom alias, fallback: `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push ...`)

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
     - Error analysis (Phase 2, 4)
     - Sync failure troubleshooting (Phase 4)
   - Aim for 95%+ confidence in all decisions

6. **Error Transparency**:
   - Explain WHY any error occurred
   - Explain WHY bash is used (no MCP equivalent)
   - Provide clear path forward
   - Never silently fail or proceed

## Success Criteria

- All phases completed successfully
- All validation gates passed
- Target branch identified correctly
- Checkout performed if needed (using MCP)
- Upstream remote detected correctly
- Sync executed successfully
Branch is up-to-date with remote
- Structured JSON state maintained throughout

## Failure Scenarios

- Cannot checkout target branch → Analyze error, propose solution
- Sync command fails → Check network, review remote status, guide manual resolution
- Merge conflicts during sync → Provide conflict resolution guidance
- MCP tool unavailable for required operations → Stop and report error

## Special Notes

**Sync Commands Explained:**

**Simple sync** (no hub dependency):
- `git fetch --prune && git merge --ff-only @{u}`
- Fetches from tracking remote (usually origin)
- Fast-forwards current branch
- Fails if fast-forward not possible (prevents accidental merge commits)

**`git sync-upstream`** (custom alias, user must configure):
- Used in fork workflows
- Fetches from upstream remote, rebases, and pushes to origin
- Keeps fork up-to-date with original repository
- Fallback: `git fetch --prune --all && git pull --stat --rebase upstream $(git branch --show-current) && git push $(git config --get branch.$(git branch --show-current).remote) $(git branch --show-current)`

**Fork vs Origin Detection:**
- Check for `upstream` remote to determine fork scenario
- IF upstream exists → Repository is a fork
- ELSE → Repository uses origin only

**Common Use Cases:**
1. **Sync mainline before creating feature branch** (see /branch workflow)
2. **Update mainline before rebasing** (see /rebase workflow)
3. **Keep fork up-to-date with upstream**
4. **Pull latest changes before starting work**

**Integration with Other Workflows:**
- `/branch` workflow invokes `/sync` in Phase 3 (mainline sync)
- `/rebase` workflow invokes `/sync` in Phase 5 (base sync)
- Can be used standalone when explicitly requested by user
