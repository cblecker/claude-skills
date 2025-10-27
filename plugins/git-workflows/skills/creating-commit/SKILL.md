---
name: creating-commit
description: Atomic commit workflow with analysis and validation gates
allowed-tools: [mcp__git__git_status, mcp__git__git_diff_unstaged, mcp__git__git_diff_staged, mcp__git__git_add, mcp__git__git_commit, mcp__git__git_log, mcp__git__git_branch, mcp__sequential-thinking__sequentialthinking, Bash(git ls-remote:*), Read, Glob]
---

# Skill: Creating a Commit

## When to Use This Skill

**Use this skill when the user requests:**
- "commit these changes"
- "create a commit"
- "save my work"
- "make a commit"
- "commit with message X"
- Any variation requesting git commit creation

**Use other skills instead when:**
- Creating a pull request → Use creating-pull-request skill (which will invoke this skill if needed)
- Viewing commit history → Use git log directly
- No changes exist to commit → Report to user and exit

---

## Workflow Description

This skill executes the atomic commit workflow with analysis and validation gates. It follows a deterministic, phase-based procedure with mandatory validation gates at each step.

**Information to gather from user request:**
- Commit message format: Detect if user wants to force Conventional Commits (e.g., "use conventional commits"), default is to auto-detect
- Explicit commit message: Extract if user provided one (e.g., "commit with message '...'"), otherwise auto-generate

---

## Phase 1: Pre-flight Checks

**Objective**: Verify environment is ready for commit operation.

**Steps**:
1. Get current branch: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
2. Get mainline branch: `git ls-remote --exit-code --symref origin HEAD | sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'`
3. Compare: Check if current equals mainline

**Validation Gate: Branch Protection**
IF on mainline AND no explicit approval:
  STOP: "On mainline branch. Create feature branch first."
  PROPOSE: Invoke creating-branch skill
ELSE: Continue to Phase 2

---

## Phase 2: Status Check

**Objective**: Identify uncommitted changes.

**Steps**:
1. Check status: `mcp__git__git_status` with `repo_path` (cwd)
2. Parse: Identify modified, untracked, and staged files

**Validation Gate: Changes Present**
IF no changes: STOP: "Working tree is clean, nothing to commit"
ELSE: Continue to Phase 3

---

## Phase 3: Change Analysis

**Objective**: Analyze changes and detect commit message conventions.

**Steps**:
1. Categorize files by type: code, docs, config, tests
2. Identify scope: single vs multiple files/components
3. Detect Conventional Commits usage (check in order, stop at first match):
   - `Glob` for `.commitlintrc*` or `commitlint.config.*`
   - `Read` CONTRIBUTING.md for "Conventional Commits" mention
   - Analyze recent commits:
     - Run: `mcp__git__git_log` (10 commits)
     - Match against pattern: `^(feat|fix|docs|style|refactor|perf|test|chore)(\(.+\))?!?:.+`
     - If 6+ of 10 commits match, set `use_conventional = true`
     - Otherwise, set `use_conventional = false`
4. Classify change type: feature, fix, refactor, docs, style, test, chore

Continue to Phase 4.

---

## Phase 4: Commit Message Generation

**Objective**: Draft a concise, informative commit message.

**THINKING CHECKPOINT**: Use `mcp__sequential-thinking__sequentialthinking` to:
- Review changes from Phase 3 and identify core purpose
- Determine commit type if Conventional Commits detected
- Draft subject (<50 chars, imperative mood) and optional body
- Validate accuracy and completeness

**Commit Message Format**:
- **Conventional Commits** (if detected): `<type>[scope]: <description>` (e.g., `feat(auth): add JWT token refresh`)
- **Standard** (otherwise): `<Subject line>` (e.g., `Add JWT token refresh mechanism`)
- **Body** (optional): Add only if it provides meaningful context; wrap at 72 chars, explain why not how

**Co-Authored-By**:
- `Read` `.git/config` for `includeCoAuthoredBy` in [commit] section
- IF true: Append trailer with Claude attribution
- Finalize: Subject + body (if any) + co-authored-by (if configured)

Continue to Phase 5.

---

## Phase 5: User Approval

**Objective**: Present commit details for user review and approval.

**Steps**:
1. Present: Files list, proposed commit message
2. Handle diff: Get using `mcp__git__git_diff_unstaged` and `mcp__git__git_diff_staged`
   - If < 100 lines: Show full diff
   - If ≥ 100 lines: Ask user if they want to see it
3. Request approval: "Proceed with this commit? (yes/no/edit)"

**Validation Gate: User Approval**
IF yes: Continue to Phase 6
IF edit: Apply changes, return to Step 1
IF no: STOP: "Commit cancelled"

---

## Phase 6: Execution

**Objective**: Stage files and create commit using MCP tools.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Stage: `mcp__git__git_add` with `repo_path` (cwd), `files` from Phase 2
2. Commit: `mcp__git__git_commit` with `repo_path` (cwd), `message` from Phase 4

**Error Handling**: IF failure:
- Use `mcp__sequential-thinking__sequentialthinking` to analyze
- Explain: What failed, why, impact
- Propose solution and ask user to retry or handle manually

Continue to Phase 7.

---

## Phase 7: Verification

**Objective**: Confirm commit was created successfully.

**Steps**:
1. Get latest: `mcp__git__git_log` with `repo_path` (cwd), `max_count: 1`
2. Extract: SHA, message, files, author, timestamp
3. Verify: Compare message to approved (Phase 5); warn if differs
4. Report success: SHA, message, files count, branch name

Workflow complete.
