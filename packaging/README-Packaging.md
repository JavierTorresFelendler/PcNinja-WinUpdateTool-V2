# PcNinja WinUpdate Tool Packaging

The packaging script produces two product deliverables using the version in `version.json`:

- `dist\PcNinja-WinUpdateTool-Setup-<version>-x64.msi`
- `dist\PcNinja-WinUpdateTool-Portable-<version>.exe`

Build command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Packages.ps1
```

The MSI uses WiX Toolset 6. If WiX is missing:

```powershell
dotnet tool install wix --version 6.* --tool-path ..\..\.build-tools-wix6
```

The MSI installs `PcNinja.WinUpdateTool.exe`, a branded host that runs the PowerShell UI in-process, plus `PcNinja.WinUpdateTool.Cli.exe` for command-line use.

Normal interactive MSI installs show a wizard with license, install-folder, schedule/options, progress, and finish pages.

The MSI can be deployed silently with `msiexec /qn` and can apply post-install configuration through public `PCNINJA_*` MSI properties.

JSON-based MSI deployment is not included in RC20.

The portable EXE is a small .NET Framework launcher with the app scripts and assets embedded as named resources. It extracts under `%LOCALAPPDATA%\PcNinja\WinUpdateTool\Portable\<version>`. With no arguments it launches `PcNinja.WinUpdateTool.exe`; with arguments it forwards them to `PcNinja.WinUpdateTool.Cli.exe`.

Deployment examples are generated under `dist\deployment-examples`.










