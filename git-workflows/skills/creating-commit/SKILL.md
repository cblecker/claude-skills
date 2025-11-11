---
name: creating-commit
description: Primary commit workflow replacing manual git commands: implements automated Git Safety Protocol analyzing staged/unstaged changes, drafting convention-aware messages (detects Conventional Commits from history), enforcing mainline protection, handling pre-commit hooks safely. Standard procedure: 'commit', 'save changes', 'create commit', 'check in', 'commit these changes'.
---

# Skill: Creating a Commit

## When to Use This Skill

Use this skill for commit requests: "commit these changes", "create a commit", "save my work", "commit with message X".

Use other skills for: creating PRs (creating-pull-request), viewing history (git log directly).

## Workflow Description

Executes atomic commit workflow with analysis and validation gates.

Extract from user request: commit message format ("use conventional commits" → force, default auto-detect), explicit message (if provided, else auto-generate)

---

## Phase 1: Pre-flight Checks

**Objective**: Verify environment is ready for commit operation.

**Steps**:
1. Invoke mainline-branch skill to detect mainline and check if on mainline:
   - Request comparison against current branch
   - Receive structured result with is_mainline flag

2. Detect GPG signing configuration:
   ```bash
   git config --get commit.gpgsign
   ```
   Capture: `gpg_enabled` (true if output is "true", false otherwise). Store for Phase 6.

**Validation Gate: Branch Protection**

IF is_mainline = false (on feature branch):
  Continue to Phase 2

IF is_mainline = true (on mainline):
  Check user request and context:

  IF user explicitly stated commit to mainline is acceptable:
    Examples: CLAUDE.md allows mainline commits, request says "commit to main"
    INFORM: "Proceeding with mainline commit as authorized"
    Continue to Phase 2

  IF no explicit authorization:
    INFORM: "Currently on mainline branch - creating feature branch first"
    INVOKE: creating-branch skill
    WAIT for creating-branch skill to complete

    IF creating-branch succeeded:
      VERIFY: Now on feature branch (not mainline)
      Continue to Phase 2

    IF creating-branch failed:
      STOP immediately
      EXPLAIN: "Branch creation failed, cannot proceed with commit"
      EXIT workflow

Phase 1 complete. Continue to Phase 2.

---

## Phase 2: Status Check

**Objective**: Identify uncommitted changes.

**Steps**:
1. Check status using git CLI:
   ```bash
   git status --porcelain
   ```

2. Parse output:
   - Lines starting with M, A, D, ??, etc. indicate changes
   - Empty output means clean working tree

3. Categorize files:
   - Staged: Lines starting with M, A, D, R, C (left column)
   - Unstaged: Lines with modifications in right column
   - Untracked: Lines starting with ??

**Validation Gate: Changes Present**

IF no changes (empty output):
  STOP: "Working tree is clean, nothing to commit"

IF changes present:
  Continue to Phase 3

Phase 2 complete. Continue to Phase 3.

---

## Phase 3: Change Analysis

**Objective**: Analyze changes and detect commit message conventions.

**Steps**:
1. Get full diff for analysis:
   ```bash
   git diff HEAD
   ```

2. Categorize files by type: code, docs, config, tests
3. Identify scope: single vs multiple files/components

4. Invoke detect-conventional-commits skill:
   - Receive structured result with uses_conventional_commits flag
   - Store for Phase 4

5. Classify change type: feature, fix, refactor, docs, style, test, chore

Continue to Phase 4.

---

## Phase 4: Commit Message Generation

**Objective**: Draft a concise, informative commit message.

**THINKING CHECKPOINT**: Use `mcp__sequential-thinking__sequentialthinking` to:
- Review changes from Phase 3 and identify core purpose
- Determine commit type if Conventional Commits detected
- Draft subject (<50 chars, imperative mood) and optional body
- Review the message for conciseness and clarity
- Validate accuracy and completeness

**Commit Message Format**:
- **Conventional Commits** (if detected): `<type>[scope]: <description>` (e.g., `feat(auth): add JWT token refresh`)
- **Standard** (otherwise): `<Subject line>` (e.g., `Add JWT token refresh mechanism`)
- **Body** (optional): Add only if it provides meaningful context; wrap at 72 chars, explain why not how

**Co-Authored-By**:
- Respect the `includeCoAuthoredBy` setting in Claude Code configuration
- IF enabled: Append trailer with Claude attribution
- Finalize: Subject + body (if any) + co-authored-by (if configured)

Continue to Phase 5.

---

## Phase 5: User Approval

**Objective**: Present commit details for user review and approval.

**Steps**:
1. Present: Files list, proposed commit message
2. Handle diff:
   ```bash
   git diff HEAD
   ```
   - If < 100 lines: Show full diff
   - If ≥ 100 lines: Ask user if they want to see it
3. Request approval using AskUserQuestion tool:
   - Question: "How would you like to proceed with this commit?"
   - Header: "Commit"
   - Options:
     - **Proceed**: "Create the commit with this message" - Continues to Phase 6
     - **Edit message**: "Modify the commit message" - Returns to Step 1 with user's custom message
     - **Cancel**: "Don't create this commit" - Stops workflow

**Validation Gate: User Approval**
HANDLE user selection:
- IF "Proceed": Continue to Phase 6
- IF "Edit message":
  - User provides custom message via "Other" option
  - Apply custom message (replace generated message)
  - Return to Step 1 to show updated commit details
- IF "Cancel": STOP: "Commit cancelled by user"

---

## Phase 6: Execution

**Objective**: Stage files and create commit, handling GPG signing if enabled.

**Plan Mode**: Auto-enforced read-only if active

**GPG Signing Handling**:
- IF `gpg_enabled` from Phase 1:
  - Use `dangerouslyDisableSandbox: true` for `git commit`
  - Reason: GPG requires write access to `~/.gnupg` for lock files and socket access to gpg-agent
  - This is safe because git is trusted and commit content was reviewed in Phase 5

**Steps**:
1. Stage all changes:
   ```bash
   git add -A
   ```

2. Create commit:
   ```bash
   git commit -m "<subject>" [-m "<body>"]
   ```

**Error Handling**: IF failure:
- Analyze error output
- Explain: what failed, why, and potential impact
- Common issues: pre-commit hooks failed, insufficient permissions, empty commit, GPG signing issues
- Propose solution and ask user to retry or handle manually

Continue to Phase 7.

---

## Phase 7: Verification

**Objective**: Confirm commit was created successfully.

**Steps**:
1. Get latest commit:
   ```bash
   git log -1 --format="%H%n%s%n%an%n%ad" --date=iso
   ```

2. Parse output:
   - Line 1: Commit SHA
   - Line 2: Subject line
   - Line 3: Author name
   - Line 4: Author date

3. Get commit file count:
   ```bash
   git show --stat --format="" HEAD | wc -l
   ```

4. Get current branch:
   ```bash
   git branch --show-current
   ```

5. Verify: Compare subject to approved message from Phase 5; warn if differs

6. Report using template:
   ```text
   ✓ Commit Created Successfully

   Commit: <sha_short> "<subject>"
   Branch: <branch_name>
   Files: <file_count> file(s) changed
   Author: <author_name>
   ```

---

## Implementation Notes

### GPG Commit Signing

When git is configured with `commit.gpgsign=true`, the commit operation requires sandbox to be disabled because:

1. **Filesystem Access**: GPG creates temporary lock files in `~/.gnupg/` which is not in the sandbox write allowlist
2. **Socket Access**: GPG connects to the agent socket at `~/.gnupg/S.gpg-agent` which is not in the sandbox Unix socket allowlist

**Security Assessment:**
- Risk: Low to moderate
- Justification: Git is a trusted system binary, commit content is user-reviewed in Phase 5, and GPG signing is explicitly configured by the user
- This follows the same pattern as other privileged system operations (e.g., npm install)

The skill automatically detects GPG configuration in Phase 1 and applies appropriate sandbox handling in Phase 6 without user intervention.
