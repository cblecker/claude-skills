---
name: detect-conventional-commits
description: Automates Conventional Commits detection through multi-phase analysis: checks commitlint configs, scans documentation (CONTRIBUTING.md), analyzes commit history patterns (60% threshold). Ensures Git Safety Protocol compliance by identifying project conventions before commit creation. Autonomously invoked by commit and branch skills to determine message/branch format conventions.
allowed-tools: Bash, Glob, Read
---

# Skill: Detecting Conventional Commits Usage

## When to Use This Skill

Use when determining Conventional Commits usage, generating commit messages/branch names, enforcing conventions, or when another skill needs commit format info.

Invoked by: creating-commit (message format), creating-branch (type prefixes feat/, fix/).

## Workflow Description

Detects Conventional Commits usage via commitlint config, documentation references, or commit history patterns (checked in priority order).

---

## Phase 1: Check for Commitlint Configuration

**Objective**: Look for explicit Conventional Commits configuration files.

**Steps**:
1. Search for commitlint config files:
   ```text
   Use Glob to search for:
   - .commitlintrc
   - .commitlintrc.json
   - .commitlintrc.yml
   - .commitlintrc.yaml
   - .commitlintrc.js
   - .commitlintrc.cjs
   - .commitlintrc.ts
   - commitlint.config.js
   - commitlint.config.cjs
   - commitlint.config.ts
   ```

2. Check glob results:
   - IF any file found: Set has_commitlint = true
   - IF no files found: Set has_commitlint = false

### Early Return: Commitlint Found

IF has_commitlint = true:
  RETURN immediately:
  ```json
  {
    "uses_conventional_commits": true,
    "detection_method": "commitlint_config",
    "confidence": "high"
  }
  ```

IF has_commitlint = false:
  Continue to Phase 2

Phase 1 complete. Continue to Phase 2.

## Phase 2: Check Documentation

**Objective**: Search for Conventional Commits references in documentation.

**Steps**:
1. Check if CONTRIBUTING.md exists using Glob:
   ```text
   Pattern: CONTRIBUTING.md or .github/CONTRIBUTING.md
   ```

2. IF file exists:
   - Read CONTRIBUTING.md
   - Search for keywords:
     - "Conventional Commits"
     - "conventionalcommits.org"
     - "commit message format"
     - Type prefixes pattern: feat:, fix:, docs:, etc.

3. IF keywords found:
   Set has_doc_reference = true

### Early Return: Documentation Reference Found

IF has_doc_reference = true:
  RETURN immediately:
  ```json
  {
    "uses_conventional_commits": true,
    "detection_method": "documentation",
    "confidence": "high"
  }
  ```

IF has_doc_reference = false:
  Continue to Phase 3

Phase 2 complete. Continue to Phase 3.

## Phase 3: Analyze Commit History

**Objective**: Use pattern matching on recent commits to infer convention usage.

**Steps**:
1. Get recent commit messages:
   ```bash
   git log --format=%s -n 10
   ```

2. For each commit message, test against Conventional Commits pattern:
   ```regex
   ^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\(.+\))?!?: .+
   ```

3. Count matches:
   - match_count = number of commits matching pattern
   - total_commits = 10 (number of commits analyzed)

4. Calculate match rate:
   - match_rate = match_count / total_commits

**Decision Logic**:

IF match_rate >= 0.6 (60% or more commits match):
  Set uses_conventional_commits = true
  Set confidence = "medium"
  Set detection_method = "history_pattern"

IF match_rate < 0.6:
  Set uses_conventional_commits = false
  Set confidence = "medium"
  Set detection_method = "history_pattern"

**Output**: Structured result

```json
{
  "uses_conventional_commits": <true|false>,
  "detection_method": "history_pattern",
  "confidence": "medium",
  "pattern_match_rate": <rate>,
  "commits_analyzed": 10,
  "commits_matched": <count>
}
```

Phase 3 complete. Workflow complete.
