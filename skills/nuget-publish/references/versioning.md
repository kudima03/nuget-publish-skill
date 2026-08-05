# Versioning Rules

## Tag formats

### Stable
Standard semver: `MAJOR.MINOR.PATCH`

For a first release, default to `0.1.0` unless the user specifies otherwise.

Examples: `0.1.0`, `1.0.0`, `4.3.0`, `5.0.1`

### Pre-release (default convention)

Format: `STABLE_MAJOR.STABLE_MINOR.STABLE_PATCH-preview.PREV_MAJOR.PREV_MINOR.PREV_PATCH`

The **first part** is the upcoming stable version this pre-release precedes.
The **second part** (after `-preview.`) is the pre-release iteration, also semver.

Examples:
- `0.1.0-preview.0.1.0` — first preview for upcoming `0.1.0`
- `0.1.0-preview.0.1.1` — patch fix in preview iteration
- `0.1.0-preview.0.2.0` — new additions, stable target unchanged
- `1.0.0-preview.0.3.0` — preview for upcoming `1.0.0`

### Alternative pre-release styles (on demand)

Only switch from the default if the user explicitly asks or if the project already uses a different convention:

| Style | Example |
|---|---|
| Simple suffix | `1.0.0-beta`, `1.0.0-rc.1` |
| Dated | `1.0.0-preview-20260101` |
| Alpha/beta/rc progression | `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.1` |

Detect an existing convention from previous tags before suggesting a different one.

---

## Detecting the current series

Look at the last tag:
- No `-preview.` suffix → currently on stable series
- Has `-preview.` suffix → currently on preview series

The user may want to switch series (e.g., cut a stable release from a preview series). Ask if unclear.

---

## Semver bump rules

### For stable tags

| Change type | Version bump |
|---|---|
| Removed/changed public API member | **MAJOR** |
| Breaking NuGet dependency update (dep major bump) | **MAJOR** |
| New public type or member added | **MINOR** |
| Non-breaking dep update (dep minor bump) | **MINOR** |
| Non-breaking dep update (dep patch bump) | **PATCH** |
| Bug fix, CI, docs, tooling only | **PATCH** |

Evaluate **every** change and take the **highest** applicable bump as `MIN_REQUIRED_BUMP`. This is the floor — no tag below it is valid.

### For preview tags

- Incrementing the **preview iteration** part follows the same rules applied to the preview suffix:
  - Breaking change in preview delta → bump `PREV_MAJOR`
  - New addition in preview delta → bump `PREV_MINOR`
  - Fix in preview delta → bump `PREV_PATCH`
- The **stable prefix** does not change until the stable release is cut.

### Dependency version propagation

If a NuGet dependency in the csproj was bumped:
- **Major dep bump (x.0.0 → x+1.0.0)** → treat as a breaking change; this **forces** `MIN_REQUIRED_BUMP = MAJOR` (or `PREV_MAJOR` for preview), regardless of any other changes
- **Minor dep bump** → treat as a non-breaking feature update; raises floor to at least MINOR (or `PREV_MINOR` for preview) unless a higher-priority change already sets MAJOR
- **Patch dep bump** → treat as a non-breaking fix update; raises floor to at least PATCH (or `PREV_PATCH` for preview) unless a higher-priority change already sets MINOR or MAJOR

Look for `<PackageReference>` changes in the csproj diff to detect dep bumps. Parse the old and new version strings to classify the bump:
- Old major ≠ new major → **major dep bump**
- Old major = new major, old minor ≠ new minor → **minor dep bump**
- Only patch changed → **patch dep bump**

---

## Tag validation

Before confirming, validate the user-supplied or suggested tag:
- Matches `^\d+\.\d+\.\d+$` for stable
- Matches `^\d+\.\d+\.\d+-preview\.\d+\.\d+\.\d+$` for preview
- Is strictly greater than the last tag (semver ordering; for preview, the stable prefix must be ≥ last stable, and the preview suffix must be strictly greater)
- **Hard-rejects any tag whose bump level is below `MIN_REQUIRED_BUMP`** — do not accept or proceed with an undersized tag

When the user supplies a custom tag that is below `MIN_REQUIRED_BUMP`, refuse it and explain why:

```
✗ Tag <USER_TAG> is a <ACTUAL_BUMP> bump, but changes require at least a <MIN_REQUIRED_BUMP> bump
  because: <REASON> (e.g. "SomeDep was bumped 1.x → 2.x (major dep bump)").
  Please provide a tag with a <MIN_REQUIRED_BUMP> bump or higher.
```

Never silently accept an undersized tag. Never downgrade `MIN_REQUIRED_BUMP` based on user preference — the floor is non-negotiable.
