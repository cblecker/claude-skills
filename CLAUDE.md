# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal collection of Claude Code plugins that extend Claude Code's capabilities through custom subagents, slash commands, hooks, and MCP servers. The repository serves as a plugin marketplace that can be added to Claude Code via `/plugin marketplace add cblecker/claude-plugins`.

## Repository Structure

```
plugins/
└── <plugin-name>/
    ├── plugin.json          # Plugin metadata and configuration
    ├── skills/              # Skill definitions (directories with SKILL.md)
    │   └── <skill-name>/
    │       ├── SKILL.md     # Main skill instructions (required)
    │       ├── reference.md # Additional context (optional)
    │       └── scripts/     # Utility scripts (optional)
    ├── agents/              # Subagent definitions (markdown with YAML frontmatter)
    ├── commands/            # Slash command definitions (markdown files)
    ├── hooks/               # Hook configurations
    └── mcp/                 # MCP server configurations
```

### Plugin Components

**Skills** are directories containing SKILL.md files with YAML frontmatter:
- Directory structure: `skills/<skill-name>/SKILL.md`
- Required frontmatter: name, description
- Optional frontmatter: allowed-tools (restricts tool access)
- Body contains the skill instructions and workflow phases
- Invoked automatically by Claude based on task context
- Can include additional reference files, scripts, and templates

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
- **Skills**: Main context invokes these directly based on user intent
  - `creating-commit` - Atomic commit with code review, analysis, and validation
  - `syncing-branch` - Branch sync with remote (fork vs origin aware)
  - `creating-pull-request` - Pull request creation (can invoke creating-commit if needed)
  - `creating-branch` - Feature branch creation (invokes syncing-branch for mainline sync)
  - `rebasing-branch` - Rebase workflow with conflict handling (invokes syncing-branch for base sync)

**MCP Servers Used:**
- `git` (mcp-server-git): Git operations via MCP
- `github` (GitHub Copilot API): GitHub operations via MCP
- `sequential-thinking`: Structured reasoning for complex decisions

**Architecture Philosophy:**
- **MCP-first**: Uses MCP tools for all git/GitHub operations to enable fine-grained IAM control
- **Skills-based**: Main context directly invokes skills based on user intent (no orchestrator agent)
- **Phase-based**: Deterministic workflows with validation gates and structured state tracking
- **Skill composition**: Skills can invoke other skills autonomously (e.g., creating-pull-request → creating-commit)
  - Claude autonomously detects when a skill needs another skill and invokes it
  - No explicit skill references in allowed-tools (removed in v3.0.0)
  - Skill invocation is based on task context and skill descriptions
- **95%+ confidence**: Uses sequential-thinking tool to achieve high confidence in decisions
- **Prescriptive**: Exact tool specifications per step ("Use mcp__git__git_status" not "use MCP tools")
- **Plan mode aware**: Skills automatically limited to read-only operations in plan mode

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
3. Create skills in `skills/<skill-name>/SKILL.md` (subdirectory containing SKILL.md with YAML frontmatter)
4. Create subagents in `agents/` (markdown with YAML frontmatter) - optional
5. Create slash commands in `commands/` (markdown files) - optional
6. Configure MCP servers in plugin.json if needed
7. Update marketplace.json to register the plugin

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
- Skill definitions and frontmatter
- Agent definitions and frontmatter
- Slash command syntax
- MCP server configurations
- Marketplace registration

Run validation from the repository root directory to check all plugins at once.

### Plugin Versioning

Follow semantic versioning in plugin.json.
