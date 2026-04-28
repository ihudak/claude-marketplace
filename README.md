# Claude Marketplace

Ivan Gudak's private Claude Code plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| [dev-workflows](plugins/dev-workflows/) | `/impl`, `/vuln`, `/upgrade` commands with Opus-backed planning, code review, and security-remediation workflows |
| [engineering-practices](plugins/engineering-practices/) | Skills for TDD, architecture improvement, disciplined debugging, and design grilling |
| [productivity](plugins/productivity/) | Caveman compressed-communication mode and write-a-skill for authoring new skills |
| [planning](plugins/planning/) | Discovery interviews and pre-mortem risk analysis for pre-implementation planning |

## Installation

### 1. Add this marketplace to Claude Code (once)

```
/add-marketplace ihudak/claude-marketplace
```

### 2. Install a plugin

```
/install dev-workflows
```

## Adding new plugins

1. Create a subdirectory under `plugins/` with the plugin name.
2. Add `.claude-plugin/plugin.json` (name, description, author).
3. Add `commands/`, `agents/`, `hooks/`, and/or `skills/` as needed.
4. For hooks, add a `hooks/hooks.json` declaring the registrations.
5. Register the plugin in `.claude-plugin/marketplace.json`.
6. Commit and push to `main`.

## License

MIT — see [LICENSE](LICENSE).
