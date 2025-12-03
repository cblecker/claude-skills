# git-workflows Scripts Documentation

This directory contains bash scripts that optimize git workflow operations by consolidating multiple git commands into single, atomic operations.

## Overview

The scripts are organized into categories based on their purpose:

1. **Helper Scripts**: Low-level utilities for parsing and categorizing
2. **Utility Scripts**: Repository metadata detection
3. **Context Gatherers**: Comprehensive context collection for workflows
4. **Verification Scripts**: Standardized operation reporting

## Script Categories

### 1. Helper Scripts

#### parse-git-status.sh
Parses `git status --porcelain` output into structured JSON.

**Usage:**
```bash
git status --porcelain | ./parse-git-status.sh
```

**Output:**
```json
{
  "is_clean": false,
  "staged": [
    {"status": "M", "path": "file.txt"}
  ],
  "unstaged": [],
  "untracked": ["debug.log"]
}
```

#### categorize-files.sh
Categorizes files by type (code, tests, docs, config, other).

**Usage:**
```bash
echo -e "src/main.ts\nREADME.md" | ./categorize-files.sh
```

**Output:**
```json
{
  "code": ["src/main.ts"],
  "tests": [],
  "docs": ["README.md"],
  "config": [],
  "other": []
}
```

### 2. Utility Scripts

#### get-repository-type.sh
Detects fork vs origin repository and extracts owner/repo metadata.

**Usage:**
```bash
./get-repository-type.sh
```

**Output (Fork):**
```json
{
  "success": true,
  "is_fork": true,
  "upstream": {
    "url": "https://github.com/anthropics/claude-code.git",
    "owner": "anthropics",
    "repo": "claude-code"
  },
  "origin": {
    "url": "https://github.com/user/claude-code.git",
    "owner": "user",
    "repo": "claude-code"
  }
}
```

#### get-mainline-branch.sh
Detects mainline branch and optionally compares against a specified branch.

**Usage:**
```bash
./get-mainline-branch.sh [branch_name]
```

**Output:**
```json
{
  "success": true,
  "mainline_branch": "main",
  "comparison_branch": "feature-branch",
  "is_mainline": false
}
```

#### detect-conventions.sh
Detects if repository uses Conventional Commits.

**Usage:**
```bash
./detect-conventions.sh
```

**Output (With commitlint config):**
```json
{
  "success": true,
  "uses_conventional_commits": true,
  "detection_method": "commitlint_config",
  "confidence": "high",
  "config_file": ".commitlintrc.json"
}
```

**Output (From commit history):**
```json
{
  "success": true,
  "uses_conventional_commits": true,
  "detection_method": "commit_history",
  "confidence": "high",
  "pattern_match_rate": 0.85,
  "sample_size": 10
}
```

### 3. Context Gatherers

#### gather-commit-context.sh
Gathers all context needed for commit message generation in a single call.

**Usage:**
```bash
./gather-commit-context.sh
```

**Output:**
```json
{
  "success": true,
  "current_branch": "feature/add-logging",
  "mainline_branch": "main",
  "is_mainline": false,
  "uses_conventional_commits": true,
  "conventional_commits_confidence": "high",
  "working_tree_status": {
    "is_clean": false,
    "has_staged": true,
    "has_unstaged": false,
    "has_untracked": true
  },
  "staged_files": [
    {"status": "M", "path": "src/logger.ts"},
    {"status": "A", "path": "src/logger.test.ts"}
  ],
  "unstaged_files": [],
  "untracked_files": ["debug.log"],
  "file_categories": {
    "code": ["src/logger.ts"],
    "tests": ["src/logger.test.ts"],
    "docs": [],
    "config": [],
    "other": ["debug.log"]
  },
  "recent_commits": [
    {"hash": "abc123", "subject": "feat: add user auth"}
  ],
  "diff_summary": {
    "files_changed": 2,
    "insertions": 45,
    "deletions": 12
  }
}
```

**Replaces:** 10-12 separate tool calls in `creating-commit` skill

#### gather-pr-context.sh
Gathers all context needed for PR title/description generation.

**Usage:**
```bash
./gather-pr-context.sh [base_branch]
```

**Output:**
```json
{
  "success": true,
  "current_branch": "feature/add-logging",
  "base_branch": "main",
  "is_fork": true,
  "repository": {
    "upstream_owner": "anthropics",
    "upstream_repo": "claude-code",
    "origin_owner": "user",
    "origin_repo": "claude-code"
  },
  "branch_validation": {
    "is_feature_branch": true,
    "has_uncommitted_changes": false
  },
  "uncommitted_files": [],
  "commit_history": [
    {
      "hash": "abc123",
      "subject": "feat: add structured logging",
      "body": "Implements Winston logger"
    }
  ],
  "diff_summary": {
    "files_changed": 5,
    "insertions": 150,
    "deletions": 25
  },
  "uses_conventional_commits": true
}
```

**Replaces:** 8-10 separate tool calls in `creating-pull-request` skill

### 4. Workflow Execution Scripts

#### sync-branch.sh
Executes fork-aware branch synchronization with automatic remote detection.

**Usage:**
```bash
./sync-branch.sh [branch_name]
```

**Output (Fork - Success):**
```json
{
  "success": true,
  "branch": "main",
  "is_fork": true,
  "operations_performed": [
    "fetched_all",
    "rebased_on_upstream",
    "pushed_to_origin"
  ],
  "commits_pulled": 3,
  "status": "up_to_date"
}
```

**Output (Origin - Success):**
```json
{
  "success": true,
  "branch": "main",
  "is_fork": false,
  "operations_performed": [
    "fetched_origin",
    "merged_fast_forward"
  ],
  "commits_pulled": 2,
  "status": "up_to_date"
}
```

**Error (Uncommitted Changes):**
```json
{
  "success": false,
  "error_type": "uncommitted_changes",
  "message": "Cannot sync with uncommitted changes",
  "suggested_action": "Commit or stash your changes before syncing",
  "uncommitted_files": ["file.txt"]
}
```

**Replaces:** Entire `syncing-branch` skill workflow

### 5. Verification Scripts

#### verify-operation.sh
Provides standardized verification and reporting for workflow operations.

**Usage:**
```bash
./verify-operation.sh <operation_type> [args...]
```

**Operation Types:**
- `commit`: Verify last commit
- `branch <branch_name> [base_branch]`: Verify branch creation
- `sync <branch_name>`: Verify sync operation
- `pr <pr_url>`: Verify PR creation

**Output (Commit):**
```json
{
  "success": true,
  "operation": "commit",
  "details": {
    "commit_hash": "abc123def456...",
    "short_hash": "abc123d",
    "branch": "feature-branch",
    "subject": "feat: add logging",
    "author": "User Name",
    "date": "2025-11-20T12:00:00-08:00",
    "files_changed": 3
  },
  "formatted_report": "✓ Commit Completed Successfully\n\n**Commit:** abc123d\\\n**Branch:** feature-branch\\\n..."
}
```

## Using Scripts in Skills

### Basic Pattern

Skills reference scripts using natural language. Each skill has a `scripts/` directory containing symlinks to the scripts it uses.

```markdown
## Phase 1: Gather Context

Use the gather-commit-context.sh script to collect all commit context

Parse the JSON output:
- Check `.success` field
- If false, handle error using `.error_type` and `.message`
- If true, extract context from the response

Example error handling:
- `clean_working_tree`: No changes to commit
- `not_git_repo`: Not in a git repository
```

### Integration with Bash and MCP

Skills should:

1. **Use scripts for data gathering** (read operations)
2. **Use bash git commands for local git operations** (add, commit, checkout)
3. **Use GitHub MCP tools for remote operations** (PR creation)

Example workflow for creating a commit:

```markdown
## Phase 1-3: Gather Context
Use gather-commit-context.sh to get all context in one call.

## Phase 4: Message Generation
Use the context + AI to generate commit message.

## Phase 5: User Approval
Present message and file list for approval.

## Phase 6: Execution
Use bash git commands:
1. git add . to stage files
2. git commit -m "message" to create commit

Git hooks work automatically!

## Phase 7: Verification
Use verify-operation.sh to generate standardized report.
```

## Performance Impact

### Tool Call Reduction

**creating-commit skill:**
- Before: ~12-15 tool calls
- After: 3 tool calls (gather-context, git_add, git_commit)
- **Reduction: 75-80%**

**creating-pull-request skill:**
- Before: ~10-12 tool calls
- After: 2-3 tool calls (gather-context, create PR)
- **Reduction: 75-83%**

**Utility operations:**
- Repository type detection: 4-5 calls → 1 call (80% reduction)
- Mainline branch detection: 2-3 calls → 1 call (67% reduction)
- Convention detection: Multiple glob/read operations → 1 call (90% reduction)

### Execution Speed

Scripts execute deterministic operations 3-5x faster than step-by-step tool calls due to:
- Single process execution
- No tool call overhead
- Atomic operations
- Efficient bash execution

## Error Handling

All scripts return JSON with a `success` field:

### Success Response
```json
{
  "success": true,
  ...data...
}
```

### Error Response
```json
{
  "success": false,
  "error_type": "clean_working_tree",
  "message": "No changes to commit",
  "suggested_action": "Make changes before creating a commit"
}
```

### Common Error Types
- `not_git_repo`: Not in a git repository
- `no_remote`: No remote configured
- `clean_working_tree`: No changes to commit
- `on_base_branch`: Cannot create PR from base branch
- `no_commits`: No commits in branch
- `remote_head_not_found`: Could not detect mainline branch
- `invalid_url`: Could not parse remote URL

## Testing

All scripts have comprehensive test coverage:

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suites
./tests/unit/test-helpers.sh
./tests/unit/test-utility-scripts.sh
./tests/integration/test-context-gatherers.sh
```

Current test coverage: All tests passing

## Dependencies

All scripts require:
- `bash` (POSIX-compliant)
- `git`
- `jq` (for JSON processing)
- Standard Unix utilities (`sed`, `grep`, `cut`)

These dependencies are typically available in all development environments.

## Script Paths

Skills reference shared scripts using explicit relative paths from the skill directory:

```
git-workflows/
├── scripts/               # Shared script location
│   ├── gather-commit-context.sh
│   ├── gather-pr-context.sh
│   ├── get-mainline-branch.sh
│   └── ...
└── skills/
    ├── creating-commit/
    │   └── SKILL.md       # References: ../../scripts/gather-commit-context.sh
    ├── creating-pull-request/
    │   └── SKILL.md       # References: ../../scripts/gather-pr-context.sh
    └── ...
```

**Pattern:**
Skills use `../../scripts/<script-name>.sh` to reference shared scripts directly.

**Benefits:**
- No symlink indirection - scripts are called from their actual location
- Explicit paths that Claude interprets unambiguously
- Simpler directory structure
- Inter-script dependencies work via `SCRIPT_DIR` resolution

## Exit Code Semantics

Scripts use exit codes to distinguish between actual errors and expected conditions:

**Exit 1 (Actual Errors):**
- `missing_dependency` - Required tool (jq, git) not installed
- `not_git_repo` - Not in a git repository
- `remote_head_not_found` - Cannot detect remote HEAD
- `git_status_failed` - Git command failed
- `sync_conflict` - Merge conflict during sync
- `sync_failed` - Sync operation failed
- `branch_diverged` - Branch has diverged from remote

**Exit 0 (Expected Conditions):**
- `on_base_branch` - User is on the base/mainline branch
- `no_commits` - No commits between branches
- `clean_working_tree` - No changes to commit
- `uncommitted_changes` - Working directory has uncommitted changes

This allows Claude Code to show error indicators only for actual script failures, not for expected state validations.

## Completed Implementation

All planned scripts from the refactor (Phases 1-5) are now complete:
- ✓ Helper scripts (parse-git-status, categorize-files)
- ✓ Utility scripts (get-repository-type, get-mainline-branch, detect-conventions)
- ✓ Context gatherers (gather-commit-context, gather-pr-context)
- ✓ Workflow execution (sync-branch)
- ✓ Verification utilities (verify-operation)

**Test Coverage:** All tests passing

## Future Enhancements

Potential future additions:
- Performance monitoring and metrics collection
- Additional workflow automation scripts
- Enhanced conflict resolution guidance
- Git hook integration utilities

## Support

For issues or questions:
- Check test files for usage examples
- See skill implementations for integration patterns
