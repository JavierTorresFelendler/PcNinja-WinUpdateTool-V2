# GitHub Workflows

GitHub Actions workflows for the V2 line.

Active workflows:

- `ci.yml` runs on every pull request, on pushes to `main`, and on manual dispatch. It runs the Pester tests, installs WiX 6, builds the unsigned MSI and Portable EXE with `packaging\Build-Packages.ps1`, and smoke-tests the Portable EXE with no console attached. The built packages, the regenerated `public-release/` folder and `TestResults.xml` are uploaded as a workflow artifact for VM testing.

- `release.yml` is run manually from `main` and publishes an official release. It checks the version and tag, calls `ci.yml`, creates the GitHub release from the exact artifact CI tested, and pushes the regenerated `public-release/` metadata to a `release/<tag>-metadata` branch to merge afterwards. See [docs/v2/RELEASE-PROCESS.md](../../docs/v2/RELEASE-PROCESS.md).

Signing is not automated yet. `Build-Packages.ps1` signs only when a certificate is passed explicitly, and releases are currently unsigned, as before.
