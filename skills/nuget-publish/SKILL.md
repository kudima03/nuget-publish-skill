---
name: nuget-publish
description: Use this skill when the user wants to publish, release, tag, or cut a new version of a NuGet package. Triggers on phrases like "publish nuget", "cut a release", "push a tag", "release new version", "ready to release", "bump version", "prepare release", or any mention of creating a git tag for a .NET library. Also use when the user asks about what version to use next, whether changes are breaking, or how to handle API compatibility suppressions.
---

# NuGet Publish

This skill handles the complete release workflow for NuGet packages that use .NET package validation (`EnablePackageValidation=true` and `PackageValidationBaselineVersion` in the csproj).

## Overview of the workflow

1. Detect context (csproj, baseline version, last tag)
2. Analyze changes since the last tag
3. Suggest a new version and tag format (stable or preview)
4. User confirms the tag
5. Run `dotnet pack` to check API compatibility
6. If breaking changes detected: generate suppressions, open a PR, wait for user approval, merge
7. Push the tag (triggers GitHub Actions publish to NuGet and GitHub Packages)
8. After 5–7 minutes: update `PackageValidationBaselineVersion` in csproj, open a PR, wait for CI, merge

Read `references/versioning.md` for the full versioning rules (tag formats, semver bumping logic, preview vs stable, dep-version propagation).
Read `references/dotnet-compat.md` for how package validation and suppressions work.

---

## Step 1 — Detect context

Run from the repo root:

```bash
# Last published tag (exits non-zero if no tags exist)
git describe --tags --abbrev=0

# Find the solution and csproj (exclude obj/ and test projects)
find . -name "*.sln" -not -path "*/obj/*" | head -1
find . -name "*.csproj" -not -path "*/obj/*"

# Current baseline version (only present if package validation is enabled)
grep -rl "PackageValidationBaselineVersion" --include="*.csproj" .
```

Extract:
- `LAST_TAG` — e.g. `4.3.0` or `1.0.0-preview.0.2.0`. If `git describe` exits non-zero, there are no tags — this is a first release (see below).
- `PACKAGE_NAME` — from `<PackageId>` in csproj (falls back to assembly name)
- `BASELINE_VERSION` — current `PackageValidationBaselineVersion` value (if present — skip Steps 4–5 and 7 if absent)
- `CSPROJ_PATH` — full path to the packable csproj
- `SLN_OR_CSPROJ_DIR` — directory to run `dotnet` commands from (solution dir if a `.sln` exists, otherwise csproj dir)

### First release (no tags yet)

If no tags exist, ask the user:

```
No tags found — this looks like a first release.
Would you like to start with a stable release (suggested: 0.1.0) or a preview release (suggested: 0.1.0-preview.0.1.0)?
```

Use the user's answer as `LAST_TAG = "(none)"` and skip the "changes since last tag" diff in Step 2 (show all commits instead). Proceed normally from Step 3 onward.

Determine the current tag series (stable or preview) from `LAST_TAG`. See `references/versioning.md`.

---

## Step 2 — Analyze changes since last tag

```bash
# All commits
git log ${LAST_TAG}..HEAD --oneline

# All changed files
git diff --name-only ${LAST_TAG}..HEAD

# Files changed inside the packable project directory
CSPROJ_DIR=$(dirname <CSPROJ_PATH>)
git diff --name-only ${LAST_TAG}..HEAD -- "${CSPROJ_DIR}"

# Package reference changes (dependency bumps)
git diff ${LAST_TAG}..HEAD -- "*.csproj"
```

**Early exit — no project changes to release:** If `git diff --name-only ${LAST_TAG}..HEAD -- "${CSPROJ_DIR}"` produces no output, there are no changes inside the packable project — even if other commits or files (CI, docs, repo tooling) changed. Stop immediately and tell the user:

```
No changes found in <CSPROJ_DIR> since <LAST_TAG>.
Nothing to release. Exiting.
```

Do not proceed to Step 3.

Summarize (using only the project-scoped diff):
- What interfaces or members were added, changed, or removed
- Whether any NuGet dependency was bumped, and whether the bump is a **major** (breaking) version bump
- Whether there are only infrastructure/CI/doc changes (patch-only)

Capture the summary as `CHANGES_SUMMARY` — a 3–5 bullet list that you'll reuse in the tag message (Step 6). Show the user this summary along with the suggested tag and ask for confirmation. See `references/versioning.md` for bump rules.

---

## Step 3 — User confirms the tag

Present:
```
Changes since 4.3.0:
• Added IFoo interface
• Bumped SomeDep 1.x → 2.x (breaking)
• Updated CI workflow

Suggested tag: 5.0.0  (major bump due to breaking dep)
Tag type: stable

Confirm? [y/N / enter different tag]
```

Wait for explicit confirmation or a custom tag. If the user provides a different tag, validate it matches the expected format (see `references/versioning.md`).

---

## Step 4 — Check API compatibility

Run from `SLN_OR_CSPROJ_DIR`:

```bash
dotnet restore <SLN_OR_CSPROJ_DIR>
dotnet pack <CSPROJ_PATH> --configuration Release -p:PackageVersion=<CONFIRMED_TAG> --output /tmp/nuget-pack-check
```

**If pack succeeds:** no breaking public API changes. Skip Step 5 and proceed directly to Step 6.

**If pack fails with compat errors:** capture the full error output. Extract the list of violations (they look like `CP0001`, `CP0002`, etc.). Proceed to Step 5.

---

## Step 5 — Handle breaking public API changes

Only needed when `dotnet pack` in Step 4 produced compatibility errors.

### 5a. Generate suppressions

```bash
dotnet pack <CSPROJ_PATH> --configuration Release \
  -p:PackageVersion=<CONFIRMED_TAG> \
  -p:GenerateCompatibilitySuppressionFile=true \
  --output /tmp/nuget-pack-suppress
```

This writes `CompatibilitySuppressions.xml` next to the csproj. Read it and parse the suppressed violations.

### 5b. Open a suppressions PR

```bash
git checkout -b compat-suppressions/<CONFIRMED_TAG>
git add <CSPROJ_DIR>/CompatibilitySuppressions.xml
git commit -m "Add compatibility suppressions for <CONFIRMED_TAG>"
git push -u origin compat-suppressions/<CONFIRMED_TAG>
gh pr create \
  --title "Add compatibility suppressions for <CONFIRMED_TAG>" \
  --body "$(cat <<'EOF'
## Breaking API changes in <CONFIRMED_TAG>

The following public API changes require compatibility suppressions:

<VIOLATIONS_LIST>

These suppressions allow `dotnet pack` to succeed. They do not hide the changes from consumers — they only acknowledge the intentional breaks.

Please review and merge before the tag is pushed.
EOF
)"
```

Replace `<VIOLATIONS_LIST>` with a human-readable bullet list of each violation (name + description). Read `references/dotnet-compat.md` for how to parse the XML into readable form.

### 5c. Notify the user

Show the user:
- The PR URL
- A summary of the breaking changes (what APIs were removed/changed)
- Ask them to review and let you know when to proceed

Wait for explicit "proceed" / "merge it" before continuing.

### 5d. Merge the PR

Wait for CI to pass, then merge:

```bash
gh pr checks <PR_NUMBER> --watch
gh pr merge <PR_NUMBER> --squash --delete-branch
git checkout main
git pull
```

---

## Step 6 — Push the tag

Create an annotated tag that embeds the `CHANGES_SUMMARY` from Step 2 so the changelog is preserved in git history:

```bash
git tag -a <CONFIRMED_TAG> -m "Release <CONFIRMED_TAG>

Changes since <LAST_TAG>:
<CHANGES_SUMMARY>"
git push origin <CONFIRMED_TAG>
```

Replace `<CHANGES_SUMMARY>` with the bullet list captured in Step 2 (each bullet on its own line, prefixed with `•`).

Tell the user: "Tag `<CONFIRMED_TAG>` pushed. CI will now build and publish the package. This typically takes a few minutes."

---

## Step 7 — Update the baseline version

Wait 5–7 minutes for the CI publish to complete, then:

### 7a. Verify the package is live (optional but recommended)

```bash
# Check NuGet.org feed (may take a few extra minutes to index)
curl -s "https://api.nuget.org/v3-flatcontainer/<package-id-lowercase>/index.json" \
  | grep "<CONFIRMED_TAG>"
```

### 7b. Open baseline update PR

Update `PackageValidationBaselineVersion` in the csproj:

```bash
git checkout -b update-baseline/<CONFIRMED_TAG>
# Edit <CSPROJ_PATH> — change PackageValidationBaselineVersion to <CONFIRMED_TAG>
git add <CSPROJ_PATH>
git commit -m "Update package validation baseline to <CONFIRMED_TAG>"
git push -u origin update-baseline/<CONFIRMED_TAG>
gh pr create \
  --title "Update package validation baseline to <CONFIRMED_TAG>" \
  --body "$(cat <<'EOF'
Bump `PackageValidationBaselineVersion` from `<OLD_BASELINE>` to `<CONFIRMED_TAG>` following the successful publish.
EOF
)"
```

### 7c. Wait for CI and merge

```bash
# Poll until CI passes (check every 60s)
gh pr checks <PR_NUMBER> --watch
gh pr merge <PR_NUMBER> --squash --delete-branch
```

After merging, tell the user the full release is complete with a summary:
- Tag pushed: `<CONFIRMED_TAG>`
- Package: `<PACKAGE_NAME>`
- Baseline updated from `<OLD_BASELINE>` → `<CONFIRMED_TAG>`
- NuGet URL (if known)
