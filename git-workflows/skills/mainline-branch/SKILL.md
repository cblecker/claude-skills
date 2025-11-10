---
name: mainline-branch
description: Automates mainline branch detection by querying remote HEAD, preventing hardcoded assumptions. Compares current or specified branch against detected mainline to enforce Git Safety Protocol branch protection. Invoked by commit, PR, and branch skills to prevent accidental mainline operations. Use when detecting mainline or validating branch context.
allowed-tools: Bash, Read
---

# Skill: Detecting Mainline Branch

## When to Use This Skill

Use when determining mainline branch (main/master/develop), checking if current/specified branch is mainline, validating branch context, or when another skill needs mainline info.

Invoked by: creating-commit (prevent mainline commits), creating-pull-request (validate feature branch/PR base), creating-branch (default base), rebasing-branch (prevent mainline rebase).

## Workflow Description

Detects repository mainline from remote config, optionally compares against specified or current branch. Read-only utility for autonomous invocation.

Gather from context: branch to compare (optional, else detect current).

---

## Phase 1: Detect Mainline Branch

Query remote for default branch:
```bash
git ls-remote --exit-code --symref origin HEAD | sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'
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
  "is_mainline": <true|false>,
  "mainline_branch": "<mainline_branch_name>",
  "comparison_branch": "<comparison_branch_name>"
}
```

Phase 3 complete. Workflow complete.
