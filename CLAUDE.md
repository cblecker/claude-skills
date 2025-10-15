# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal collection of Claude Code plugins that extend Claude Code's capabilities through custom subagents, slash commands, hooks, and MCP servers. The repository serves as a plugin marketplace that can be added to Claude Code via `/plugin marketplace add cblecker/claude-plugins`.

## Repository Structure

```
plugins/
└── <plugin-name>/
    ├── plugin.json          # Plugin metadata and configuration
    ├── agents/              # Subagent definitions (markdown with YAML frontmatter)
    ├── commands/            # Slash command definitions (markdown files)
    ├── hooks/               # Hook configurations
    └── mcp/                 # MCP server configurations
```

### Plugin Components

**Subagents** are defined as markdown files with YAML frontmatter:
- Frontmatter includes: name, description, tools, model
- Body contains the system prompt defining the agent's role and capabilities

**Slash Commands** are markdown files with optional YAML frontmatter:
- Frontmatter includes: description, allowed-tools
- Body contains the command prompt with $ARGUMENTS support

**MCP Servers** provide connections to external tools and data sources, configured in plugin.json

## Available Plugins

### git-workflows Plugin

The primary plugin in this collection. Provides comprehensive git and GitHub automation.

**Key Components:**
- **git-ops subagent**: Orchestrates git operations by interpreting user intent and invoking deterministic workflows
- **Slash command workflows**:
  - `/commit` - Atomic commit with code review
  - `/branch` - Feature branch creation
  - `/rebase` - Rebase with conflict handling
  - `/sync` - Branch sync with remote
  - `/pr` - Pull request creation
  - `/git-workflow` - End-to-end workflow (review + test + commit + PR)

**MCP Servers Used:**
- `git` (mcp-server-git): Git operations via MCP
- `github` (GitHub Copilot API): GitHub operations via MCP
- `sequential-thinking`: Structured reasoning for complex decisions

**Architecture Philosophy:**
- **MCP-first**: Uses MCP tools for all git/GitHub operations to enable fine-grained IAM control
- **Workflow-based**: Deterministic, phase-based procedures with validation gates
- **95%+ confidence**: Uses sequential-thinking tool to achieve high confidence in decisions
- **Transparent**: Explains why defaults are overridden, why bash is used when MCP unavailable

## Workflow Patterns

### Phase-Based Execution

All workflows follow strict phase-based execution with JSON state tracking:

1. Pre-flight checks and validation
2. Data gathering (status, diffs, logs)
3. Analysis and decision-making (using sequential-thinking when needed)
4. User approval for critical operations
5. Execution using MCP tools
6. Verification and reporting

Each phase outputs structured JSON state that passes to the next phase.

### Validation Gates

Workflows have mandatory STOP conditions:
- On mainline branch without approval
- Critical issues in code review
- Test failures
- MCP tool unavailable for required operation
- User rejection

When STOP triggered: halt immediately, explain why, propose solution, wait for user decision.

## Working with This Repository

### Adding New Plugins

1. Create directory under `plugins/<plugin-name>/`
2. Add `plugin.json` with metadata
3. Create subagents in `agents/` (markdown with YAML frontmatter)
4. Create slash commands in `commands/` (markdown files)
5. Configure MCP servers in plugin.json if needed
6. Update marketplace.json to register the plugin

### Testing Plugins

Plugins are loaded from the local filesystem during development:
```bash
/plugin install ./plugins/<plugin-name>
```

### Validating Plugin Configuration

Validate plugin configuration files before installing or publishing:
```bash
claude plugin validate /path/to/repository
```

This command checks:
- Plugin metadata and structure
- Agent definitions and frontmatter
- Slash command syntax
- MCP server configurations
- Marketplace registration

Run validation from the repository root directory to check all plugins at once.

### Plugin Versioning

Follow semantic versioning in plugin.json.
