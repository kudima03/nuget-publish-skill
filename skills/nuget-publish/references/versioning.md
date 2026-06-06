# Versioning Rules

## Tag formats

### Stable
Standard semver: `MAJOR.MINOR.PATCH`

Examples: `1.0.0`, `4.3.0`, `5.0.1`

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
| Non-breaking dep update (dep minor/patch bump) | **MINOR** |
| Bug fix, CI, docs, tooling only | **PATCH** |

Use the **highest** applicable bump category across all changes.

### For preview tags

- Incrementing the **preview iteration** part follows the same rules applied to the preview suffix:
  - Breaking change in preview delta → bump `PREV_MAJOR`
  - New addition in preview delta → bump `PREV_MINOR`
  - Fix in preview delta → bump `PREV_PATCH`
- The **stable prefix** does not change until the stable release is cut.

### Dependency version propagation

If a NuGet dependency in the csproj was bumped:
- **Major dep bump (x.0.0 → x+1.0.0)** → treat as a breaking change; bump this package's MAJOR (or PREV_MAJOR for preview)
- **Minor/patch dep bump** → treat as a non-breaking feature update; bump MINOR (or PREV_MINOR for preview)

Look for `<PackageReference>` changes in the csproj diff to detect dep bumps.

---

## Tag validation

Before confirming, validate the user-supplied or suggested tag:
- Matches `^\d+\.\d+\.\d+$` for stable
- Matches `^\d+\.\d+\.\d+-preview\.\d+\.\d+\.\d+$` for preview
- Is strictly greater than the last tag (semver ordering; for preview, the stable prefix must be ≥ last stable, and the preview suffix must be strictly greater)
- Is consistent with the detected change type (e.g., warn if suggesting a PATCH when breaking API changes were detected)
