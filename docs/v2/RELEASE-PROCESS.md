# V2 Release Process

How an official PcNinja WinUpdate Tool V2 release is built, tested and published.

## Pipeline overview

| Workflow | Trigger | What it does |
|---|---|---|
| `.github/workflows/ci.yml` | Every pull request, every push to `main`, manual run, and called by `release.yml` | Pester tests (Pester 4.10.1), WiX 6 install, `packaging\Build-Packages.ps1`, no-console Portable smoke test, upload of the built packages as an artifact |
| `.github/workflows/release.yml` | Manual run from `main` only | Preflight checks, then the CI workflow, then publishes **the exact artifact CI tested** as a GitHub release and pushes the regenerated `public-release/` metadata to a `release/<tag>-metadata` branch |

The packages a user downloads are always the same bytes that passed the tests in the same workflow run. Nothing is rebuilt between testing and publishing.

## Why the order matters

Installed copies check for updates by reading `public-release/update-manifest.json` from the `main` branch (`WinUpdateTool.ps1`, `Get-PcnDefaultAppUpdateManifestUrl`). The manifest holds the download URL and SHA-256 of each package.

- If the manifest reaches `main` **before** the release assets exist, every installed copy is offered an update it cannot download.
- If the manifest hashes do not match the uploaded assets, the in-app updater refuses the download (hash verification added in V2.2.6).

So the release must exist first, and the manifest from the same build is merged after it.

## Releasing a new version

1. **Prepare the version in a pull request.**
   - Bump `version.json`, the defaults in `WinUpdateTool.ps1` and `packaging/Build-Packages.ps1`, and the assembly versions in the four `packaging/*.cs` hosts.
   - Add the release highlights to `Build-Packages.ps1` (the release notes block) and a "New In" section to `README.md`.
   - Update the manifest example in `docs/v2/APP-UPDATE-FLOW.md`.
   - Do **not** edit `public-release/` by hand.
   - CI must be green. Download the CI artifact and run the VM checklist below.
2. **Merge the pull request into `main`.**
3. **Run the Release workflow.** In GitHub, open Actions, then Release, then Run workflow on `main`, and type the public label exactly as in `version.json` (for example `V2.2.8`).
   - Preflight stops the run if it is not on `main`, if the label does not match `version.json`, or if the tag or release already exists.
   - Publish verifies that the manifest's version, hashes and URLs match the artifact before creating anything.
4. **Merge the metadata branch.** The run summary links the new release and the `release/<tag>-metadata` branch. Open a pull request from that branch into `main` and merge it. From this moment installed copies are offered the update.
5. **Check the release page.** It should hold 9 assets: the MSI, the Portable EXE, `update-manifest.json`, `SHA256SUMS.txt`, `PUBLIC-RELEASE-README.txt`, `SIGNING-INSTRUCTIONS.txt`, the release notes, and the public release zip with its `.sha256.txt`.

## VM checklist before step 2

- Portable EXE: a double-click and UAC approval open the UI.
- MSI: install, then open the UI from the Start menu shortcut.
- MSI upgrade over the previous version keeps settings and the scheduled task.
- Available Updates shows Hebrew and other non-ASCII titles correctly.
- CLI: `PcNinja.WinUpdateTool.Cli.exe -Mode Status -Json` returns valid JSON.

## Signing

Releases are currently unsigned (`signing.required: false` in the manifest), matching V2.2.7 and earlier. `Build-Packages.ps1` signs only when `-CertificateThumbprint` or `-PfxPath` is passed. To sign in CI later, store the PFX and its password as repository secrets and pass them to the build step. Never commit certificates.

## If something goes wrong

- **Release created, metadata not merged yet.** Users are unaffected. Fix the problem, delete the release and its tag, and run the workflow again.
- **Metadata merged and the release is bad.** Revert the metadata commit on `main` so the manifest points back to the previous release. Installed copies stop being offered the bad version; copies that already updated need the next fixed release.
- **A rerun says the tag already exists.** A previous run got as far as creating the release. Check whether it is complete before deleting anything.

## Related documents

- [APP-UPDATE-FLOW.md](APP-UPDATE-FLOW.md) – how the in-app updater consumes the manifest.
- [incidents/2026-11-05-v2.2.7-startup-failure.md](incidents/2026-11-05-v2.2.7-startup-failure.md) – the incident that led to this pipeline.
