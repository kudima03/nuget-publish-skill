---
description: "Auto-fix all code style issues in this repo using csharpier and dotnet format. Run from the ./src directory."
allowed-tools: ["Bash(cd *src* && csharpier format*)", "Bash(cd *src* && dotnet format*)"]
---

# Format

Run from the repo root:

```bash
cd ./src && csharpier format . && dotnet format
```

Report which files were changed, if any. If both commands exit cleanly with no changes, say so.
