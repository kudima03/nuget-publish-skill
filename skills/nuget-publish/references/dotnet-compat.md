# .NET Package Validation & Compatibility Suppressions

## How package validation works

Projects opt in with:
```xml
<EnablePackageValidation>true</EnablePackageValidation>
<PackageValidationBaselineVersion>X.Y.Z</PackageValidationBaselineVersion>
```

When `dotnet pack` runs, it downloads the baseline NuGet package and compares the new package's public API against it. Any removed or changed member is a compatibility error and fails the build.

## Error codes

Common violation codes in error output:

| Code | Meaning |
|---|---|
| `CP0001` | Interface member removed |
| `CP0002` | Member type changed |
| `CP0003` | Abstract member added to interface |
| `CP0006` | Generic constraint changed |
| `PKV0004` | Assembly removed |

Errors look like:
```
error CP0001: Member 'MyLibrary.IFoo.Bar' was removed from the public API
```

## Generating suppressions

```bash
dotnet pack <CSPROJ_PATH> --configuration Release \
  -p:PackageVersion=<VERSION> \
  -p:GenerateCompatibilitySuppressionFile=true \
  --output /tmp/nuget-pack-suppress
```

This writes (or overwrites) `CompatibilitySuppressions.xml` next to the csproj.

## Reading CompatibilitySuppressions.xml

The file looks like:
```xml
<?xml version="1.0" encoding="utf-8"?>
<Suppressions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Suppression>
    <DiagnosticId>CP0001</DiagnosticId>
    <Target>M:MyLibrary.IFoo.Bar</Target>
    <Left>lib/net8.0/MyLibrary.dll</Left>
    <Right>lib/net8.0/MyLibrary.dll</Right>
    <IsBaselineSuppression>true</IsBaselineSuppression>
  </Suppression>
</Suppressions>
```

To produce a human-readable summary for the PR body:
1. For each `<Suppression>`, read `DiagnosticId` and `Target`
2. Map `DiagnosticId` to the table above
3. Parse the `Target` to extract the member name (strip the method/field/type prefix: `M:`, `P:`, `T:`, `F:`)
4. Group by `DiagnosticId`

Example PR bullet list:
```
- **CP0001** — `IFoo.Bar` removed from public API (net8.0, net9.0)
- **CP0003** — Abstract member `IBaz.Qux` added to interface (net8.0)
```

## Updating the baseline after publish

After a tag is pushed and the GitHub Actions publish completes, update `PackageValidationBaselineVersion` in the csproj to the new version:

```xml
<PackageValidationBaselineVersion>NEW_VERSION</PackageValidationBaselineVersion>
```

The baseline update PR must go through CI. Only merge after CI passes.

## Important: suppression file must be on main before the tag

Because the tag build downloads the code at that commit, the `CompatibilitySuppressions.xml` file must already be merged to main before the tag is pushed. Pushing the tag before the suppressions are merged will cause the CI tag build to fail.
