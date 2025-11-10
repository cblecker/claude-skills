---
name: detect-conventional-commits
description: Automates Conventional Commits detection through multi-phase analysis: checks commitlint configs, scans documentation (CONTRIBUTING.md), analyzes commit history patterns (60% threshold). Ensures Git Safety Protocol compliance by identifying project conventions before commit creation. Autonomously invoked by commit and branch skills to determine message/branch format conventions.
allowed-tools: Bash, Glob, Read
---

# Skill: Detecting Conventional Commits Usage

## When to Use This Skill

**Use this skill when:**
- Determining if repository uses Conventional Commits format
- Generating commit messages or branch names
- Enforcing project commit conventions
- Another skill needs to know commit message format

**This skill is invoked by:**
- creating-commit: To determine commit message format
- creating-branch: To determine if branch names should include type prefixes (feat/, fix/, etc.)

## Workflow Description

This skill detects whether a repository follows Conventional Commits conventions by checking for commitlint configuration, documentation references, and analyzing commit history patterns.

**Information to gather from invoking context:**
- None required - skill analyzes current repository state

## Phase 1: Check for Commitlint Configuration

**Objective**: Look for explicit Conventional Commits configuration files.

**Steps**:
1. Search for commitlint config files:
   ```
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

**Early Return: Commitlint Found**

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
   ```
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

**Early Return: Documentation Reference Found**

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
   - matches = number of commits matching pattern
   - total = 10 (number of commits analyzed)

4. Calculate match rate:
   - match_rate = matches / total

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
  "uses_conventional_commits": true,
  "detection_method": "history_pattern",
  "confidence": "medium",
  "pattern_match_rate": 0.7,
  "commits_analyzed": 10,
  "commits_matched": 7
}
```

Or if not using Conventional Commits:

```json
{
  "uses_conventional_commits": false,
  "detection_method": "history_pattern",
  "confidence": "medium",
  "pattern_match_rate": 0.2,
  "commits_analyzed": 10,
  "commits_matched": 2
}
```

Phase 3 complete. Workflow complete.

## Success Criteria

This skill succeeds when:
- Detection method completes successfully (config, docs, or history)
- Boolean result (uses_conventional_commits) is determined
- Confidence level is reported
- Structured result is returned to invoking skill

## Notes

**Detection Priority** (checked in order):
1. Commitlint configuration (highest confidence)
2. Documentation references (high confidence)
3. Commit history patterns (medium confidence)

**Pattern Matching**:
- Requires 60% match rate for positive detection
- Analyzes most recent 10 commits
- Matches standard Conventional Commits types

**Confidence Levels**:
- high: Config file or explicit documentation
- medium: Inferred from commit history patterns
