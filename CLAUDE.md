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

```text
<plugin-name>/
├── plugin.json              # Plugin metadata and configuration
├── scripts/                 # Shared utility scripts
│   ├── gather-commit-context.sh
│   ├── get-mainline-branch.sh
│   └── ...
└── skills/
    └── <skill-name>/
        ├── SKILL.md         # Main skill instructions (required)
        └── reference.md     # Additional context (optional)
```

Skills reference shared scripts using explicit relative paths in SKILL.md:
```markdown
Run `../../scripts/scriptname.sh` [args]
```

### Skill Format

Skills are directories containing a SKILL.md file with YAML frontmatter:
- **Required frontmatter**: `name`, `description`
- **Optional frontmatter**: `allowed-tools` (restricts tool access)
- **Body**: Skill instructions including workflow phases, validation gates, and examples
- **Supporting files**: Additional markdown files, templates

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

**Why These Patterns Are Prohibited:**
- **Scalability**: Multiple skills using imperatives creates conflicting absolutes ("ALWAYS use X" vs. "NEVER use Y")
- **Semantic Discovery**: Skills should be discovered by capability matching, not rigid routing rules
- **Contextual Decision-Making**: Descriptive language allows agents to make informed contextual choices
- **Root Cause**: Imperatives don't address the real issue—competition with system-level instructions embedded in tool descriptions
- **Framework Integrity**: The descriptive approach is based on systematic evaluation and testing

**System-Level Instruction Coordination:**

Skills face asymmetric competition with system prompts:
- **Skill descriptions**: Located in metadata, evaluated when considering which skills to invoke
- **Tool instructions**: Embedded in Bash/tool descriptions, visible on every tool invocation, often using imperative language

This creates a visibility and authority imbalance where tool-embedded workflows compete directly with skills but have structural advantages.

**Strategies to overcome this:**
1. **Explicit competitor naming**: Mention "bash-based workflows" or "manual git commands" in descriptions to create direct displacement
2. **Front-load triggers**: Place user request patterns in the first sentence for maximum visibility
3. **Strong positioning**: Use "Standard workflow for ALL [operations]" and "Canonical implementation" signals
4. **System integration**: Reference system concepts (Git Safety Protocol) to appear as native functionality
5. **Improve scannability**: Use em-dashes and shorter clauses for faster comprehension

**Troubleshooting Non-Invocation:**

When skills aren't being invoked as expected:

1. **Diagnose the competition**: Identify what tool or system instruction might be competing
   - Check Bash tool descriptions for embedded git workflows
   - Look for imperative language ("NEVER", "ALWAYS") in system prompts
   - Verify trigger phrase visibility and positioning

2. **Strengthen within framework** (don't use imperatives):
   - Use skill-description-evaluator to assess current effectiveness
   - Front-load trigger phrases (first 10 words)
   - Explicitly name bash/tool competitors being replaced
   - Add positioning signals ("Standard for ALL", "Canonical")
   - Improve scannability (em-dashes, shorter clauses)

3. **Verify skill installation**: Ensure plugin is properly installed and skills are loaded

4. **Test with explicit requests**: Use trigger phrases from description to verify invocation

**Role-Based Guidance**:
- **User-facing workflows** (commit, PR, branch creation): Use Replacive + positioning signals
- **Utility skills** (fork detection, branch detection): Use Collaborative framing
- **Supporting skills** (invoked by other skills): Focus on technical accuracy, use Collaborative

**Template Examples**:

*Replacive (user-facing workflow):*
```text
Primary [operation] workflow replacing manual [commands]: [implements/orchestrates]
[protocol/system concept] with [key features]. Standard procedure for [operation
category]: '[trigger 1]', '[trigger 2]', '[trigger 3]'.
```

*Integrative (protocol implementation):*
```text
Implements [system protocol] for [operation]: [key feature 1], [key feature 2]
([technical detail]), [key feature 3]. Use when [scenario] or saying '[trigger 1]',
'[trigger 2]'.
```

*Collaborative (utility skill):*
```text
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
- `github` (GitHub Copilot API): GitHub operations via MCP
- `sequential-thinking`: Structured reasoning for complex decisions

**Architecture Philosophy:**
- **Bash for git, MCP for GitHub**: Uses bash commands for local git operations and MCP tools for GitHub API operations
- **Skills-based**: Main context directly invokes skills based on user intent (no orchestrator agent)
- **Phase-based**: Deterministic workflows with validation gates and structured state tracking
- **Skill composition**: Skills can invoke other skills autonomously (e.g., creating-pull-request → creating-commit)
  - Claude autonomously detects when a skill needs another skill and invokes it
  - No explicit skill references in allowed-tools (removed in v3.0.0)
  - Skill invocation is based on task context and skill descriptions
- **95%+ confidence**: Uses sequential-thinking tool to achieve high confidence in decisions
- **Prescriptive**: Exact tool specifications per step (e.g., `git status --porcelain` for status checks)
- **Plan mode aware**: Skills automatically limited to read-only operations in plan mode

**Skill Description Approach:**
- **User-facing workflows** (creating-commit, creating-branch, creating-pull-request, syncing-branch, rebasing-branch): Use **Replacive authority pattern** (80-85%) with "Primary [operation] workflow replacing manual git commands" framing to establish precedence over bash-based workflows
- **Utility functions** are implemented as bash scripts (not skills) for efficiency: `get-mainline-branch.sh`, `get-repository-type.sh`, `detect-conventions.sh`
- All skill descriptions follow framework requirements: third-person voice, 45-52 words, explicit trigger phrases, system protocol integration

## Workflow Patterns

### Phase-Based Execution

All workflows follow strict phase-based execution with JSON state tracking:

1. Pre-flight checks and validation
2. Data gathering (status, diffs, logs)
3. Analysis and decision-making (using sequential-thinking when needed)
4. User approval for critical operations
5. Execution (bash for git, MCP for GitHub)
6. Verification and reporting

Each phase outputs structured JSON state that passes to the next phase.

### Validation Gates

Workflows have mandatory STOP conditions:
- On mainline branch without approval
- Critical issues in code review
- Test failures
- Tool or command failure
- User rejection

When STOP triggered: halt immediately, explain why, propose solution, wait for user decision.

### Reporting Standards

Skills follow different reporting formats based on their invocation pattern:

**Utility Scripts** (invoked by skills):
- Return structured JSON output for programmatic consumption
- Include success/failure indicators and all required data
- Examples: `get-mainline-branch.sh`, `get-repository-type.sh`, `detect-conventions.sh`

**User-Facing Workflow Skills** (invoked by users):
- Use standardized reporting templates for consistency
- Include success indicator (✓), operation name, key information, and next steps
- Examples: creating-commit, creating-branch, creating-pull-request, syncing-branch, rebasing-branch

Standard template format for user-facing skills:
```markdown
✓ <Operation> Completed Successfully

**Field Name:** value \
**Field Name:** value \
**Field Name:** value

[Optional: Important notes or next steps]
```

Note: Use backslash (`\`) preceded by a space at the end of lines to create hard line breaks in CommonMark without extra vertical spacing. The space prevents the backslash from being included when copying values (especially important for URLs). This ensures consistent rendering across different markdown viewers.

## Working with This Repository

### Adding New Skills

1. Create plugin directory: `<plugin-name>/`
2. Add `plugin.json` with metadata (name, version, description)
3. Create skill directory: `<plugin-name>/<skill-name>/`
4. Add `SKILL.md` with YAML frontmatter and instructions
5. Add supporting files as needed (reference.md, templates/)
6. If scripts needed, add to `<plugin-name>/scripts/` (shared) or skill directory (standalone)
7. Configure MCP servers in plugin.json if required
8. Update marketplace.json to register the plugin

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

```text
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

### Markdown Style Guidelines

All markdown files must comply with standard linting rules:

- **MD040 - Fenced code blocks require language identifiers**: Every fenced code block must specify a language. Use appropriate identifiers:
  - `bash` - Shell commands and scripts
  - `json` - JSON data structures
  - `yaml` - YAML configuration
  - `markdown` - Markdown examples
  - `text` - Plain text, user prompts, or generic content
