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
/plugin marketplace add cblecker/claude-skills
/plugin install git-workflows
```

### Local Development

```bash
git clone https://github.com/cblecker/claude-skills.git
/plugin install ./claude-skills/git-workflows
```

## Available Skills

The plugin provides five core skills that are invoked directly by Claude based on your requests:

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
Creates feature branches from synchronized mainline with smart naming. Syncs mainline first (invokes syncing-branch) to ensure you're branching from the latest state. Handles uncommitted changes via stashing or committing.

**Triggered by:** "create a branch", "make a new branch", "create a feature branch"

**Natural Language Options:**
- Create from specific branch - Say "from [branch]" or "based on [branch]" (defaults to mainline)
- Skip sync - Say "without syncing" or "skip sync"

### `rebasing-branch`
Rebases current branch onto updated mainline with conflict handling and optional author date reset. Syncs base branch first (invokes syncing-branch) and handles fork and origin scenarios automatically.

**Triggered by:** "rebase my branch", "rebase on main", "update my branch with main"

**Natural Language Options:**
- Rebase onto specific branch - Say "rebase onto [branch]" (defaults to mainline)
- Skip author date reset - Say "skip author date reset" or "keep author dates"

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
