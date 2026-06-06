# pure-claude-plugin

Claude Code plugin for Pure ecosystem repos. Provides skills, slash commands, and hooks that work across all repos derived from [Pure.Template](https://github.com/kudima03/Pure.Template).

## Contents

| Type | Name | Description |
|---|---|---|
| Skill | `nuget-publish` | Auto-triggered publish workflow: version analysis, API compat, suppressions, tag, baseline update |
| Command | `/nuget-publish` | Explicitly kick off the publish workflow |
| Command | `/format` | Run `csharpier format . && dotnet format` from `./src` |
| Hook | `Stop` | Auto-format `.cs` files after Claude finishes a session (only when `.cs` files were changed) |

## Install as a git submodule (recommended)

Add to each Pure ecosystem repo and to Pure.Template:

```bash
git submodule add https://github.com/kudima03/pure-claude-plugin .claude/plugins/pure
git submodule update --init
```

Claude Code picks up the plugin automatically when working in the repo.

## Standalone install

```bash
git clone https://github.com/kudima03/pure-claude-plugin
claude plugins install ./pure-claude-plugin
```

## Updating

```bash
# In a repo that uses the submodule:
git submodule update --remote .claude/plugins/pure
git add .claude/plugins/pure
git commit -m "Update pure-claude-plugin"
```

## Per-repo overrides and additions

See [Overriding and extending the plugin](#overriding-and-extending) below.

---

## Overriding and extending

The plugin is the shared baseline. Each repo can add or override behavior at the project level without touching the submodule.

### Add a repo-specific command

Create `.claude/commands/<name>.md` in the repo. It shows up as `/<name>` alongside the plugin commands. This is the standard way to add repo-specific workflows.

```
my-repo/
└── .claude/
    └── commands/
        └── my-custom-command.md   ← only available in this repo
```

### Override plugin behavior (skills)

There is no formal skill override mechanism — both the plugin skill and CLAUDE.md are in context simultaneously. Use `CLAUDE.md` for repo-specific overrides:

```markdown
<!-- CLAUDE.md in the specific repo -->

## Publish notes
When running the nuget-publish skill, always default to preview tags for this repo.
The baseline version for this repo is pinned at 3.x.
```

CLAUDE.md instructions are always in context and Claude gives them priority over generic skill guidance.

### Disable the auto-format hook for a specific repo

Add to the repo's `.claude/settings.json`:

```json
{
  "disabledHooks": ["pure@pure-claude-plugin:Stop"]
}
```

(Exact key depends on Claude Code's hook disable API — check `claude hooks --help`.)

## Prerequisites

- [Claude Code](https://claude.ai/code)
- `gh` (GitHub CLI) authenticated
- `dotnet` SDK
- `csharpier` (`dotnet tool install -g csharpier`)

## License

MIT
