# Claude Code Skills Collection

My personal collection of Claude Code skills that extend Claude's capabilities through model-invoked workflows.

## What are Claude Code Skills?

Skills are intelligent workflows that Claude can invoke autonomously based on task context. When you ask Claude to perform a task, it analyzes your request and automatically selects the appropriate skill to handle it.

Skills enable:

- **Autonomous workflow selection**: Claude determines which skill to use based on your request
- **Phase-based execution**: Structured workflows with validation gates and state tracking
- **Tool composition**: Skills can invoke other skills to complete complex tasks
- **95%+ confidence decisions**: Structured reasoning for critical operations
- **Best practice enforcement**: Codified expertise in git, GitHub, and development workflows

## Getting Started

### Add this Skills Collection

To add this skills collection to Claude Code:

```bash
/plugin marketplace add cblecker/claude-skills
```

### Install Skills

Once the marketplace is added, you can browse and install available skill collections:

```bash
/plugin install <plugin-name>
```

For example, to install the git-workflows skills:

```bash
/plugin install git-workflows
```

## Resources

### Claude Code Skills Documentation

- [How to Create Custom Skills](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)
- [Agent Skills Best Practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices)
- [Skills Reference](https://docs.claude.com/en/docs/claude-code/plugins-reference#skills)
- [Official Skills Repository](https://github.com/anthropics/skills)

### Claude Code Documentation

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Plugins Announcement](https://www.anthropic.com/news/claude-code-plugins)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
