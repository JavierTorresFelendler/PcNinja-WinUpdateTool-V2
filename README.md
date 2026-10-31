# PcNinja WinUpdate Tool V2.2.7

V2.2.7 fixes Unicode decoding across the update scan process so Hebrew and other non-ASCII update titles remain readable in the Available Updates window and application logs. It retains the V2.2.6 app-update validation, verified downloads, and atomic configuration/state writes.

The Windows Update engine, driver audit behavior, interactive MSI wizard, portable packaging, and branded host behavior remain based on the V2 recovery work.

## Version Repositories

- V2 repository: https://github.com/JavierTorresFelendler/PcNinja-WinUpdateTool-V2
- V1 legacy repository: https://github.com/JavierTorresFelendler/PcNinja-WinUpdateTool-V1

Use the V1 repository for the stable V1 download line. Use this repository for V2 stable releases and V2 release candidates.

## New In V2.2.7

- Fixes Hebrew and other non-ASCII update titles displaying as mojibake in the Available Updates window and application logs.
- Sets PowerShell console and pipeline output to UTF-8, captures subprocess stdout/stderr with UTF-8 decoders, and reads captured files as UTF-8.
- Adds regression tests for UTF-8 text with Hebrew, Arabic, Japanese, and accented Latin characters.

## New In V2.2.6

- Validates update package filenames, file extensions, and SHA-256 hashes before downloading.
- Downloads updates to temporary files and replaces existing packages only after hash verification.
- Writes configuration and run-state JSON atomically to protect against interrupted writes.

## New In V2.2.5

- Reduces unsigned Portable false-positive risk by removing the embedded ZIP plus dropped-EXE execution pattern.
- Runs the Portable PowerShell payload in-process and extracts only named scripts, configuration, and visual assets.
- Compiles the Portable entry point as a Windows GUI application so normal launches do not flash a console window.
- Uses a hidden MSI maintenance host instead of visible CMD custom actions during upgrades, configuration, and cleanup.
- Starts background PowerShell checks with `CreateNoWindow` and captured output rather than visible console processes.

## Earlier V2.2.5-RC1 Branding Work

- Replaces the legacy single-frame icon with transparent Windows ICO assets in eight sizes from 16 through 256 px.
- Uses the approved laptop-ninja icon consistently for the installed host, taskbar/window, MSI branding, Start Menu, shortcuts, uninstall entry, and Portable EXE.
- Keeps the application UI free of an embedded header logo so future icon changes do not alter the interface layout.
- Sets a shared Windows AppUserModelID for the host process and Start Menu shortcut so Taskbar branding remains associated correctly.

## New In V2.2.4

- Adds `assets/PcNinja-SoftAlert.wav`, blended from Javier's preferred preview tones.
- Routes V2 dialogs through quiet wrappers so routine informational dialogs are silent.
- Plays the soft PcNinja alert only for important warning, error, and question dialogs.
- Suppresses the default Windows MessageBox icon sound by showing app dialogs with no native MessageBox icon.

## New In V2.2.3

- Fixes portable installs being misdetected as MSI installs during app updates. UAC elevation strips the environment variables set by the portable launcher, so both the branded host and the script now forward the portable source path as a command-line argument across elevation. Portable installs once again download the new portable EXE beside the running file; MSI installs keep the MSI flow.
- Sizes the Drivers `File password` frame to its text instead of a fixed 190px width, so it no longer looks oversized at the minimum window size.

## New In V2.2.2.1 (Stable)

- First official stable release of the V2 line; releases are published from the single `main` branch.
- Keeps a `v2-dev` branch as a read-only compatibility alias of `main` so release-candidate installs (RC18-RC24) continue to receive update prompts at their built-in manifest URL. It is refreshed at each release and is not a development branch.

## New In RC25

- Moves the Logs `Export Bundle` action onto the Application Logs title row, right-aligned above the filter field and always visible.
- Inlines the Retry Policy description with its card title and re-spaces the retry rows with the freed vertical room.
- Removes leftover WinForms anchor settings that fought the responsive layout engine — fixing the stretched log filter box and the `On repeated failure` combo being pushed off the right edge at small window sizes.
- Recomputes the responsive layout every time a tab is opened, so pages opened at a small window size no longer show clipped footers, hidden buttons, or missing scrollbars until a manual resize.
- Reads the tool update manifest from the `main` branch: development now converges on a single stable branch with no separate dev branch.

## New In RC24

- Fixes the V2 window closing seconds after launch. The RC23 WAN IP lookup attached PowerShell script blocks to background process output events; the handlers fired on a thread-pool thread without a PowerShell runspace and terminated the host process. The lookup now uses file-redirected process output, matching the proven pattern used by the scan and update jobs.
- Adds a `PCNINJA_V2_UI_SMOKE_MS` environment override for the UI smoke window (default 1500 ms) so smoke runs can stay open long enough to catch asynchronous startup failures like the RC23 regression.

## New In RC23

- Moves Settings `Clear Schedule` and `Save Schedule` actions to the top header beside Settings and Help.
- Keeps Settings and Logs layouts stable after first paint, maximize, restore, and manual resizing.
- Changes the Help button to open the GitHub V2 user guide.
- Adds logged-on user, LAN/WAN IP, GPU, motherboard, and BIOS summary data to System Status.
- Uses conditional log scrollbars so the log window does not show forced sliders when content does not require them.
- Uses the approved transparent laptop-ninja artwork for the application icon, MSI, Portable EXE, shortcuts, and uninstall metadata; the V2 UI remains unchanged and does not render an in-app logo.

## New In RC22

- Sets a larger V2 minimum window size based on VM layout validation.
- Moves Settings Save/Clear schedule actions into the upper schedule area.
- Fixes the `Windows & Office Activation` label so the ampersand displays correctly.
- Moves the Logs filter field beside `Open Log File`.
- Replaces the small white-backed header icon with a cropped dark-background PcNinja logo.
- Rewrites restart-state details so users see a clear restart/no-restart message instead of raw registry diagnostics.

## New In RC21

- Moves the Schedule helper text below the schedule fields to avoid visual interference with the time selector.
- Renames the Drivers tools panel to `PcNinja Free Tools`.
- Simplifies the Drivers tool links to `Driver Updater`, `Smart Office Installer`, `Windows & Office Activation`, and `Custom PcNinja Images`.
- Reapplies tab layout after form and tab-host resize events so restored windows keep all top tabs visible.
- Keeps MSI/ProductVersion metadata aligned so Windows uninstall views match the RC build.
- Uses invariant English date formatting in the V2 UI even on non-English Windows locales.
- Enables double buffering on the V2 form, panels, and cards to reduce resize/redraw artifacts.
- Keeps long log lines on one line with horizontal scrolling so live-follow does not jump during wrapped lines.
- Automatically checks the GitHub update manifest after the UI opens.
- Shows a version-aware update dialog only when a newer release is available.
- Starts a relaunch watcher for MSI updates so the app closes for installation and opens again after the installer finishes.
- Downloads portable EXE updates beside the current portable file, then closes the old UI and starts the new EXE.
- Removes unwanted Dashboard scrollbars in the normal window size.
- Adds a public support log bundle export button in Logs.
- Updates footer result status after scans and background runs complete.

## Earlier RC18 Startup Work

- Shows the window first, then loads settings, schedule status, restart status, dashboard status, and logs in short deferred steps.
- Adds clear loading text in the footer during startup and delayed tab refreshes.
- Caches short-lived GUI status checks so switching back to Dashboard does not immediately re-query Windows Update, Task Scheduler, and reboot state.
- Keeps explicit Refresh, schedule changes, and finished update runs using fresh status checks.

## Earlier RC17 UI Note

- Shortens the Windows Update snooze dialog buttons to `Snooz to run`, `Retry in 5 min`, and `Cancel`.

## New In RC16

- Shows the `Snooz to run` choice when Windows Update is active, including servicing/install activity.
- Allows a manual run to snooze Windows Update services and continue instead of immediately scheduling a retry.
- Adds `Wake the computer to run this task` to the scheduled task settings.
- Adds CLI and MSI property support for wake-to-run scheduling.
- Changes default first retry delay from `15` minutes to `5` minutes.
- Changes default retry cooldown from `15` minutes to `5` minutes.

## New In RC14

- Changes the product version to `1.0.14.0` so MSI major upgrades can detect and replace older `1.0.13.x` builds.
- Keeps one stable default install path: `C:\Program Files\PcNinja\WinUpdateTool`.
- Keeps normal interactive installs asking for the install folder.
- Keeps silent `/qn` MSI deployment with `PCNINJA_*` properties.
- Removes the MSI JSON deployment example for now.
- Removes `PCNINJA_CONFIG_FILE` from MSI deployment examples.

## New In RC13.12

- Adds real MSI wizard pages instead of only the small basic progress window.
- Adds a license/notice page with PcNinja website references.
- Adds an install-folder page so the user can choose the target path during normal MSI install.
- Adds an install-time schedule/options page for creating the scheduled task during installation.
- Keeps silent `/qn` MSI deployment behavior for BigFix/RMM use.
- Keeps `PCNINJA_*` MSI properties and JSON deployment configuration support.
- Uses a compact internal MSI handoff to avoid long custom-action command lines.

## New In RC13.11

- Adds `-ConfigFile <json path>` support to `Configure` mode.
- Adds MSI post-install configuration through public MSI properties.
- Adds MSI silent deployment support for schedule, retry, reboot prompt, and firmware options.
- Adds `MsiConfigure-WinUpdateTool.ps1` for MSI post-install configuration.
- Adds deployment examples under `dist\deployment-examples`.
- Updates installed and portable CLI help with config-file examples.

## New In RC13.10

- Fixes `Exception setting "ItemSize": The script failed due to call depth overflow`.
- Adds a re-entry guard around full-width tab resizing.
- Avoids resetting tab `ItemSize` when the calculated size is already applied.

## New In RC13.9

- Makes the top tab menu use equal-width tabs across the full available row.
- Centers tab labels inside each tab.
- Keeps the existing centered content layout from RC13.8.
- Keeps the Logs tab full-width for better log readability.

## New In RC13.8

- Centers the Dashboard content groups using the wider Driver Audit style.
- Centers the Updates tab manual run and Windows image download panels.
- Centers the Schedule and Retry Policy panels.
- Adds responsive centering so the main tab content stays aligned when the window is resized.
- Adds a wider, centered Logs view margin.

## New In RC13.7

- Expands the Driver Audit action box to match the full tab layout.
- Restyles the PcNinja links as centered link tiles.
- Centers the `JavierTorres` password inside the selectable read-only text field.
- Arranges manufacturer driver links in three balanced columns.

## New In RC13.6

- Removes the PcNinja password `Copy` button.
- Removes the clipboard API call that could fail when the app host is not running in STA mode.
- Keeps `JavierTorres` in a selectable read-only text field so the user can mark and copy it manually.

## New In RC13.5

- Renames the Updates tab helper from feature-update assistant to `Windows Image Downloads`.
- Changes the helper button to open `https://win11.pcninja.pro/`.
- Replaces the plain PcNinja password label with a selectable read-only text field.

## New In RC13.4

- Splits the Driver Audit links into:
  - `PcNinja Tools`
  - `Manufacturer Driver Sources`
- Adds `PcNinja Office Installer` linking to `https://office.pcninja.pro`.
- Adds `PcNinja Activation` linking to `https://active.pcninja.pro`.
- Keeps `PcNinja Drivers Updater` linking to `https://driver.pcninja.pro`.
- Shows the PcNinja file password in the PcNinja tools section.

## New In RC13.3

- Removes the explanatory text from `Driver Sources & Links`.
- Removes the recommended-flow text from the bottom of the Driver Audit link panel.
- Moves the driver links upward so the section contains only links.

## New In RC13.2

- Adds `PcNinja.WinUpdateTool.Cli.exe` as the official command-line entry point.
- MSI installs both:
  - `PcNinja.WinUpdateTool.exe` for GUI
  - `PcNinja.WinUpdateTool.Cli.exe` for CLI/RMM/PSRemoting
- Portable EXE now always extracts to `%LOCALAPPDATA%\PcNinja\WinUpdateTool\Portable\1.0.13.2`.
- Portable EXE forwards command-line arguments to the embedded CLI host.
- `/?`, `-?`, `--help`, `-help`, and `/help` show command syntax.
- GUI EXE now points users to the CLI EXE if command-line arguments are passed to the GUI host.

## CLI Syntax

Installed MSI:

```cmd
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" /?
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode Status -Json
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode DriverAudit -Json
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode CollectLogs -OutputPath C:\Temp -Json
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode RunUpdates -Silent -RunType Manual -Json
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode ResetWindowsUpdate -ConfirmReset -Json
"C:\Program Files\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode Configure -ConfigFile C:\Temp\pcninja-install.json -Json
```

Portable:

```cmd
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe /?
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode Status -Json
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode DriverAudit -Json
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode CollectLogs -OutputPath C:\Temp -Json
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode RunUpdates -Silent -RunType Manual -Json
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode ResetWindowsUpdate -ConfirmReset -Json
PcNinja-WinUpdateTool-Portable-1.1.2.0.exe -Mode Configure -ConfigFile C:\Temp\pcninja-install.json -Json
```

Common modes:

```text
UI
Status
RunUpdates
ResetWindowsUpdate
Configure
DriverAudit
DriverReport
CollectLogs
ShowLog
RunOnceTask
```

Notes:

- `Status` and `DriverAudit` can run without elevation.
- `Configure`, `RunUpdates`, `ResetWindowsUpdate`, and scheduled-task operations should run elevated.
- `ResetWindowsUpdate` also accepts aliases `ResetWinUpdate` and `ResetUpdateCache`, and requires `-ConfirmReset`.
- The GUI entry point remains `PcNinja.WinUpdateTool.exe`.

## New In RC13.1

- Adds `PcNinja.WinUpdateTool.exe`, a branded Windows EXE host for the PowerShell UI.
- The host runs `WinUpdateTool.ps1` in-process through a Windows PowerShell runspace.
- MSI shortcuts now launch `PcNinja.WinUpdateTool.exe` instead of `wscript.exe` or `powershell.exe`.
- The portable EXE now extracts and launches the branded host.
- Legacy VBS/CMD launchers prefer the branded host when it exists.
- The running application should now show the PcNinja icon/process identity on the taskbar.

## New In RC13

- Adds a WiX-based MSI packaging definition.
- Adds an MSI cleanup script for scheduled tasks, ProgramData, and Event Log source cleanup during uninstall.
- Adds a portable EXE launcher build path.
- Produces separate installed and portable deliverables from the same app files:
  - `PcNinja-WinUpdateTool-Setup-1.0.13.0-x64.msi`
  - `PcNinja-WinUpdateTool-Portable-1.0.13.0.exe`

## New In RC12.11

- Moves `Feature Update Helper` from the Dashboard to the `Updates` tab.
- Places the update helper button below the manual update controls where there is more room.
- Changes Dashboard `Run Options` into a full-width section.
- Aligns the Dashboard run-option checkboxes on one row.

## New In RC12.10

- Pins the helper button near the top of the `Feature Update Helper` box.
- Removes bottom anchoring from the helper button so it cannot be pushed below the visible panel.
- Shortens the helper text and adds a smaller note below the button.

## New In RC12.9

- Expands the Dashboard `Feature Update Helper` section downward.
- Moves the helper button onto its own full-width row.
- Adds `PcNinja Drivers Updater` to the Driver Audit links.
- Renames the Driver Audit link section to `Driver Sources & Links`.

## New In RC12.8

- Shortens the header area and moves `wWw.PcNinja.Pro` to the right side of the subtitle row.
- Moves the main tab area upward to reclaim vertical space.
- Places `Run Options` and `Feature Update Helper` side by side on the Dashboard.
- Keeps the helper button visible inside the `Feature Update Helper` section.
- Adds a short recommended workflow note under the official driver-source links.

## New In RC12.7

- Adds a Dashboard `Feature Update Helper` section.
- Adds a helper button for Windows feature/image download resources.
- Does not auto-download or auto-run external upgrade tools.
- Adds official driver-source links to the Driver Audit tab:
  - Dell
  - Lenovo
  - HP
  - Microsoft Surface
  - ASUS
  - Intel
  - NVIDIA
  - AMD
  - Logitech

## New In RC12.6

- Stops rebuilding the hidden Logs viewer while another tab is active.
- Throttles live log repainting during update runs.
- Defers Logs and Dashboard refresh work until after the selected tab changes.
- Throttles Dashboard system checks when the Dashboard is already fresh.
- Limits the retry monitor to updating only the visible tab UI.

## New In RC12.5

- Uses the Logs tab itself as the only heading.
- Starts the log viewer at the top-left of the tab with minimal margin.
- Moves log action buttons to the bottom-right.
- Dynamically resizes the log viewer to use the available tab width and height.
- Reduces the log font slightly more to `Consolas 8`.

## New In RC12.4

- Removes the visible `Recent Log` heading from the Logs tab.
- Uses a smaller log font.
- Compacts displayed timestamps and severity names in the UI, while keeping the real log file unchanged.
- Uses a full-width wrapped log viewer with a forced vertical scrollbar.
- Keeps the `Bottom` button for jumping to the newest log line.

## New In RC12.3

- Replaces the Logs tab textbox with a single-column line viewer.
- Wraps long log lines inside the available width instead of clipping text under the right edge.
- Adds a visible vertical scroll bar for moving through log history.
- Adds a `Bottom` button to jump to the newest log entry.
- Forces Refresh and live updates to scroll to the newest row.

## New In RC12.2

- Removes the separate Settings tab.
- Moves the run options into the Dashboard:
  - Show reboot prompt after manual runs
  - Allow firmware/BIOS updates
- Replaces the Logs tab viewer with a plain wrapped log textbox and visible vertical scrollbar.
- Keeps longer 500-line recent log loading.

## New In RC12.1

- Fixes Dashboard Quick Actions by calling the real UI actions directly instead of trying to click controls on hidden tabs.
- Makes Dashboard `Open Logs` switch directly to the Logs tab.
- Disables the Dashboard `Run Update Now` button while an update process is already running.
- Improves the Logs tab with a bordered log viewer, visible scrollbars, no word wrapping, and a longer 500-line recent log view.

## New In RC12

- Adds a tabbed GUI: Dashboard, Updates, Schedule, Driver Audit, Logs, and Settings.
- Adds a Dashboard summary for last run, Windows Update activity, restart state, schedule, retry state, and latest driver audit report.
- Moves reboot prompt and firmware/BIOS controls into the Settings tab.
- Keeps the Exit button and footer anchored to the visible form area.
- Keeps RC11 report-only Driver Audit behavior unchanged.

## New In RC11

- Renames the UI panel from `Driver Inventory` to `Driver Audit`.
- Keeps Windows Update driver installation as the safe default path.
- Adds audit-only fields to the driver CSV/JSON:

```text
AuditCandidate
AuditPriority
AuditAction
PrimarySourceName
PrimarySourceUrl
SecondarySourceName
SecondarySourceUrl
HardwareVendorId
HardwareDeviceId
HardwareProductId
```

- Adds a `DriverAudit` CLI mode while keeping `DriverReport` for compatibility:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode DriverAudit -Json
```

- Creates `DriverAudit-*.csv`, `DriverAudit-*.json`, and `DriverAudit-*.txt`.
- Recommends only responsible official sources for comparison, such as:
  - PcNinja Drivers Updater
  - Dell Command | Update / Dell Drivers & Downloads
  - Lenovo System Update / Lenovo Support
  - HP Image Assistant
  - Microsoft Surface drivers and firmware
  - ASUS Download Center
  - Intel Driver & Support Assistant
  - NVIDIA official drivers
  - AMD Drivers and Support
  - Logitech Support + Download
- Does not claim that a driver is outdated.
- Does not download or install third-party drivers.
- No Windows Update engine behavior changed.

## New In RC10.2

- Fixes GUI startup crash:

```text
Cannot convert value "System.Windows.Forms.CheckBox" to type "System.Management.Automation.SwitchParameter"
```

- Renames internal UI control variables so they do not collide with CLI parameters such as `-EnableSchedule`, `-Frequency`, `-MonthlyDay`, `-RunAtStartup`, and `-RunIfMissed`.
- Keeps the RC10 remote/admin CLI syntax unchanged.
- No Windows Update engine behavior changed.

## New In RC10.1

- Restores explicit GUI launch behavior for normal app startup.
- Adds `-STA` to GUI launch paths.
- Adds GUI startup diagnostics:

```text
C:\ProgramData\PcNinja\WinUpdateTool\Logs\GuiStartup.log
```

- No Windows Update engine behavior changed.

## New In RC10

- Adds remote/admin command modes:

```text
Status
Configure
RunOnceTask
CollectLogs
```

- Adds `-Json` output for automation.
- Adds a run-once SYSTEM scheduled task for remote launches:

```text
\PcNinja\PcNinja WinUpdate Tool Run Once
```

- Keeps the tested RC9.5 update engine behavior unchanged.
- Recommended remote pattern: use PowerShell remoting to install/configure/start the local task, then read back JSON status/logs.

## Remote/Admin Commands

Installed path:

```text
C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1
```

Status as JSON:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode Status -Json
```

Start a one-off update run through a local SYSTEM task:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode RunOnceTask -Json
```

Run directly without UI:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode RunUpdates -Silent -RunType Manual -Json
```

Collect logs/config/state/task XML into a ZIP:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode CollectLogs -Json
```

Configure a monthly schedule:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode Configure -Frequency Monthly -MonthlyDay 15 -Time 03:00 -EnableSchedule -Json
```

Configure startup runs with a 15-minute delay:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode Configure -Frequency Startup -StartupDelayMinutes 5 -EnableSchedule -Json
```

Example PowerShell remoting launch:

```powershell
Invoke-Command -ComputerName PCNAME -ScriptBlock {
    & "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode RunOnceTask -Json
}
```

Example remote status check:

```powershell
Invoke-Command -ComputerName PCNAME -ScriptBlock {
    & "C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1" -Mode Status -Json
}
```

## New In RC9.5

- If the user clicks `Run Update Now` while Windows Update or Windows servicing is actively installing, the UI schedules an automatic retry immediately.
- If background Windows Update activity is detected and the user chooses not to stop it, the UI schedules an automatic retry immediately.
- The retry still uses the configured retry delay, max retries, and retry backoff.
- The existing Task Scheduler one-time retry remains the persistent mechanism.
- While the app window is open, a lightweight UI retry monitor also starts the retry when the scheduled retry time arrives. The run lock prevents duplicate runs if Task Scheduler starts it at the same time.
- The user can still click `Run Update Now` manually at any time to try again.

## New In RC9.4

- Shows retry status as three short lines:

```text
Next retry
Attempt
Reason
```

- Keeps the full retry reason in logs/state, but uses a shorter readable reason in the UI.
- Gives the retry-status label more space and a smaller normal-weight font.
- No update, driver, or scheduling behavior changed in this build.

## New In RC9.3

- Makes the retry-policy group taller.
- Aligns the retry numeric row with more vertical breathing room.
- Moves scheduled-task status and recent-log controls down as a group.
- No update, driver, or scheduling behavior changed in this build.

## New In RC9.2

- Widens and centers the schedule/retry numeric fields.
- Improves retry-policy spacing so values are visible next to their spinner buttons.
- No update, driver, or scheduling behavior changed in this build.

## New In RC9.1

- Pending file rename operations are now classified instead of treated as an automatic hard reboot requirement.
- Windows Update runs are still blocked by real servicing/reboot markers:

```text
Component Based Servicing\RebootPending
WindowsUpdate\Auto Update\RebootRequired
Pending computer rename
Pending file renames under Windows servicing, update, driver, DriverStore, or INF paths
```

- Generic pending file rename operations are logged as warnings and do not block the update flow.
- Adds:

```text
Uninstall-WinUpdateTool.cmd
```

- Reduces the default UI height and enables scrolling fallback so the bottom status line and `Exit` button remain reachable.

## New In RC9

- Adds a `Driver Inventory` panel in the UI.
- Creates CSV, JSON, and TXT driver inventory reports.
- Collects device names, classes, providers, versions, dates, INF names, device IDs, hardware IDs, compatible IDs, OEM/model, BIOS, and OS details.
- Marks high-confidence vendor-driver comparison candidates using hardware-ID patterns similar to commercial driver tools:

```text
PCI\VEN_xxxx&DEV_xxxx
HDAUDIO\FUNC_xx&VEN_xxxx&DEV_xxxx
USB\VID_xxxx&PID_xxxx
HID\VID_xxxx&PID_xxxx
SCSI\...
```

- Filters common generic/noisy entries such as generic disks, optical drives, software/root devices, USB storage, and generic HID/ACPI entries.
- Does not download or install third-party drivers.
- Adds CLI report mode:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinUpdateTool.ps1 -Mode DriverReport
```

Reports are saved to:

```text
C:\ProgramData\PcNinja\WinUpdateTool\DriverReports
```

Important: `UpdateCandidate` in the report means the device is useful for vendor-driver comparison. It does not mean the installed driver is outdated.

## New In RC9

- Fixes a PowerShell collection unwrapping issue that could stop the run after discovery with: `The property 'Count' cannot be found on this object`.

## From RC8

- Default startup delay remains `15` minutes. Default first retry delay and cooldown are now `5` minutes.
- Runs explicit discovery scans for broad updates, drivers, and optional updates.
- Merges duplicate updates by Windows Update identity before download/install.
- Detects firmware/BIOS candidates and logs them clearly.
- Firmware/BIOS installation is disabled by default and requires the UI setting `Allow firmware/BIOS updates`.

## From RC7

- Installs updates from the broad missing/non-hidden Windows Update result instead of limiting the install queue to `Type='Software'`.
- Includes `Type='Driver'` updates, which covers driver updates shown under Windows Update -> Advanced options -> Optional updates.
- Adds richer discovery and queue logging with update type, categories, and optional-related flags when Windows exposes them.

## From RC6.1

- Fixes Task Scheduler XML registration by using the SYSTEM SID (`S-1-5-18`) and omitting the rejected `LogonType` XML value.

## From RC6

Schedule modes:

```text
Daily
Weekly
Monthly
Startup
```

Additional schedule options:

- Monthly day of month, limited to day `1-28` for safe every-month behavior.
- Startup delayed trigger.
- Optional startup catch-up for daily/weekly/monthly schedules.
- Run-if-missed behavior through Task Scheduler `StartWhenAvailable`.

## Important Implementation Detail

Windows PowerShell's `New-ScheduledTaskTrigger` does not support monthly triggers.

RC6 now creates the normal schedule task using Task Scheduler XML registration.

This allows the same task to contain:

- Calendar trigger.
- Monthly trigger.
- Boot trigger with delay.
- Run-if-missed setting.

## Schedule Examples

Monthly only:

```text
Frequency: Monthly
Month day: 15
Time: 03:00
Also run after startup: off
```

Monthly plus startup catch-up:

```text
Frequency: Monthly
Month day: 15
Time: 03:00
Also run after startup: on
Startup delay: 15 minutes
Run if missed: on
```

Startup only:

```text
Frequency: Startup
Startup delay: 15 minutes
```

Weekly:

```text
Frequency: Weekly
Day: Sunday
Time: 03:00
```

## From RC5

- Single-instance run lock:

```text
C:\ProgramData\PcNinja\WinUpdateTool\run.lock
```

- Persistent state:

```text
C:\ProgramData\PcNinja\WinUpdateTool\state.json
```

- One-time retry task:

```text
\PcNinja\PcNinja WinUpdate Tool Retry
```

- Retry policy controls.
- Run controller.

## From RC4

- Microsoft Update registration when possible.
- Up to 3 update passes.
- Stop at reboot boundary.
- Broad discovery logging.
- Post-pass verification scan.

## Install In A VM

1. Copy this folder to the VM.
2. Double-click:

```text
Install-WinUpdateTool.vbs
```

3. Approve UAC.
4. The UI should open after installation.

The app installs to:

```text
C:\Program Files\PcNinja\WinUpdateTool
```

## Check Installed Apps

After install, check:

```text
Settings -> Apps -> Installed apps
```

or:

```text
Control Panel -> Programs and Features
```

You should see:

```text
PcNinja WinUpdate Tool
```

Version:

```text
1.1.2.0
```

## Scheduled Tasks

Normal schedule:

```text
\PcNinja\PcNinja WinUpdate Tool
```

Temporary retry:

```text
\PcNinja\PcNinja WinUpdate Tool Retry
```

Remote/admin run once:

```text
\PcNinja\PcNinja WinUpdate Tool Run Once
```

## Logs And Config

Logs:

```text
C:\ProgramData\PcNinja\WinUpdateTool\Logs\WinUpdateTool.log
```

Driver reports:

```text
C:\ProgramData\PcNinja\WinUpdateTool\DriverReports
```

Config:

```text
C:\ProgramData\PcNinja\WinUpdateTool\config.json
```

State:

```text
C:\ProgramData\PcNinja\WinUpdateTool\state.json
```

## Uninstall

Use Windows Installed Apps / Programs and Features.

For quick VM testing, you can also double-click:

```text
Uninstall-WinUpdateTool.cmd
```

The normal uninstall removes:

- Installed app folder.
- ProgramData config/logs/state/lock.
- Normal scheduled task.
- Retry scheduled task.
- Run-once scheduled task.
- Start Menu shortcut.
- Desktop shortcut if it exists.
- Registry uninstall entry.
- App Event Log source when possible.

## Website

The app displays:

```text
wWw.PcNinja.Pro
```











