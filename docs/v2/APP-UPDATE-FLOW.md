# PcNinja Tool Update Flow

This document describes the application update flow for PcNinja WinUpdate Tool itself. This is separate from installing Windows updates.

## Principle

Customer machines should not run `git pull` and should not execute raw files from the source repository.

The app should update from signed release artifacts produced by the release pipeline.

## V2.0 Flow

1. App checks a published HTTPS `update-manifest.json`.
2. App compares current version with the latest stable version.
3. App shows whether a verified release is available.
4. User clicks `Update`.
5. App downloads the MSI or Portable EXE.
6. App verifies SHA256.
7. App verifies Authenticode signature when signing is available.
8. App launches the verified MSI.
9. MSI closes the running PcNinja tool process safely before replacing files.
10. MSI continues installation/upgrade.
11. App logs the update handoff result before it exits.

## V2.0 Installed-App Update Behavior

For installed MSI deployments, V2.0 should support one-click update handoff:

1. The currently running app downloads the verified MSI to an app-controlled update cache.
2. The app starts `msiexec` with the verified MSI path.
3. The app exits after successfully handing off to the installer.
4. The MSI performs a product-only shutdown step before replacing files.

Recommended cache location:

```text
%ProgramData%\PcNinja\WinUpdateTool\Updates
```

The normal user Downloads folder is convenient, but `%ProgramData%` is safer for elevated MSI handoff, RMM usage, cleanup, and avoiding OneDrive/user-profile path issues.

## Installer Close Strategy

The installer should not blindly kill unrelated processes.

Recommended order:

1. Ask the running GUI to close gracefully if the current version supports it.
2. Wait a short timeout.
3. If still running, close only known PcNinja WinUpdate Tool processes:
   - `PcNinja.WinUpdateTool.exe`
   - `PcNinja.WinUpdateTool.Cli.exe`
4. Avoid closing or interrupting unrelated Windows Update processes.
5. Log the close action.

Process close must run before MSI file replacement.

If the tool is actively running Windows Update installation, V2.0 should either block app self-update or ask for explicit confirmation. The app should not interrupt an active Windows Update operation silently.

## V2.0 Portable Update Behavior

Portable update is different from MSI update.

V2.0 should download and verify the new portable EXE, then guide the user to launch the new portable file. Fully replacing the running portable EXE should be deferred unless tested separately.

## V2.0 CLI Modes

```cmd
PcNinja.WinUpdateTool.Cli.exe -Mode AppUpdateCheck -Json
PcNinja.WinUpdateTool.Cli.exe -Mode AppUpdateDownload -Json
PcNinja.WinUpdateTool.Cli.exe -Mode AppUpdateInstall -Json
```

## V2.1 Candidate Flow

```cmd
PcNinja.WinUpdateTool.Cli.exe -Mode AppUpdateInstall -Silent -Json
```

V2.1 may make this fully silent for RMM/enterprise use after the V2.0 user-initiated update handoff proves stable.

## Manifest Shape

```json
{
  "channel": "stable",
  "publicLabel": "V2.2.6",
  "version": "2.2.6.0",
  "minimumSupportedVersion": "2.2.6.0",
  "releaseNotesUrl": "https://github.com/JavierTorresFelendler/PcNinja-WinUpdateTool-V2/releases/tag/v2.2.6",
  "msi": {
    "fileName": "WinUpdate.Tool.by.PcNinja.msi",
    "url": "https://github.com/JavierTorresFelendler/PcNinja-WinUpdateTool-V2/releases/download/v2.2.6/WinUpdate.Tool.by.PcNinja.msi",
    "sha256": "<sha256>"
  },
  "portable": {
    "fileName": "WinUpdate.Tool.by.PcNinja.exe",
    "url": "https://github.com/JavierTorresFelendler/PcNinja-WinUpdateTool-V2/releases/download/v2.2.6/WinUpdate.Tool.by.PcNinja.exe",
    "sha256": "<sha256>"
  },
  "signing": {
    "required": false,
    "expectedPublisher": "PcNinja"
  }
}
```

## Required Validation

- Manifest URL must use HTTPS.
- Latest version must be newer than current version.
- File names must match expected public naming.
- Downloaded file hash must match SHA256.
- Signature must be valid when signing is enabled.
- Publisher must match expected publisher when a certificate exists.

## UI Behavior

Dashboard should show:

- Current version.
- Latest version.
- Status: up to date, update available, download verified, verification failed, or check failed.
- Release notes link.
- Buttons: `Check Tool Update`, `Download Verified`, `Update Now`.

V2.0 install should be user-initiated. Do not auto-install without the user clicking update or an explicit CLI/RMM command.
