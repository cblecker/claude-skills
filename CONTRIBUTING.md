# Contributing to Claude Code Plugins

Thank you for your interest in contributing to this plugin collection! This guide will help you understand the validation requirements and development workflow.

## Development Workflow

1. **Fork and Clone**: Fork this repository and clone it locally
2. **Create a Branch**: Create a feature branch for your changes
3. **Make Changes**: Follow the plugin structure and validation requirements
4. **Test Locally**: Run the validation script before committing
5. **Submit PR**: Open a pull request with a clear description of your changes

## Plugin Structure

Each plugin must follow this directory structure:

```
plugins/
└── <plugin-name>/
    ├── plugin.json          # Plugin metadata and configuration
    ├── agents/              # Subagent definitions (markdown with YAML frontmatter)
    ├── commands/            # Slash command definitions (markdown files)
    ├── hooks/               # Hook configurations (optional)
    └── mcp/                 # MCP server configurations (optional)
```

## Validation Requirements

All pull requests are automatically validated using GitHub Actions. You can run the same validation locally:

```bash
python .github/scripts/validate-plugins.py
```

### What Gets Validated

#### 1. JSON Files

**marketplace.json** (`.claude-plugin/marketplace.json`):
- ✅ Valid JSON syntax
- ✅ Required fields: `name`, `description`, `version`, `plugins`
- ✅ `plugins` must be an array of objects
- ✅ Each plugin must have `name` and `source` fields
- ✅ Plugin source directories must exist

**plugin.json** (`plugins/*/plugin.json`):
- ✅ Valid JSON syntax
- ✅ Required fields: `name`, `displayName`, `description`, `version`
- ✅ `version` must follow semantic versioning (e.g., `1.0.0`)
- ✅ `name` must use kebab-case (e.g., `git-workflows`)
- ✅ Referenced directories (`agents`, `commands`) must exist

#### 2. Agent Files

Agent files are markdown files with YAML frontmatter in `plugins/*/agents/*.md`:

- ✅ Must have YAML frontmatter (between `---` markers)
- ✅ Required fields in frontmatter: `name`, `description`
- ✅ File name must use kebab-case (e.g., `git-ops.md`)

**Example agent file**:
```markdown
---
name: my-agent
description: Agent description. MUST BE USED IMMEDIATELY when...
tools: Bash, Read, Write
---

# My Agent

Agent system prompt and instructions...
```

#### 3. Command Files

Command files are markdown files in `plugins/*/commands/*.md`:

- ✅ YAML frontmatter is optional but recommended
- ✅ File name must use kebab-case (e.g., `commit.md`)

**Example command file**:
```markdown
---
description: Command description
---

# My Command

Command instructions and workflow...
```

## Best Practices

### Naming Conventions

- **Plugin names**: Use kebab-case (e.g., `git-workflows`, `code-review`)
- **Agent files**: Use kebab-case (e.g., `git-ops.md`, `code-analyzer.md`)
- **Command files**: Use kebab-case (e.g., `commit.md`, `create-pr.md`)
- **Versions**: Follow semantic versioning (e.g., `1.0.0`, `2.1.3`)

### Plugin Design

- Keep plugins focused on a single purpose
- Include 2-8 components per plugin
- Provide clear descriptions for all components
- Document MCP server requirements
- Include usage examples in README.md

### Testing

Always test your changes locally before submitting:

```bash
# Validate all plugin configurations
python .github/scripts/validate-plugins.py

# Test installing a plugin locally
# (from Claude Code interface)
/plugin install ./plugins/<plugin-name>
```

## CI/CD

This repository uses GitHub Actions to validate all pull requests. The workflow:

1. Checks out the code
2. Sets up Python 3.11
3. Runs the validation script
4. Reports results in the PR

The CI must pass before a PR can be merged.

## Questions?

If you have questions or need help, please:

1. Review the existing plugins for examples
2. Check the [Claude Code documentation](https://docs.claude.com/en/docs/claude-code)
3. Open an issue for discussion

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
