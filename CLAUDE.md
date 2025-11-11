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
  # See "Skill Description Best Practices" section below for detailed guidance
allowed-tools:
  - tool_name_1
  - tool_name_2
---

# Skill Instructions

[Phase-based workflow with validation gates]
```

### Skill Description Best Practices

Skill descriptions are critical for discoverability and invocation. Follow these guidelines to ensure skills are invoked appropriately by Claude.

**Framework Requirements** (non-negotiable):
- **Third-person voice**: No "you", "your", or second-person language
- **Descriptive verb-led sentences**: Start with action verbs describing what the skill does
- **Target 45-52 words**: Scannable yet detailed enough for pattern matching
- **Include trigger phrases**: User request patterns that should invoke the skill

**Authority Spectrum** (choose based on skill role):

1. **Replacive** (80-85% authority) - For primary user-facing workflows competing with system defaults:
   - Pattern: "Primary [operation] workflow replacing manual [commands]..."
   - Example: "Primary commit workflow replacing manual git commands: implements Git Safety Protocol..."
   - Use when: Skill should take precedence over bash/direct tool usage

2. **Integrative** (75-80% authority) - For protocol implementations and standard workflows:
   - Pattern: "Implements [system protocol] for [operation]..." or "Standard implementation of..."
   - Example: "Implements Git Safety Protocol for commits: analyzes changes, enforces protections..."
   - Use when: Skill is the canonical implementation of a system concept

3. **Collaborative** (60-70% authority) - For utility and supporting skills:
   - Pattern: "Automates [workflow]...", "Provides [capability]...", "Enables [feature]..."
   - Example: "Automates fork detection by analyzing git remotes..."
   - Use when: Skill assists with tasks but isn't the primary workflow

**Positioning Signals** (combine with authority patterns above):
- **Primacy indicators**: "Primary", "Standard", "Default" → Establishes as THE workflow (not A workflow)
- **Trigger framing**: "Standard procedure:", "Use when:", "Use for:" → Clear invocation conditions
- **System integration**: Reference system concepts like "Git Safety Protocol", "Conventional Commits"
- **Orchestration**: Mention skill composition: "auto-invokes creating-commit if needed"

**Prohibited Patterns** (violate framework requirements):
- Second-person imperatives: "you MUST invoke", "you should use"
- Command-style language: "ALWAYS invoke for", "NEVER use bash"
- Direct prohibitions: "DO NOT use other tools"

**Role-Based Guidance**:
- **User-facing workflows** (commit, PR, branch creation): Use Replacive + positioning signals
- **Utility skills** (fork detection, branch detection): Use Collaborative framing
- **Supporting skills** (invoked by other skills): Focus on technical accuracy, use Collaborative

**Template Examples**:

*Replacive (user-facing workflow):*
```
Primary [operation] workflow replacing manual [commands]: [implements/orchestrates]
[protocol/system concept] with [key features]. Standard procedure for [operation
category]: '[trigger 1]', '[trigger 2]', '[trigger 3]'.
```

*Integrative (protocol implementation):*
```
Implements [system protocol] for [operation]: [key feature 1], [key feature 2]
([technical detail]), [key feature 3]. Use when [scenario] or saying '[trigger 1]',
'[trigger 2]'.
```

*Collaborative (utility skill):*
```
Automates [specific task]: [how it works], [what it provides]. [When invoked or
use case]. Use when [scenario].
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

**Skill Description Approach:**
- **User-facing workflows** (creating-commit, creating-branch, creating-pull-request, syncing-branch, rebasing-branch): Use **Replacive authority pattern** (80-85%) with "Primary [operation] workflow replacing manual git commands" framing to establish precedence over bash-based workflows
- **Utility skills** (repository-type, detect-conventional-commits, mainline-branch): Use **Collaborative authority pattern** (60-70%) with "Automates [task]" framing, appropriate for skills invoked by other skills rather than users directly
- All descriptions follow framework requirements: third-person voice, 45-52 words, explicit trigger phrases, system protocol integration

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

### Reporting Standards

Skills follow different reporting formats based on their invocation pattern:

**Utility Skills** (invoked by other skills only):
- Return structured JSON output for programmatic consumption
- Include success/failure indicators and all required data
- Examples: mainline-branch, repository-type, detect-conventional-commits

**User-Facing Workflow Skills** (invoked by users):
- Use standardized reporting templates for consistency
- Include success indicator (✓), operation name, key information, and next steps
- Examples: creating-commit, creating-branch, creating-pull-request, syncing-branch, rebasing-branch

Standard template format for user-facing skills:
```markdown
✓ <Operation> Completed Successfully

**Field Name:** value  
**Field Name:** value  
...

[Optional: Important notes or next steps]
```

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

### Evaluating Skill Descriptions

Use the `skill-description-evaluator` skill to assess the effectiveness of skill descriptions:

```
Evaluate the skill description in git-workflows/skills/creating-commit/SKILL.md
```

This skill provides:
- Multi-dimensional analysis (User Request Matching, Authority Level, Semantic Clarity)
- Model-specific invocation likelihood ratings (Sonnet 4.5 and Haiku)
- Comparison against competing system instructions (optional)
- Actionable improvement recommendations with estimated impact
- Before/after examples showing how to strengthen descriptions

The evaluator uses the authority spectrum and best practices defined in this document to generate 0-100 scores across five dimensions, helping optimize skill descriptions for maximum effectiveness.

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
