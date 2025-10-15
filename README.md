# Claude Code Plugins

A personal collection of Claude Code plugins, providing custom subagents, slash commands, hooks, and MCP servers to enhance my development workflow.

## What are Claude Code Plugins?

Claude Code plugins are custom collections that can include:

- **Subagents**: Specialized AI agents for specific development tasks
- **Slash Commands**: Custom shortcuts for common operations
- **MCP Servers**: Tool and data source connections
- **Hooks**: Workflow customization points

Plugins help standardize my development environment, enforce best practices, and improve productivity.

## Getting Started

### Add this Plugin Collection

To add this plugin collection to Claude Code:

```bash
/plugin marketplace add cblecker/claude-plugins
```

### Install Plugins

Once the marketplace is added, you can browse and install available plugins:

```bash
/plugin install <plugin-name>
```

### Manage Plugins

Toggle plugins on/off to manage system complexity:

```bash
/plugin list
/plugin enable <plugin-name>
/plugin disable <plugin-name>
```

## Plugin Structure

Each plugin in this marketplace is organized in the `plugins/` directory with the following structure:

```
plugins/
└── <plugin-name>/
    ├── plugin.json          # Plugin metadata and configuration
    ├── agents/              # Subagent definitions (markdown with YAML frontmatter)
    ├── commands/            # Slash command definitions (markdown files)
    ├── hooks/               # Hook configurations
    └── mcp/                 # MCP server configurations
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Plugins Announcement](https://www.anthropic.com/news/claude-code-plugins)
- [Subagents Guide](https://docs.claude.com/en/docs/claude-code/sub-agents.md)
- [Slash Commands Guide](https://docs.claude.com/en/docs/claude-code/slash-commands.md)
- [Hooks Guide](https://docs.claude.com/en/docs/claude-code/hooks-guide.md)
