# GitHub Workflows

This folder is reserved for GitHub Actions workflows.

Active workflow:

- `ci.yml` runs on every pull request, on pushes to `main`, and on manual dispatch. It runs the Pester tests, installs WiX 6, builds the unsigned MSI and Portable EXE with `packaging\Build-Packages.ps1`, and smoke-tests the Portable EXE with no console attached. The built packages, the regenerated `public-release/` folder and `TestResults.xml` are uploaded as a workflow artifact for VM testing.

Planned V2 workflow:

- release.yml

Expected responsibilities:

- Run syntax checks.
- Build MSI and Portable EXE.
- Validate MSI metadata.
- Generate hashes.
- Generate update-manifest.json.
- Package public release artifacts.
- Upload release artifacts to GitHub Releases.

The release workflow should call the existing packaging script instead of replacing it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Packages.ps1
```
