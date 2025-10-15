---
description: Comprehensive end-to-end git workflow from code review to pull request creation
---

# Comprehensive Git Workflow

[Extended thinking: This is a meta-workflow that invokes other workflows (/commit, /branch, /pr) as building blocks. Uses MCP tools for git/GitHub operations, bash only for operations without MCP equivalents. Code review happens before commit. Sub-workflow invocations pass flags to avoid duplicate work (e.g., --skip-review to /commit since review happened in Phase 2).]

You are executing the **comprehensive git workflow**. This orchestrates a complete development cycle from code review through pull request creation. Follow this deterministic, phase-based procedure exactly.

## Tool Requirements (Highly Relevant)

This workflow uses MCP tools for git/GitHub operations to enable user-controlled IAM permissions. Bash is used only when no MCP equivalent exists.

## Workflow Overview

This workflow executes the following sequence:
1. **Code Review** - Analyze changes for quality and security
2. **Testing** (optional) - Run tests if applicable
3. **Commit** - Create commit with reviewed changes
4. **Branch Strategy** - Ensure proper branch structure
5. **Pull Request** - Create GitHub PR

## Workflow Configuration

**Optional Flags:**
- `--skip-review`: Skip code review phase
- `--skip-tests`: Skip testing phase
- `--draft-pr`: Create draft pull request
- `--trunk-based`: Commit directly to mainline (requires explicit approval)
- `--feature-branch`: Use feature branch (default)
- `--conventional`: Force Conventional Commits format
- `--pr-title <text>`: Override PR title
- `--pr-body <text>`: Override PR description

## Phase 1: Pre-Workflow Validation

**Objective**: Verify environment is ready for complete workflow.

**Steps:**
1. Check working directory status using `mcp__git__git_status` (repo_path: current working directory)

2. **Verify changes exist**:
   - Must have modified or untracked files
   - Cannot proceed with empty changeset

3. **Get current branch using bash**:
   - `git branch --show-current`

4. **Get mainline branch** (§ git-ops.md Mainline Detection)

**Validation Gate: Environment Ready**
```
IF no changes detected:
  STOP: "No changes to process"
  EXIT workflow

IF Git repository not detected:
  STOP: "Not a git repository"
  PROPOSE: Initialize git or navigate to repo
  EXIT workflow
ELSE:
  PROCEED to Phase 2
```

**Required Output (JSON):**
```json
{
  "phase": "pre-workflow-validation",
  "status": "success",
  "data": {
    "has_changes": true,
    "current_branch": "feat/add-metrics",
    "mainline_branch": "main",
    "is_git_repo": true
  },
  "next_phase": "code-review"
}
```

**Validation Gate: Plan Mode Check**
```
IF in plan mode:
  STOP: "Cannot execute comprehensive workflow in plan mode"
  EXPLAIN: This workflow would perform multiple write operations:
    - Code review and testing
    - Create commit via /commit workflow
    - Potentially create feature branch via /branch workflow
    - Push to remote and create PR via /pr workflow
  INFORM: "Exit plan mode to execute git-workflow"
  NOTE: "Consider running individual workflows (/commit, /pr) after exiting plan mode"
  EXIT workflow
ELSE:
  PROCEED to Phase 2
```

## Phase 2: Code Review (Configurable)

**Objective**: Analyze code quality, security, and best practices.

**Skip Condition:**
- IF `--skip-review` flag present: Skip to Phase 3
- ELSE: Execute review

**Thinking Checkpoint (RECOMMENDED):**
THINKING CHECKPOINT: Use `mcp__sequential-thinking` to:
1. Comprehensively analyze all changes
2. Identify potential issues across categories
3. Assess security implications
4. Evaluate code quality and patterns
5. Generate actionable recommendations
6. Ensure 95%+ confidence in review

**Steps:**
1. Get complete diff using MCP tools:
   - Unstaged: `mcp__git__git_diff_unstaged` (repo_path: cwd, context_lines: 5)
   - Staged: `mcp__git__git_diff_staged` (repo_path: cwd, context_lines: 5)

2. **Perform multi-dimensional review**:

   **Security Analysis:**
   - Secrets/credentials exposure (API keys, passwords, tokens)
   - Authentication/authorization issues
   - SQL injection vulnerabilities
   - XSS vulnerabilities
   - Insecure dependencies
   - Sensitive data handling

   **Code Quality:**
   - Code complexity and readability
   - Proper error handling
   - Resource management (memory leaks, file handles)
   - Performance implications
   - Code duplication
   - Design patterns usage

   **Best Practices:**
   - Language-specific conventions
   - Project coding standards
   - Documentation completeness
   - Test coverage considerations
   - Breaking changes impact

3. **Categorize findings**:
   - CRITICAL: **Critical**: Must fix (security, data loss)
   - WARNING:  **Warning**: Should fix (quality, performance)
   - SUGGESTION: **Suggestion**: Nice to have (refactoring, optimization)

4. **Present review results**:
   ```
   Code Review Results

   Files analyzed: 5
   Lines changed: +120 -45

   Critical Issues: 0
   WARNING:  Warnings: 2
   Suggestions: 3

   [Detailed findings with file:line references]
   ```

**Validation Gate: Review Pass**
```
IF critical issues found:
  STOP: "Critical issues detected - must be resolved"
  LIST: All critical issues with locations
  RECOMMEND: Specific fixes needed
  WAIT for user to address issues
  ASK: "Have issues been resolved? Re-run workflow?"
  EXIT workflow

IF warnings present:
  WARN: Present warnings
  ASK: "Proceed despite warnings? (yes/no)"
  WAIT for user decision

  IF user approves:
    PROCEED to Phase 3
  ELSE:
    EXIT workflow to address warnings
ELSE:
  PROCEED to Phase 3
```

**Required Output (JSON):**
```json
{
  "phase": "code-review",
  "status": "success",
  "data": {
    "skipped": false,
    "files_analyzed": 5,
    "critical_issues": 0,
    "warnings": 2,
    "suggestions": 3,
    "review_passed": true,
    "user_approved_warnings": true
  },
  "next_phase": "testing"
}
```

[Extended thinking: Code review in this workflow is multi-dimensional: security, quality, and best practices. The thinking checkpoint is CRITICAL for thorough analysis. Review happens before commit, which is the right time - catching issues early prevents bad commits from entering history. Critical issues are STOP conditions (non-negotiable), while warnings allow user choice. The review categorizes findings by severity to help users prioritize fixes. Sequential-thinking ensures 95%+ confidence, avoiding both false positives (crying wolf) and false negatives (missing real issues). Skipping review via --skip-review is allowed but should be rare, used only for trivial changes or when external review process exists.]

## Phase 3: Testing (Configurable)

**Objective**: Run automated tests to verify changes.

**Skip Condition:**
- IF `--skip-tests` flag present: Skip to Phase 4
- ELSE: Attempt to detect and run tests

**Steps:**
1. **Detect test framework**:
   - Check for common test files/configs:
     - JavaScript/TypeScript: `package.json` with test script, `jest.config.js`, `vitest.config.ts`
     - Python: `pytest.ini`, `tox.ini`, `tests/` directory
     - Go: `*_test.go` files
     - Ruby: `spec/` directory, `.rspec`
     - Rust: `cargo test` availability

2. **IF test framework detected**:
   - Determine test command:
     - npm/yarn: `npm test` or `yarn test`
     - Python: `pytest` or `python -m pytest`
     - Go: `go test ./...`
     - Ruby: `rspec`
     - Rust: `cargo test`

3. **Run tests using Bash**:
   - Execute determined test command
   - Capture exit code and output
   - Timeout: 300 seconds (5 minutes)

4. **IF no test framework detected**:
   - WARN: "No test framework detected"
   - ASK: "Continue without running tests? (yes/no)"

**Validation Gate: Tests Pass**
```
IF tests detected AND tests failed:
  STOP: "Tests failed - cannot proceed"
  SHOW: Test failure output
  RECOMMEND: Fix failing tests
  ASK: "Fix tests and re-run workflow?"
  EXIT workflow

IF tests detected AND tests passed:
  SUCCESS: "All tests passed"
  PROCEED to Phase 4

IF no tests detected AND user approves:
  WARN: "Proceeding without tests"
  PROCEED to Phase 4

IF no tests detected AND user rejects:
  EXIT workflow
```

**Required Output (JSON):**
```json
{
  "phase": "testing",
  "status": "success",
  "data": {
    "skipped": false,
    "test_framework": "jest",
    "tests_detected": true,
    "tests_run": true,
    "tests_passed": true,
    "test_output": "25 tests passed"
  },
  "next_phase": "commit-invocation"
}
```

## Phase 4: Commit Invocation

**Objective**: Create commit using /commit workflow.

**Steps:**
1. **Invoke /commit command using SlashCommand tool**:
   - Command: `/commit`
   - Pass flags if applicable:
     - `--skip-review` (already reviewed in Phase 2)
     - `--conventional` (if flag present in git-workflow)

2. **Wait for /commit workflow to complete**:
   - /commit will handle:
     - Profile verification
     - Change analysis
     - Conventional Commits detection
     - Commit message generation
     - User approval
     - Commit execution

3. **Capture /commit result**:
   - Extract commit SHA
   - Verify commit was created

**Validation Gate: Commit Success**
```
IF /commit workflow failed:
  STOP: "Commit creation failed"
  EXPLAIN: Reason for failure
  PROPOSE: Address issue and retry
  EXIT workflow

IF /commit workflow cancelled by user:
  INFO: "User cancelled commit"
  EXIT workflow gracefully

IF /commit workflow successful:
  SUCCESS: "Commit created"
  PROCEED to Phase 5
```

**Required Output (JSON):**
```json
{
  "phase": "commit-invocation",
  "status": "success",
  "data": {
    "commit_workflow_invoked": true,
    "commit_created": true,
    "commit_sha": "abc123def",
    "flags_passed": ["--skip-review"]
  },
  "next_phase": "branch-strategy"
}
```

[Extended thinking: Commit invocation delegates to /commit workflow but must pass appropriate flags to avoid duplicate work. Since code review happened in Phase 2, we pass --skip-review to /commit. If --conventional flag was present in git-workflow invocation, pass it through to /commit. The /commit workflow handles profile verification, Conventional Commits detection, commit message generation, and actual commit execution. We wait for it to complete and verify success before proceeding. If /commit fails or user cancels, the entire git-workflow stops - there's no point continuing to branch strategy or PR creation without a commit.]

## Phase 5: Branch Strategy

**Objective**: Ensure proper branch structure for workflow type.

**Steps:**
1. **Determine strategy from flags**:
   - `--trunk-based`: Mainline workflow
   - `--feature-branch` OR default: Feature branch workflow

2. **Get current branch** from Phase 1 data

3. **Execute strategy**:

   **A. Trunk-Based Strategy** (`--trunk-based`):
   - Verify current branch == mainline
   - IF not on mainline:
     - WARN: "Trunk-based workflow requires mainline branch"
     - ASK: "Switch to mainline and continue?"
     - IF yes: Checkout mainline using MCP
     - ELSE: EXIT workflow

   **B. Feature Branch Strategy** (default):
   - Verify current branch != mainline
   - IF on mainline:
     - ALERT: "On mainline branch, feature branch recommended"
     - ASK: "Create feature branch? (yes/no/continue-anyway)"
     - IF yes: Invoke `/branch` command
     - IF continue: Proceed with warning
     - IF no: EXIT workflow

**Validation Gate: Branch Strategy Valid**
```
IF trunk-based AND not on mainline AND user rejects switch:
  EXIT workflow

IF feature-branch AND on mainline AND user rejects branch creation:
  EXIT workflow

ELSE:
  PROCEED to Phase 6
```

**Required Output (JSON):**
```json
{
  "phase": "branch-strategy",
  "status": "success",
  "data": {
    "strategy": "feature-branch",
    "branch_created": false,
    "current_branch": "feat/add-metrics",
    "on_mainline": false,
    "strategy_valid": true
  },
  "next_phase": "pr-creation"
}
```

[Extended thinking: Branch strategy validates workflow type matches branch state. Feature branch workflow (default) expects to be on a non-mainline branch - if on mainline, offer to create feature branch via /branch invocation. Trunk-based workflow (--trunk-based flag) expects to be on mainline - if not, offer to switch. The "continue-anyway" option exists for flexibility but should warn user. This phase ensures changes land in appropriate location: feature branches for collaborative review, mainline for trunk-based development. Getting this wrong causes organizational friction - commits on wrong branch require cleanup.]

## Phase 6: Pull Request Creation

**Objective**: Create GitHub PR using /pr workflow.

**Steps:**
1. **Check if GitHub repository**:
   - Use bash: `git remote get-url origin 2>/dev/null | grep -qi github.com`
   - IF no GitHub remote: Skip PR creation, workflow complete

2. **Invoke /pr command using SlashCommand tool**:
   - Command: `/pr`
   - Pass flags if applicable:
     - `--draft` (if `--draft-pr` present in git-workflow)
     - `--title "<text>"` (if `--pr-title` present)
     - `--body "<text>"` (if `--pr-body` present)

3. **Wait for /pr workflow to complete**:
   - /pr will handle:
     - Repository type detection
     - Remote URL parsing
     - PR content generation
     - Branch push
     - PR creation via GitHub MCP

4. **Capture PR result**:
   - Extract PR number and URL
   - Store for final report

**Validation Gate: PR Success**
```
IF no GitHub remote:
  INFO: "No GitHub remote detected - skipping PR creation"
  WORKFLOW COMPLETE (without PR)

IF /pr workflow failed:
  STOP: "PR creation failed"
  EXPLAIN: Reason for failure
  PROPOSE: Address issue or create PR manually
  WORKFLOW INCOMPLETE

IF /pr workflow successful:
  SUCCESS: "PR created"
  PROCEED to Phase 7
```

**Required Output (JSON):**
```json
{
  "phase": "pr-creation",
  "status": "success",
  "data": {
    "github_remote_detected": true,
    "pr_workflow_invoked": true,
    "pr_created": true,
    "pr_number": 123,
    "pr_url": "https://github.com/owner/repo/pull/123",
    "is_draft": false
  },
  "next_phase": "final-report"
}
```

[Extended thinking: PR creation is the final step, delegating to /pr workflow which handles all complexity (fork vs origin detection, URL parsing, content generation, push, GitHub API call). If no GitHub remote exists, skip PR creation gracefully - workflow is still successful, just incomplete. Pass through flags: --draft-pr becomes --draft, --pr-title and --pr-body override content generation. The /pr workflow may itself invoke /commit if uncommitted changes exist, but that shouldn't happen here since we just committed in Phase 4. PR creation failure doesn't invalidate prior work (commit still exists) but does leave workflow incomplete.]

## Phase 7: Final Report

**Objective**: Provide comprehensive summary of workflow execution.

**Steps:**
1. **Compile workflow results** from all phases:
   - Code review summary
   - Test results
   - Commit details
   - Branch information
   - PR information

2. **Generate comprehensive report**:
   ```
   Git Workflow Completed Successfully

   Code Review
   - Files analyzed: 5
   - Issues found: 0 critical, 2 warnings
   - Status: Approved

   Testing
   - Framework: jest
   - Tests run: 25
   - Result: All passed

   Commit
   - SHA: abc123def
   - Message: Add metrics export functionality
   - Branch: feat/add-metrics

   Branch Strategy
   - Type: Feature branch
   - Branch: feat/add-metrics
   - Base: main

   Pull Request
   - PR #123: Add metrics export functionality
   - URL: https://github.com/owner/repo/pull/123
   - Status: Open

   Your changes are ready for review!
   ```

3. **Provide next steps**:
   - Monitor PR for review feedback
   - Address review comments if needed
   - Merge when approved

**Required Output (JSON):**
```json
{
  "phase": "final-report",
  "status": "complete",
  "data": {
    "workflow_successful": true,
    "code_reviewed": true,
    "tests_passed": true,
    "commit_created": true,
    "branch_strategy_valid": true,
    "pr_created": true,
    "pr_url": "https://github.com/owner/repo/pull/123"
  },
  "workflow_complete": true
}
```

## Tool Reference

**MCP tools:** `mcp__git__git_status`, `mcp__git__git_diff_unstaged`, `mcp__git__git_diff_staged`, `mcp__git__git_checkout`, `mcp__github__create_pull_request`

**Bash (no MCP equivalent):** `git branch --show-current`, `git ls-remote` (for mainline detection), `git remote get-url` (for GitHub detection), test commands (npm test, pytest, etc.)

**Workflow invocations:** `/commit` (Phase 4), `/branch` (Phase 5 if needed), `/pr` (Phase 6 if GitHub remote)

## Success Criteria

- All phases completed successfully (or skipped as configured)
- All validation gates passed
- Code reviewed and approved (unless --skip-review)
- Tests passed (unless --skip-tests or no tests)
Commit created via /commit workflow
Branch strategy validated
- PR created via /pr workflow (if GitHub remote)
- Comprehensive report provided
- Structured JSON state maintained throughout

## Failure Scenarios

- No changes to process → Exit gracefully
- Critical code issues → Stop, require fixes
- Tests failed → Stop, require fixes
- Commit creation failed → Exit with error
- Branch strategy invalid → Exit or create branch
- PR creation failed → Workflow incomplete
- User cancels at any phase → Exit gracefully

## Configuration Examples

**Minimal (all defaults)**:
```
/git-workflow
```
- Code review included
- Tests run if detected
- Feature branch strategy
- Regular PR

**Quick commit without review**:
```
/git-workflow --skip-review --skip-tests
```
- Skip code review
- Skip testing
- Fast path to PR

**Draft PR with review**:
```
/git-workflow --draft-pr
```
- Full code review
- Tests run
- Create draft PR

**Trunk-based workflow**:
```
/git-workflow --trunk-based
```
- Commit to mainline
- May skip PR or create from mainline

**Custom PR content**:
```
/git-workflow --pr-title "Feature: Metrics Export" --pr-body "Custom description"
```
- Override generated PR title and body

## Integration Notes

**Workflow Composition**:
This workflow orchestrates three sub-workflows:
1. `/commit` - Phase 4
2. `/branch` - Phase 5 (conditional)
3. `/pr` - Phase 6

**State Passing**:
- Flags are passed to sub-workflows
- Results are captured and included in final report
- Each sub-workflow maintains its own structured state

**Error Propagation**:
- Sub-workflow failures stop main workflow
- Error details are surfaced to user
- Recovery options are presented

**Flexibility**:
- Users can invoke sub-workflows directly for atomic operations
- This comprehensive workflow provides end-to-end automation
- Skip flags allow customization for different scenarios
