# Plugin Validator

This Go tool validates Claude Code plugin configurations for syntax errors and structural correctness.

## What it validates

- **marketplace.json**: Validates the marketplace configuration file
  - Required fields: name, owner.name, owner.email, version, plugins array
  - Plugin entries must have name and source fields
  
- **plugin.json**: Validates individual plugin configurations
  - Required fields: name, description, version, author.name, author.email
  - Optional fields: displayName, license, repository, homepage, keywords, agents, commands, mcpServers

- **Agent and Command markdown files**: Validates YAML frontmatter
  - Agents must have YAML frontmatter with proper delimiters (---)
  - Commands can optionally have YAML frontmatter

## Usage

```bash
go run main.go <path-to-repository-root>
```

Example:
```bash
go run main.go ../..
```

## Exit codes

- `0`: All validations passed
- `1`: Validation errors found

## CI Integration

This tool is used in the GitHub Actions workflow to validate all plugin configurations on every pull request.
