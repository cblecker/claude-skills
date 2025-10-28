# Git Workflows Plugin

Comprehensive Git and GitHub automation for Claude Code. This plugin provides deterministic, phase-based workflows for common git operations with built-in safety, validation, and intelligent decision-making.

## Overview

The git-workflows plugin automates your entire Git and GitHub workflow, from code review through pull request creation. It uses MCP (Model Context Protocol) tools for fine-grained permission control, ensuring safe and transparent operations.

**Key Features:**
- **Automated code review** with security and quality checks
- **Intelligent commit message generation** with Conventional Commits support
- **Smart branch management** with mainline synchronization
- **Fork-aware operations** for both origin and upstream workflows
- **Validation gates** that prevent common mistakes
- **95%+ confidence decisions** using structured reasoning

## Installation

### From Marketplace

```bash
/plugin marketplace add cblecker/claude-plugins
/plugin install git-workflows
```

### Local Development

```bash
git clone https://github.com/cblecker/claude-plugins.git
/plugin install ./claude-plugins/plugins/git-workflows
```

## Available Skills

The plugin provides five core skills that are invoked directly by Claude based on your requests:

### `creating-commit`
Creates atomic commits with optional code review, intelligent message generation, and validation gates. Automatically detects Conventional Commits usage and generates appropriate messages.

**Triggered by:** "commit these changes", "create a commit", "make a commit"

**Flags:**
- `--skip-review` - Skip code review phase
- `--conventional` - Force Conventional Commits format

### `syncing-branch`
Syncs branch with remote, auto-detecting fork vs origin scenarios. Uses appropriate sync strategy based on repository structure.

**Triggered by:** "sync my branch", "pull latest changes", "sync with remote"

**Flags:**
- `--branch <name>` - Sync specific branch instead of current

### `creating-pull-request`
Creates GitHub pull requests with AI-generated title and description. Automatically handles uncommitted changes (invokes creating-commit), pushes branch, and handles fork vs origin PR creation.

**Triggered by:** "create a PR", "make a pull request", "open a PR"

**Flags:**
- `--draft` - Create as draft pull request
- `--title <text>` - Override PR title
- `--body <text>` - Override PR description
- `--base <branch>` - Target branch (default: mainline)

### `creating-branch`
Creates feature branches from synchronized mainline with smart naming. Syncs mainline first (invokes syncing-branch) to ensure you're branching from the latest state. Handles uncommitted changes via stashing or committing.

**Triggered by:** "create a branch", "make a new branch", "create a feature branch"

**Flags:**
- `--from <branch>` - Create from specific branch instead of mainline
- `--no-sync` - Skip syncing mainline before creation

### `rebasing-branch`
Rebases current branch onto updated mainline with conflict handling and optional author date reset. Syncs base branch first (invokes syncing-branch) and handles fork and origin scenarios automatically.

**Triggered by:** "rebase my branch", "rebase on main", "update my branch with main"

**Flags:**
- `--onto <branch>` - Rebase onto specific branch instead of mainline
- `--skip-author-date-reset` - Skip resetting author dates after rebase

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

# Flags are supported in natural language:
"commit without review"  # --skip-review
"create a draft PR"      # --draft
"rebase onto develop"    # --onto develop
```

### Skill Composition

Skills can invoke other skills automatically:

- **creating-pull-request** → **creating-commit** (if uncommitted changes exist)
- **creating-branch** → **syncing-branch** (to sync mainline before branching)
- **rebasing-branch** → **syncing-branch** (to sync base before rebasing)

This ensures workflows are complete and atomic without requiring multiple user commands.

## Read-only Command Approval (Optional)

For smoother operation, you can configure Claude Code to auto-approve read-only operations. This eliminates confirmation prompts for safe operations like checking status, viewing diffs, and listing branches, while still requiring approval for write operations like commits and pushes.

Add this to your Claude Code `settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__git__git_status",
      "mcp__git__git_diff_unstaged",
      "mcp__git__git_diff_staged",
      "mcp__git__git_diff",
      "mcp__git__git_log",
      "mcp__git__git_show",
      "mcp__git__git_branch",
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
      "Bash(git remote get-url:*)",
      "Bash(git branch --show-current)",
      "Bash(git ls-remote:*)",
      "Bash(git merge-base:*)",
      "Bash(git log:*)"
    ]
  }
}
```

## Requirements

### MCP Servers

The following MCP servers are automatically configured when you install the plugin:

- **mcp-server-git** - Git operations via MCP (installed via `uvx`)
- **GitHub Copilot API** - GitHub operations via MCP (HTTP connection)
- **@modelcontextprotocol/server-sequential-thinking** - Structured reasoning (installed via `npx`)

### Prerequisites

- **uv** (for `uvx` command)
- **Node.js** (for `npx` command)
- **GITHUB_TOKEN** environment variable must be set for GitHub operations
- Claude Code with MCP support
