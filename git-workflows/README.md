# Git Workflows Plugin

Comprehensive Git and GitHub automation for Claude Code. This plugin provides deterministic, phase-based workflows for common git operations with built-in safety, validation, and intelligent decision-making.

## Overview

The git-workflows plugin automates your entire Git and GitHub workflow, from code review through pull request creation. It provides deterministic, phase-based workflows with built-in safety, validation, and intelligent decision-making.

**Key Features:**
- **Automated code review** with security and quality checks
- **Intelligent commit message generation** with Conventional Commits support
- **Smart branch management** with automatic mainline detection
- **Fork-aware operations** for both origin and upstream workflows
- **Validation gates** that prevent common mistakes
- **95%+ confidence decisions** using structured reasoning
- **Direct git CLI commands** for transparent operations

## Installation

### From Marketplace

```bash
/plugin marketplace add cblecker/claude-skills
/plugin install git-workflows
```

### Local Development

```bash
git clone https://github.com/cblecker/claude-skills.git
/plugin install ./claude-skills/git-workflows
```

## Available Skills

The plugin provides five core workflow skills and three utility skills that are invoked automatically by Claude based on your requests:

### Workflow Skills

### `creating-commit`
Creates atomic commits with optional code review, intelligent message generation, and validation gates. Automatically detects Conventional Commits usage and generates appropriate messages.

**Triggered by:** "commit these changes", "create a commit", "make a commit"

**Natural Language Options:**
- Skip review - Say "without review" or "skip review" in your request
- Force Conventional Commits - Say "use conventional commits" in your request

### `syncing-branch`
Syncs branch with remote, auto-detecting fork vs origin scenarios. Uses appropriate sync strategy based on repository structure.

**Triggered by:** "sync my branch", "pull latest changes", "sync with remote"

**Natural Language Options:**
- Sync specific branch - Say "sync [branch-name]" or "sync the [branch-name] branch"

### `creating-pull-request`
Creates GitHub pull requests with AI-generated title and description. Automatically handles uncommitted changes (invokes creating-commit), pushes branch, and handles fork vs origin PR creation.

**Triggered by:** "create a PR", "make a pull request", "open a PR"

**Natural Language Options:**
- Draft PR - Say "draft PR" or mention "WIP" in your request
- Custom title - Say "create PR titled '[your title]'" or "with title '[your title]'"
- Custom description - Say "with description '[your description]'"
- Target branch - Say "create PR to [branch]" or "base on [branch]" (defaults to mainline)

### `creating-branch`
Creates feature branches from current state with smart naming. Automatically detects Conventional Commits usage to generate type-prefixed branch names (feat/, fix/, etc.). Preserves uncommitted changes when creating the new branch.

**Triggered by:** "create a branch", "make a new branch", "create a feature branch"

**Natural Language Options:**
- Create from specific branch - Say "from [branch]" or "based on [branch]" (defaults to mainline)
- Explicit branch name - Say "called [name]" or "named [name]"

### `rebasing-branch`
Rebases current branch onto updated mainline with conflict handling and optional author date reset. Syncs base branch first (invokes syncing-branch) and handles fork and origin scenarios automatically.

**Triggered by:** "rebase my branch", "rebase on main", "update my branch with main"

**Natural Language Options:**
- Rebase onto specific branch - Say "rebase onto [branch]" (defaults to mainline)
- Skip author date reset - Say "skip author date reset" or "keep author dates"

### Utility Skills (Automatically Invoked)

The following utility skills are automatically invoked by the main workflow skills to encapsulate common operations. You don't need to invoke these directly.

#### `mainline-branch`
Detects the repository's mainline/default branch by querying remote HEAD configuration. Compares current or specified branch against mainline to enforce branch protection. Invoked by commit, PR, branch, and rebase skills.

#### `repository-type`
Detects fork vs origin repository structure by analyzing git remote configuration. Extracts owner and repository names from remote URLs for GitHub operations. Invoked by PR and sync skills.

#### `detect-conventional-commits`
Detects whether the repository follows Conventional Commits convention through configuration analysis and commit history pattern matching. Invoked by commit and branch skills to determine message/name format.

## Usage

The skills are invoked automatically by Claude based on your natural language requests. Simply describe what you want to do:

```bash
# Create a commit with review
"commit these changes"

# Create a feature branch
"create a new branch for adding metrics"

# Rebase your branch onto main
"rebase my branch on main"

# Sync your branch with remote
"sync my branch with latest from main"

# Create a pull request
"create a PR for this"

# Natural language variations work seamlessly:
"commit without review"
"create a draft PR"
"rebase onto develop"
```

### Skill Composition

Skills can invoke other skills automatically:

- **creating-commit** → **creating-branch** (if on mainline branch)
- **creating-pull-request** → **creating-commit** (if uncommitted changes exist) → **creating-branch** (if on mainline)
- **rebasing-branch** → **syncing-branch** (to sync base before rebasing)

All workflow skills automatically invoke utility skills as needed for mainline detection, repository type detection, and convention detection.

This ensures workflows are complete and atomic without requiring multiple user commands.

### Reporting Standards

The plugin follows consistent reporting standards based on skill type:

**Utility Skills** (mainline-branch, repository-type, detect-conventional-commits):
- Return structured JSON output for programmatic consumption by other skills
- Include all required data for downstream decision-making
- Example formats provided in each skill's final phase

**User-Facing Workflow Skills** (creating-commit, creating-branch, creating-pull-request, syncing-branch, rebasing-branch):
- Use standardized reporting templates for consistency
- Include success indicator (✓), operation name, key information, and next steps when applicable
- Provide consistent user experience across all git operations

Example template format:
```text
✓ <Operation> Completed Successfully

<Key Info Line 1>
<Key Info Line 2>
...

[Optional: Important notes or next steps]
```

## Read-only Command Approval (Optional)

For smoother operation, you can configure Claude Code to auto-approve read-only operations. This eliminates confirmation prompts for safe operations like checking status, viewing diffs, and listing branches, while still requiring approval for write operations like commits and pushes.

Add this to your Claude Code `settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Skill(git-workflows:*)",
      "mcp__github__get_pull_request",
      "mcp__github__get_pull_request_diff",
      "mcp__github__get_pull_request_files",
      "mcp__github__get_pull_request_reviews",
      "mcp__github__get_pull_request_review_comments",
      "mcp__github__get_pull_request_status",
      "mcp__github__list_branches",
      "mcp__github__get_issue",
      "mcp__github__list_issues",
      "mcp__github__list_sub_issues",
      "mcp__github__get_commit",
      "mcp__github__list_commits",
      "mcp__github__get_file_contents",
      "mcp__github__get_me",
      "mcp__sequential-thinking",
      "Bash(git config --get:*)",
      "Bash(git branch --show-current)",
      "Bash(git status:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git diff:*)",
      "Bash(git ls-remote:*)",
      "Bash(git remote get-url:*)",
      "Bash(git merge-base:*)",
      "Bash(git rev-parse:*)"
    ]
  }
}
```

## Requirements

### MCP Servers

The following MCP servers are recommended for enhanced functionality:

- **GitHub Copilot API** - GitHub operations via MCP (HTTP connection)
- **@modelcontextprotocol/server-sequential-thinking** - Structured reasoning (installed via `npx`)

The plugin uses direct git CLI commands for all git operations, eliminating the need for git MCP servers.

### Prerequisites

- **Git** - Git CLI must be available in PATH
- **jq** - JSON processor required for UserPromptSubmit hook functionality (hook will show a warning if not installed)
- **Node.js** (for `npx` command, if using sequential-thinking MCP)
- **GITHUB_TOKEN** environment variable must be set for GitHub operations
- Claude Code with MCP support (optional - for GitHub MCP and sequential-thinking)
