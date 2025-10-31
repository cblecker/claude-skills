# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal collection of Claude Code skills that extend Claude Code's capabilities through custom skill definitions. Skills are autonomous, contextually-invoked workflows that help Claude perform complex tasks. The repository serves as a skills collection that can be added to Claude Code via `/plugin marketplace add cblecker/claude-skills`.

## Skills Overview

Skills are specialized capabilities that Claude automatically invokes based on task context. Each skill defines:
- **Name and description**: How Claude identifies when to use the skill
- **Instructions**: Step-by-step workflow with phases and validation gates
- **Tool restrictions**: Optional allowed-tools list to limit tool access
- **Supporting files**: Reference documentation, scripts, templates

Skills are invoked automatically by Claude when user requests match the skill's description. No explicit invocation is needed.

## Repository Structure

```
<plugin-name>/
├── plugin.json              # Plugin metadata and configuration
└── <skill-name>/
    ├── SKILL.md             # Main skill instructions (required)
    ├── reference.md         # Additional context (optional)
    └── scripts/             # Utility scripts (optional)
```

### Skill Format

Skills are directories containing a SKILL.md file with YAML frontmatter:
- **Required frontmatter**: `name`, `description`
- **Optional frontmatter**: `allowed-tools` (restricts tool access)
- **Body**: Skill instructions including workflow phases, validation gates, and examples
- **Supporting files**: Additional markdown files, scripts, templates in the skill directory

Example structure:
```markdown
---
name: example-skill
description: Brief description of when to invoke this skill
  # Description Best Practices (see designer agent for details):
  # - Use collaborative framing: "Automates [workflow]..." (not "MUST use for...")
  # - Integrate system terminology (protocols, safety features)
  # - Target 45-52 words (scannable yet detailed)
  # - Lead with value proposition, include technical specificity and safety features
allowed-tools:
  - tool_name_1
  - tool_name_2
---

# Skill Instructions

[Phase-based workflow with validation gates]
```

### Optional Components

While this repository currently contains only skills, plugins can optionally include other components:
- **Subagents**: Markdown files with YAML frontmatter defining specialized agents
- **Slash Commands**: User-invokable commands (different from skills - slash commands require explicit `/command` invocation, while skills are automatically invoked by Claude based on context)
- **Hooks**: Configuration for lifecycle event handlers
- **MCP Servers**: Connections to external tools and data sources (configured in plugin.json)

These components may be added in future iterations as needed.

## Available Skills

### git-workflows Plugin

The primary plugin in this collection. Provides comprehensive git and GitHub automation through skills-based workflows.

**Skills:**
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

### Adding New Skills

1. Create plugin directory: `<plugin-name>/`
2. Add `plugin.json` with metadata (name, version, description)
3. Create skill directory: `<plugin-name>/<skill-name>/`
4. Add `SKILL.md` with YAML frontmatter and instructions
5. Add supporting files as needed (reference.md, scripts/, templates/)
6. Configure MCP servers in plugin.json if required
7. Update marketplace.json to register the plugin

### Testing Skills Locally

Skills are loaded from the local filesystem during development:
```bash
/plugin install ./git-workflows
```

This installs the plugin and makes all skills available to Claude.

### Validating Skill Configuration

Validate plugin and skill configuration before installing or publishing:
```bash
claude plugin validate <path>
```

This command checks:
- Plugin metadata and structure
- Skill definitions and frontmatter
- YAML syntax and required fields
- File structure and naming conventions
- MCP server configurations

Run validation on any path that contains a `.claude-plugin` directory:
- Repository root: Validates the marketplace configuration
- Individual plugin directories (e.g., `git-workflows/`): Validates the specific plugin

### Skills Documentation

For comprehensive guidance on creating effective skills, refer to:
- [How to create custom skills](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills) - Tutorial and quick start
- [Agent skills best practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) - Design patterns and recommendations
- [Skills reference](https://docs.claude.com/en/docs/claude-code/plugins-reference#skills) - Technical specification and API reference

### Plugin Versioning

Follow semantic versioning in plugin.json:
- **Major**: Breaking changes to skill interfaces or behavior
- **Minor**: New skills or backward-compatible enhancements
- **Patch**: Bug fixes and documentation updates
