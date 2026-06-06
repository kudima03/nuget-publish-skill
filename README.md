# nuget-publish-skill

A Claude Code plugin that provides a full NuGet publish workflow as a skill and slash command, plus a code-formatting command and hook.

Works with any .NET project that uses `EnablePackageValidation`. Optimized for the Pure ecosystem, but applicable to any NuGet library.

## Contents

| Type | Name | Description |
|---|---|---|
| Skill | `nuget-publish` | Auto-triggered publish workflow: version analysis, API compat check, suppressions PR, tag push, baseline update |
| Command | `/nuget-publish` | Explicitly kick off the publish workflow |
| Command | `/format` | Run `csharpier format . && dotnet format` |
| Hook | `Stop` | Auto-formats `.cs` files after Claude finishes a session (only when `.cs` files were changed) |

## Per-repo overrides and additions

The plugin is the shared baseline. Each repo can extend or override it without touching the submodule.

### Add a repo-specific command

Create `.claude/commands/<name>.md` in the repo — shows up as `/<name>` alongside plugin commands:

```
my-repo/
└── .claude/
    └── commands/
        └── my-command.md
```

### Override skill behavior

There is no formal skill override mechanism. Use `CLAUDE.md` in the repo — it is always in context and Claude gives it priority over skill guidance:

```markdown
<!-- CLAUDE.md -->
## Publish notes
For this repo, always default to preview tags.
```

### Disable the auto-format hook

Add to the repo's `.claude/settings.json`:

```json
{
  "disabledHooks": ["nuget-publish-skill:Stop"]
}
```

## Prerequisites

- [Claude Code](https://claude.ai/code)
- `gh` (GitHub CLI) authenticated
- `dotnet` SDK
- `csharpier` — `dotnet tool install -g csharpier`

## License

MIT
