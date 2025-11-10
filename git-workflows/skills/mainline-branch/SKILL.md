---
name: mainline-branch
description: Automates mainline branch detection by querying remote HEAD, preventing hardcoded assumptions. Compares current or specified branch against detected mainline to enforce Git Safety Protocol branch protection. Invoked by commit, PR, and branch skills to prevent accidental mainline operations. Use when detecting mainline or validating branch context.
allowed-tools: Bash, Read
---

# Skill: Detecting Mainline Branch

## When to Use This Skill

**Use this skill when:**
- Determining the repository's default/mainline branch (main, master, develop, etc.)
- Checking if current or specified branch is the mainline
- Validating branch context before git operations
- Another skill needs mainline branch information

**This skill is invoked by:**
- creating-commit: To prevent accidental mainline commits
- creating-pull-request: To validate feature branch usage and determine PR base
- creating-branch: To determine default base branch
- rebasing-branch: To prevent mainline rebase attempts

## Workflow Description

This skill detects the repository's mainline branch from remote configuration and optionally compares it against a specified or current branch. It's a read-only utility skill designed for autonomous invocation by other skills.

**Information to gather from invoking context:**
- Branch to compare (optional): If provided, compare against mainline; otherwise just return mainline name
- If no branch specified, detect current branch and use for comparison

## Phase 1: Detect Mainline Branch

**Objective**: Query remote to determine default branch name.

**Steps**:
1. Execute git command to detect mainline:
   ```bash
   git ls-remote --exit-code --symref origin HEAD
   ```

2. Parse output to extract branch name:
   ```bash
   sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'
   ```

**Expected Output**:
```
Single line with mainline branch name (e.g., "main", "master", "develop")
```

**Validation Gate: Mainline Detection**

IF command succeeds and returns branch name:
  Capture mainline branch name
  Continue to Phase 2

IF command fails:
  STOP immediately
  EXPLAIN: "Cannot determine mainline branch from remote origin"
  PROPOSE: "Verify remote configuration with `git remote -v`"
  RETURN: Error state to invoking skill

Phase 1 complete. Continue to Phase 2.

## Phase 2: Get Comparison Branch (Conditional)

**Objective**: Determine which branch to compare against mainline.

**Skip**: If invoking skill only needs mainline name (no comparison required)

**Steps**:
1. Check if comparison branch was provided by invoking skill
2. IF provided: Use specified branch name
3. IF not provided: Get current branch using `git branch --show-current`

**Validation Gate: Branch Retrieved**

IF comparison branch successfully determined:
  Continue to Phase 3

IF cannot determine branch:
  WARN: "No branch to compare (detached HEAD state?)"
  RETURN: Mainline name only, comparison_result = "unknown"

Phase 2 complete. Continue to Phase 3.

## Phase 3: Compare Branches

**Objective**: Determine if comparison branch matches mainline.

**Skip**: If Phase 2 was skipped

**Steps**:
1. Compare branch names (case-sensitive string comparison)
2. Set is_mainline flag:
   - true: Branch matches mainline
   - false: Branch differs from mainline

**Output**: Structured result

```json
{
  "mainline_branch": "main",
  "comparison_branch": "feature/new-api",
  "is_mainline": false
}
```

Or if only mainline detection requested:

```json
{
  "mainline_branch": "main"
}
```

Phase 3 complete. Workflow complete.

## Success Criteria

This skill succeeds when:
- Mainline branch name is successfully detected from remote
- Comparison result is accurately determined (if comparison requested)
- Structured result is returned to invoking skill
