---
description: Atomic commit workflow with code review, analysis, and validation gates
---

# Commit Workflow

[Extended thinking: This workflow creates atomic commits with quality gates. Uses MCP tools for git operations, bash only for operations without MCP equivalents. Each phase builds on previous state; validation gates halt on failures with clear guidance.]

You are executing the **commit workflow**. Follow this deterministic, phase-based procedure exactly. Do not deviate from the specified steps or validation gates.

## Tool Requirements (Highly Relevant)

This workflow uses MCP tools for git operations to enable user-controlled IAM permissions. Bash is used only when no MCP equivalent exists.

## Workflow Configuration

**Configurable Options:**
- `--skip-review`: Skip code review phase (default: false)
- `--conventional`: Force Conventional Commits format (default: auto-detect)

## Phase 1: Pre-flight Checks

**Objective**: Verify environment is ready for commit operation.

**Steps:**
1. Get current branch name using bash: `git branch --show-current`
2. Get mainline branch name (§ git-ops.md Mainline Detection)
3. Check if current branch equals mainline

**Validation Gate: Branch Protection**
```
IF current_branch == mainline AND user did not explicitly request mainline commit:
  STOP: "Cannot commit directly to mainline branch"
  PROPOSE: "Create a feature branch first using /branch command"
  WAIT for user confirmation
ELSE:
  PROCEED to Phase 2
```

**Required Output (JSON):**
```json
{
  "phase": "pre-flight-checks",
  "status": "success",
  "data": {
    "current_branch": "<branch-name>",
    "mainline_branch": "<mainline-name>",
    "on_mainline": false
  },
  "next_phase": "status-check"
}
```

## Phase 2: Status Check

**Objective**: Identify uncommitted changes using MCP tools.

**Steps:**
1. Use `mcp__git__git_status` (repo_path: current working directory)

**Validation Gate: Changes Present**
```
IF no uncommitted changes detected:
  STOP: "No changes to commit"
  EXIT workflow
ELSE:
  PROCEED to Phase 3
```

**Required Output (JSON):**
```json
{
  "phase": "status-check",
  "status": "success",
  "data": {
    "has_changes": true,
    "modified_files": [...],
    "untracked_files": [...]
  },
  "next_phase": "code-review"
}
```

## Phase 3: Code Review (Configurable)

**Objective**: Analyze code quality, security, and best practices.

**Skip Condition:**
- IF `--skip-review` flag present: Skip to Phase 4
- ELSE: Execute review

**Steps:**
1. Get diff using MCP tools:
   - Unstaged: `mcp__git__git_diff_unstaged` (repo_path: cwd, context_lines: 3)
   - Staged: `mcp__git__git_diff_staged` (repo_path: cwd, context_lines: 3)

2. **Review Analysis** (THINKING CHECKPOINT: Consider using `mcp__sequential-thinking` for thorough analysis):
   - Identify potential issues (security, performance, style)
   - Check for sensitive data (credentials, keys, tokens)
   - Verify code quality and best practices
   - Assess if changes align with apparent intent

3. **Present findings**:
   - List any concerns or issues found
   - Provide recommendations if applicable
   - Ask user if they want to proceed

**Validation Gate: Review Approval**
```
IF critical issues found (security, credentials):
  STOP: "Critical issues detected in changes"
  RECOMMEND: Specific fixes needed
  WAIT for user to address issues
ELSE IF warnings present:
  WARN: Present warnings
  ASK: "Proceed with commit despite warnings?"
  WAIT for user decision
ELSE:
  PROCEED to Phase 4
```

**Required Output (JSON):**
```json
{
  "phase": "code-review",
  "status": "success",
  "data": {
    "skipped": false,
    "issues_found": 0,
    "warnings": [],
    "review_passed": true
  },
  "next_phase": "change-analysis"
}
```

## Phase 4: Change Analysis

**Objective**: Analyze changes and detect commit message conventions.

**Steps:**
1. **Analyze changed files**:
   - Categorize by type (code, docs, config, tests)
   - Identify scope of changes
   - Understand nature of modifications

2. **Detect Conventional Commits usage** (check in order):
   - Check your project memory first
   - Look for: `.commitlintrc`, `.commitlintrc.json`, `.commitlintrc.yml`, `.commitlintrc.yaml`
   - Look for: `commitlint.config.js`, `commitlint.config.cjs`
   - Look for: `CONTRIBUTING.md` containing "Conventional Commits"
   - Check recent commits (last 5) using MCP: `mcp__git__git_log` (repo_path: cwd, max_count: 5)

   **IF detected**: Set `conventional_commits: true`
   **ELSE**: Set `conventional_commits: false`

**Required Output (JSON):**
```json
{
  "phase": "change-analysis",
  "status": "success",
  "data": {
    "file_categories": {
      "code": [...],
      "docs": [...],
      "config": [...],
      "tests": [...]
    },
    "change_scope": "feature|fix|refactor|docs|style|test|chore",
    "conventional_commits_detected": false
  },
  "next_phase": "commit-message-generation"
}
```

## Phase 5: Commit Message Generation

**Objective**: Draft a concise, informative commit message.

**Thinking Checkpoint (RECOMMENDED):**
THINKING CHECKPOINT: Use `mcp__sequential-thinking` to:
1. Analyze the nature and scope of changes
2. Determine appropriate commit type (if Conventional Commits)
3. Identify the core purpose of the changes (the "why")
4. Draft a concise subject line (<50 characters, imperative mood)
5. Decide if body is needed (only if meaningfully adds context)
6. Ensure 95%+ confidence in message accuracy

**Commit Message Rules:**

**Subject Line:**
- Keep under 50 characters
- Use imperative mood ("Add feature" not "Added feature")
- Start with capital letter
- No period at end
- Be specific and descriptive

**Conventional Commits Format** (if detected in Phase 5):
```
<type>[optional scope]: <description>

[optional body]
```
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scope: Module/component affected (optional)
- Description: Imperative, lowercase, no period

**Body** (optional):
- Only include if adds meaningful context beyond subject
- Separate from subject with blank line
- Wrap at 72 characters
- Explain what and why, not how
- Use bullet points for multiple changes

**Co-Authored-By Handling:**
- Check if `includeCoAuthoredBy` setting exists in project config
- **IF enabled**: Add co-authored-by trailer:
  ```

  Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- **Default**: Do NOT include co-authored-by unless explicitly configured

**Required Output (JSON):**
```json
{
  "phase": "commit-message-generation",
  "status": "success",
  "data": {
    "commit_message": "Add user authentication middleware\n\n- Implements JWT-based authentication\n- Adds middleware for protected routes\n- Includes error handling for invalid tokens",
    "message_type": "feat",
    "conventional_format": false,
    "has_body": true,
    "co_authored_by_included": false
  },
  "next_phase": "user-approval"
}
```

## Phase 6: User Approval

**Objective**: Present commit details for user review and approval.

**Steps:**
1. **Present the following to user**:
   ```
   Files to be committed:
   - file1.js
   - file2.js

   Proposed commit message:
   ---
   Add user authentication middleware

   - Implements JWT-based authentication
   - Adds middleware for protected routes
   - Includes error handling for invalid tokens
   ---

   Diff summary:
   [IF diff < 100 lines: Include full diff]
   [IF diff >= 100 lines: "Diff is large (X lines). Show diff? (yes/no)"]
   ```

2. **Ask for approval**: "Proceed with this commit? (yes/no)"

3. **Wait for user response**

**Validation Gate: User Approval**
```
IF user approves:
  PROCEED to Phase 7
ELSE IF user requests changes:
  RETURN to Phase 5 (message generation) with user feedback
ELSE:
  STOP: "Commit cancelled by user"
  EXIT workflow
```

**Required Output (JSON):**
```json
{
  "phase": "user-approval",
  "status": "approved",
  "data": {
    "user_decision": "approved",
    "diff_shown": true
  },
  "next_phase": "execution"
}
```

## Phase 7: Execution

**Objective**: Stage files and create commit using MCP tools exclusively.

**Steps:**
1. Stage all changes using `mcp__git__git_add`:
   - repo_path: Current working directory
   - files: [All modified and untracked files from Phase 2]

2. Create commit using `mcp__git__git_commit`:
   - repo_path: Current working directory
   - message: Commit message from Phase 5

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
  PROCEED to Phase 8
```

**Required Output (JSON):**
```json
{
  "phase": "execution",
  "status": "success",
  "data": {
    "files_staged": [...],
    "commit_created": true,
    "mcp_tools_used": true,
    "bash_fallback_used": false
  },
  "next_phase": "verification"
}
```

## Phase 8: Verification

**Objective**: Confirm commit was created successfully.

**Steps:**
1. **Get latest commit using MCP**:
   - Use `mcp__git__git_log` (repo_path: cwd, max_count: 1)
   - Extract commit SHA and message

2. **Verify commit details match**:
   - Check commit message matches what was approved
   - Confirm files were included

3. **Report success to user**:
   ```
   Commit created successfully

   SHA: abc123def
   Message: Add user authentication middleware

   Files committed: 2
   ```

**Required Output (JSON):**
```json
{
  "phase": "verification",
  "status": "complete",
  "data": {
    "commit_sha": "abc123def",
    "commit_verified": true,
    "files_count": 2
  },
  "workflow_complete": true
}
```

## Tool Reference

**MCP tools:** `mcp__git__git_status`, `mcp__git__git_diff_unstaged`, `mcp__git__git_diff_staged`, `mcp__git__git_add`, `mcp__git__git_commit`, `mcp__git__git_log`

**Bash (no MCP equivalent):** `git branch --show-current`, `git ls-remote` (for mainline detection)

## Success Criteria

- All phases completed successfully
- All validation gates passed
- MCP tools used for all git operations
- User approved commit message
- Commit created and verified
- Structured JSON state maintained throughout

## Failure Scenarios

- On mainline branch without explicit approval → Create feature branch
- No changes to commit → Exit workflow gracefully
- Critical issues in code review → Stop and recommend fixes
- MCP tool unavailable → Stop and report error (no bash fallback)
- User rejects commit → Exit workflow gracefully
- Commit creation fails → Analyze error, propose solution, wait for user
