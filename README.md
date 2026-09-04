# nuget-publish-skill

A Claude Code plugin that provides a full NuGet publish workflow as a skill and slash command.

Works with any .NET project that uses `EnablePackageValidation`.

## Contents

| Type | Name | Description |
|---|---|---|
| Skill | `nuget-publish` | Auto-triggered publish workflow: version analysis, API compat check, suppressions PR, tag push, baseline update, changelog generation |
| Command | `/nuget-publish` | Explicitly kick off the publish workflow |

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

## Prerequisites

- [Claude Code](https://claude.ai/code)
- `gh` (GitHub CLI) authenticated
- `dotnet` SDK
- [`changelog-generator-skill`](https://github.com/kudima03/changelog-generator-skill) installed, if the repo has a changelog file (`CHANGELOG.md`/`.rst`) you want kept up to date on release

## License

MIT
