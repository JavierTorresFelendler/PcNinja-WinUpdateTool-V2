param(
    [string]$Version,
    [string]$PublicLabel,
    [string]$ReleaseTag,
    [string]$Repository,
    [string]$CertificateThumbprint,
    [string]$PfxPath,
    [securestring]$PfxPassword,
    [string]$TimestampServer = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

$packagingDir = Split-Path -Parent $PSCommandPath
$packageRoot = Split-Path -Parent $packagingDir
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$versionFile = Join-Path $packageRoot 'version.json'

if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
    $versionInfo = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
    if (-not $Version -and $versionInfo.version) {
        $Version = [string]$versionInfo.version
    }

    if (-not $PublicLabel -and $versionInfo.publicLabel) {
        $PublicLabel = [string]$versionInfo.publicLabel
    }

    if (-not $Repository -and $versionInfo.githubRepository) {
        $Repository = [string]$versionInfo.githubRepository
    }
}

if (-not $Version) {
    $Version = '2.2.7.0'
}

if (-not $PublicLabel) {
    $PublicLabel = 'V2.2.7'
}

if (-not $Repository) {
    $Repository = 'JavierTorresFelendler/PcNinja-WinUpdateTool-V2'
}

if (-not $ReleaseTag) {
    $ReleaseTag = ('v' + ($PublicLabel -replace '^V', '')).ToLowerInvariant()
}

$distDir = Join-Path $packageRoot 'dist'
$msiPath = Join-Path $distDir ("PcNinja-WinUpdateTool-Setup-{0}-x64.msi" -f $Version)
$portableExePath = Join-Path $distDir ("PcNinja-WinUpdateTool-Portable-{0}.exe" -f $Version)
$publicReleaseDir = Join-Path $packageRoot 'public-release'
# GitHub normalizes spaces in release asset names to dots. Use the normalized
# names at build time so update-manifest URLs address the actual assets.
$publicMsiFileName = 'WinUpdate.Tool.by.PcNinja.msi'
$publicPortableFileName = 'WinUpdate.Tool.by.PcNinja.exe'
$publicZipFileName = 'WinUpdate.Tool.by.PcNinja.Public.Release.zip'
$publicMsiPath = Join-Path $publicReleaseDir $publicMsiFileName
$publicPortablePath = Join-Path $publicReleaseDir $publicPortableFileName
$publicZipPath = Join-Path $packageRoot $publicZipFileName
$examplesDir = Join-Path $distDir 'deployment-examples'
$hostExePath = Join-Path $packageRoot 'PcNinja.WinUpdateTool.exe'
$cliExePath = Join-Path $packageRoot 'PcNinja.WinUpdateTool.Cli.exe'
$msiActionHostExePath = Join-Path $packageRoot 'PcNinja.WinUpdateTool.MsiActionHost.exe'
$wxsPath = Join-Path $packagingDir 'PcNinja.WinUpdateTool.wxs'
$launcherSource = Join-Path $packagingDir 'PortableLauncher.cs'
$hostSource = Join-Path $packagingDir 'WinUpdateToolHost.cs'
$cliSource = Join-Path $packagingDir 'WinUpdateToolCli.cs'
$msiActionHostSource = Join-Path $packagingDir 'MsiActionHost.cs'
$iconPath = Join-Path $packageRoot 'assets\PcNinja.ico'
$portableIconPath = Join-Path $packageRoot 'assets\PcNinja-Portable.ico'

if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}
else {
    Get-ChildItem -LiteralPath $distDir -File |
        Where-Object { $_.Name -like 'PcNinja-WinUpdateTool-*.msi' -or $_.Name -like 'PcNinja-WinUpdateTool-*.exe' -or $_.Name -like 'PcNinja-WinUpdateTool-*.wixpdb' } |
        Remove-Item -Force
}

if (Test-Path -LiteralPath $examplesDir) {
    Remove-Item -LiteralPath $examplesDir -Recurse -Force
}

if (Test-Path -LiteralPath $publicReleaseDir) {
    Remove-Item -LiteralPath $publicReleaseDir -Recurse -Force
}

if (Test-Path -LiteralPath $publicZipPath) {
    Remove-Item -LiteralPath $publicZipPath -Force
}

if (Test-Path -LiteralPath ($publicZipPath + '.sha256.txt')) {
    Remove-Item -LiteralPath ($publicZipPath + '.sha256.txt') -Force
}

function Write-ExampleFile {
    param(
        [string]$Name,
        [string[]]$Lines
    )

    if (-not (Test-Path -LiteralPath $examplesDir)) {
        New-Item -ItemType Directory -Path $examplesDir -Force | Out-Null
    }

    Set-Content -LiteralPath (Join-Path $examplesDir $Name) -Value $Lines -Encoding ASCII
}

function Invoke-MsiSql {
    param(
        [object]$Database,
        [string]$Query
    )

    $view = $Database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $Database, @($Query))
    try {
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
    }
    finally {
        $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null) | Out-Null
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($view)
    }
}

function Repair-MsiScheduleDialogFlow {
    param([string]$Path)

    $installer = New-Object -ComObject WindowsInstaller.Installer
    $database = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Path, 1))
    try {
        Invoke-MsiSql -Database $database -Query "DELETE FROM ``ControlEvent`` WHERE ``Dialog_``='InstallDirDlg' AND ``Control_``='Next' AND ``Event``='NewDialog' AND ``Argument``='VerifyReadyDlg'"
        Invoke-MsiSql -Database $database -Query "DELETE FROM ``ControlEvent`` WHERE ``Dialog_``='VerifyReadyDlg' AND ``Control_``='Back' AND ``Event``='NewDialog' AND ``Argument``='InstallDirDlg' AND ``Condition``='NOT Installed'"
        Invoke-MsiSql -Database $database -Query "UPDATE ``ControlEvent`` SET ``Condition``='1', ``Ordering``=10 WHERE ``Dialog_``='InstallDirDlg' AND ``Control_``='Next' AND ``Event``='NewDialog' AND ``Argument``='PcNinjaScheduleDlg'"
        Invoke-MsiSql -Database $database -Query "UPDATE ``ControlEvent`` SET ``Ordering``=1 WHERE ``Dialog_``='VerifyReadyDlg' AND ``Control_``='Back' AND ``Event``='NewDialog' AND ``Argument``='PcNinjaScheduleDlg'"
        $database.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $database, $null) | Out-Null
    }
    finally {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($database)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
        $database = $null
        $installer = $null
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-ReleaseSigningCertificate {
    param(
        [string]$Thumbprint,
        [string]$PfxFile,
        [securestring]$Password
    )

    if ($PfxFile) {
        if (-not (Test-Path -LiteralPath $PfxFile -PathType Leaf)) {
            throw "PFX file was not found: $PfxFile"
        }

        if (-not $Password) {
            $Password = Read-Host -Prompt 'PFX password' -AsSecureString
        }

        $imported = Import-PfxCertificate -FilePath $PfxFile -CertStoreLocation Cert:\CurrentUser\My -Password $Password -Exportable
        if (-not $imported) {
            throw 'PFX import did not return a certificate.'
        }

        return $imported | Select-Object -First 1
    }

    $certs = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue |
        Where-Object { $_.HasPrivateKey }

    if ($Thumbprint) {
        $cleanThumbprint = ($Thumbprint -replace '\s', '').ToUpperInvariant()
        $match = $certs | Where-Object { ($_.Thumbprint -replace '\s', '').ToUpperInvariant() -eq $cleanThumbprint } | Select-Object -First 1
        if (-not $match) {
            throw "Code-signing certificate was not found or has no private key: $Thumbprint"
        }

        return $match
    }

    # Never auto-select an unrelated certificate from the developer machine.
    # Release signing must be an explicit choice through -CertificateThumbprint or -PfxPath.
    return $null
}

function Sign-ReleaseFile {
    param(
        [string]$Path,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$Timestamp
    )

    if (-not $Certificate) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Cannot sign missing file: $Path"
    }

    $signature = Set-AuthenticodeSignature -LiteralPath $Path -Certificate $Certificate -HashAlgorithm SHA256 -TimestampServer $Timestamp
    if ($signature.Status -ne 'Valid') {
        throw "Signing failed for $Path. Status: $($signature.Status). Message: $($signature.StatusMessage)"
    }
}

function Sign-ReleaseFiles {
    param(
        [string[]]$Paths,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$Timestamp
    )

    if (-not $Certificate) {
        return
    }

    foreach ($path in $Paths) {
        Sign-ReleaseFile -Path $path -Certificate $Certificate -Timestamp $Timestamp
    }
}

$signingCertificate = Get-ReleaseSigningCertificate -Thumbprint $CertificateThumbprint -PfxFile $PfxPath -Password $PfxPassword
if ($signingCertificate) {
    Write-Host "Signing enabled with certificate: $($signingCertificate.Subject)"
}
else {
    Write-Host 'Signing skipped: no code-signing certificate was explicitly provided.'
}
$wixCandidates = @(
    (Join-Path $workspaceRoot '.build-tools-wix6\wix.exe'),
    (Join-Path $workspaceRoot '.build-tools\wix.exe'),
    'wix.exe'
)

$wix = $wixCandidates | Where-Object {
    if ($_ -eq 'wix.exe') {
        return [bool](Get-Command $_ -ErrorAction SilentlyContinue)
    }

    return Test-Path -LiteralPath $_
} | Select-Object -First 1

if (-not $wix) {
    throw 'WiX was not found. Install it with: dotnet tool install wix --version 6.* --tool-path .build-tools-wix6'
}

Push-Location $packageRoot
try {
    $extensionList = & $wix extension list 2>$null
    if ($LASTEXITCODE -ne 0 -or (($extensionList -join "`n") -notmatch 'WixToolset\.UI\.wixext')) {
        & $wix extension add 'WixToolset.UI.wixext/6.0.2'
        if ($LASTEXITCODE -ne 0) {
            throw "WiX UI extension install failed with exit code $LASTEXITCODE."
        }
    }
}
finally {
    Pop-Location
}

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) {
    throw "The .NET Framework compiler was not found: $csc"
}

$powerShellAutomation = [psobject].Assembly.Location
if (-not (Test-Path -LiteralPath $powerShellAutomation)) {
    throw "System.Management.Automation.dll was not found: $powerShellAutomation"
}

& $csc `
    /nologo `
    /target:winexe `
    /optimize+ `
    /platform:x64 `
    /out:$hostExePath `
    /win32icon:$iconPath `
    /reference:$powerShellAutomation `
    /reference:System.Windows.Forms.dll `
    /reference:System.Drawing.dll `
    $hostSource

if ($LASTEXITCODE -ne 0) {
    throw "Branded host compile failed with exit code $LASTEXITCODE."
}

& $csc `
    /nologo `
    /target:exe `
    /optimize+ `
    /platform:x64 `
    /out:$cliExePath `
    /win32icon:$iconPath `
    $cliSource

if ($LASTEXITCODE -ne 0) {
    throw "CLI host compile failed with exit code $LASTEXITCODE."
}

& $csc `
    /nologo `
    /target:winexe `
    /optimize+ `
    /platform:x64 `
    /out:$msiActionHostExePath `
    /win32icon:$iconPath `
    $msiActionHostSource

if ($LASTEXITCODE -ne 0) {
    throw "MSI maintenance host compile failed with exit code $LASTEXITCODE."
}

Sign-ReleaseFiles -Certificate $signingCertificate -Timestamp $TimestampServer -Paths @(
    $hostExePath,
    $cliExePath,
    $msiActionHostExePath,
    (Join-Path $packageRoot 'WinUpdateTool.ps1'),
    (Join-Path $packageRoot 'WinUpdateTool.V2Ui.ps1'),
    (Join-Path $packageRoot 'WinUpdateCore.psm1'),
    (Join-Path $packageRoot 'Install-WinUpdateTool.ps1'),
    (Join-Path $packageRoot 'Uninstall-WinUpdateTool.ps1'),
    (Join-Path $packageRoot 'MsiCleanup-WinUpdateTool.ps1'),
    (Join-Path $packageRoot 'MsiConfigure-WinUpdateTool.ps1')
)

Push-Location $packageRoot
try {
    & $wix build `
        -arch x64 `
        -ext WixToolset.UI.wixext `
        -d "SourceDir=$packageRoot" `
        -d "ProductVersion=$Version" `
        -o $msiPath `
        $wxsPath
}
finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    throw "WiX build failed with exit code $LASTEXITCODE."
}

Repair-MsiScheduleDialogFlow -Path $msiPath
Sign-ReleaseFile -Path $msiPath -Certificate $signingCertificate -Timestamp $TimestampServer

$portableCompileArguments = @(
    '/nologo',
    '/target:winexe',
    '/optimize+',
    '/platform:x64',
    "/out:$portableExePath",
    "/win32icon:$portableIconPath",
    "/reference:$powerShellAutomation",
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Drawing.dll',
    ("/resource:{0},PcNinjaPortable.WinUpdateTool.ps1" -f (Join-Path $packageRoot 'WinUpdateTool.ps1')),
    ("/resource:{0},PcNinjaPortable.WinUpdateTool.V2Ui.ps1" -f (Join-Path $packageRoot 'WinUpdateTool.V2Ui.ps1')),
    ("/resource:{0},PcNinjaPortable.WinUpdateCore.psm1" -f (Join-Path $packageRoot 'WinUpdateCore.psm1')),
    ("/resource:{0},PcNinjaPortable.version.json" -f (Join-Path $packageRoot 'version.json')),
    ("/resource:{0},PcNinjaPortable.Ninja-DMT.png" -f (Join-Path $packageRoot 'assets\Ninja-DMT.png')),
    ("/resource:{0},PcNinjaPortable.Ninja-DMT-header.png" -f (Join-Path $packageRoot 'assets\Ninja-DMT-header.png')),
    ("/resource:{0},PcNinjaPortable.PcNinja.ico" -f (Join-Path $packageRoot 'assets\PcNinja.ico')),
    ("/resource:{0},PcNinjaPortable.PcNinja-SoftAlert.wav" -f (Join-Path $packageRoot 'assets\PcNinja-SoftAlert.wav')),
    $launcherSource
)

& $csc @portableCompileArguments

if ($LASTEXITCODE -ne 0) {
    throw "Portable launcher compile failed with exit code $LASTEXITCODE."
}

Sign-ReleaseFile -Path $portableExePath -Certificate $signingCertificate -Timestamp $TimestampServer

Write-ExampleFile -Name 'Install-MSI-Silent-Basic.cmd' -Lines @(
    '@echo off',
    'setlocal',
    ('set "MSI=%~dp0..\{0}"' -f $publicMsiFileName),
    'msiexec /i "%MSI%" /qn /norestart',
    'exit /b %ERRORLEVEL%'
)

Write-ExampleFile -Name 'Install-MSI-Silent-WithProperties.cmd' -Lines @(
    '@echo off',
    'setlocal',
    ('set "MSI=%~dp0..\{0}"' -f $publicMsiFileName),
    'msiexec /i "%MSI%" /qn /norestart ^',
    '  PCNINJA_ENABLE_SCHEDULE=1 ^',
    '  PCNINJA_FREQUENCY=Monthly ^',
    '  PCNINJA_MONTHLY_DAY=15 ^',
    '  PCNINJA_TIME=03:00 ^',
    '  PCNINJA_RUN_AT_STARTUP=1 ^',
    '  PCNINJA_STARTUP_DELAY=5 ^',
    '  PCNINJA_RUN_IF_MISSED=1 ^',
    '  PCNINJA_WAKE_TO_RUN=1 ^',
    '  PCNINJA_ALLOW_FIRMWARE=0 ^',
    '  PCNINJA_REBOOT_PROMPT=1 ^',
    '  PCNINJA_ENABLE_AUTORETRY=1 ^',
    '  PCNINJA_RETRY_INITIAL_DELAY=5 ^',
    '  PCNINJA_RETRY_MAX_ATTEMPTS=3 ^',
    '  PCNINJA_RETRY_BACKOFF=2 ^',
    '  PCNINJA_MINIMUM_COOLDOWN=5',
    'exit /b %ERRORLEVEL%'
)

Write-ExampleFile -Name 'BigFix-Action-Example.cmd' -Lines @(
    '@echo off',
    'rem BigFix usually works best with one command line.',
    ('msiexec /i "__Download\{0}" /qn /norestart PCNINJA_ENABLE_SCHEDULE=1 PCNINJA_FREQUENCY=Monthly PCNINJA_MONTHLY_DAY=15 PCNINJA_TIME=03:00 PCNINJA_RUN_AT_STARTUP=1 PCNINJA_STARTUP_DELAY=5 PCNINJA_RUN_IF_MISSED=1 PCNINJA_WAKE_TO_RUN=1 PCNINJA_ALLOW_FIRMWARE=0 PCNINJA_REBOOT_PROMPT=1 PCNINJA_ENABLE_AUTORETRY=1 PCNINJA_RETRY_INITIAL_DELAY=5 PCNINJA_RETRY_MAX_ATTEMPTS=3 PCNINJA_RETRY_BACKOFF=2 PCNINJA_MINIMUM_COOLDOWN=5' -f $publicMsiFileName)
)

Write-ExampleFile -Name 'Installed-CLI-Examples.cmd' -Lines @(
    '@echo off',
    'setlocal',
    'set "CLI=%ProgramFiles%\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe"',
    '"%CLI%" /?',
    '"%CLI%" -Mode Status -Json',
    '"%CLI%" -Mode Configure -EnableSchedule -Frequency Monthly -MonthlyDay 15 -Time 03:00 -RunAtStartup -StartupDelayMinutes 5 -RunIfMissed -WakeToRun -RetryInitialDelayMinutes 5 -MinimumCooldownMinutes 5 -Json',
    '"%CLI%" -Mode RunUpdates -Silent -RunType Manual -Json',
    '"%CLI%" -Mode ResetWindowsUpdate -ConfirmReset -Json',
    '"%CLI%" -Mode AppUpdateCheck -Json',
    '"%CLI%" -Mode AppUpdateDownload -Json',
    'exit /b %ERRORLEVEL%'
)

Write-ExampleFile -Name 'Portable-CLI-Examples.cmd' -Lines @(
    '@echo off',
    'setlocal',
    ('set "PORTABLE=%~dp0..\{0}"' -f $publicPortableFileName),
    '"%PORTABLE%" /?',
    '"%PORTABLE%" -Mode Status -Json',
    '"%PORTABLE%" -Mode DriverAudit -Json',
    '"%PORTABLE%" -Mode Configure -EnableSchedule -Frequency Monthly -MonthlyDay 15 -Time 03:00 -RunAtStartup -StartupDelayMinutes 5 -RunIfMissed -WakeToRun -RetryInitialDelayMinutes 5 -MinimumCooldownMinutes 5 -Json',
    '"%PORTABLE%" -Mode ResetWindowsUpdate -ConfirmReset -Json',
    '"%PORTABLE%" -Mode AppUpdateCheck -Json',
    '"%PORTABLE%" -Mode AppUpdateDownload -UpdatePackageType Portable -Json',
    'exit /b %ERRORLEVEL%'
)

Write-ExampleFile -Name 'README-Deployment-Examples.txt' -Lines @(
    'PcNinja WinUpdate Tool deployment examples',
    '',
    'Files:',
    '  Install-MSI-Silent-Basic.cmd',
    '    Silent MSI install only.',
    '',
    '  Install-MSI-Silent-WithProperties.cmd',
    '    Silent MSI install plus post-install configuration using MSI properties.',
    '',
    '  BigFix-Action-Example.cmd',
    '    Single-line BigFix-style example. Adjust download paths for your action.',
    '',
    '  Installed-CLI-Examples.cmd',
    '    Examples for the installed CLI host.',
    '',
    '  Portable-CLI-Examples.cmd',
    '    Examples for the portable EXE CLI mode.',
    '',
    'App update modes:',
    '  AppUpdateCheck reads update-manifest.json and reports whether a newer release exists.',
    '  AppUpdateDownload downloads and verifies the selected release package.',
    '  AppUpdateInstall is user-initiated and is intended for installed MSI deployments.',
    '  Portable EXE update downloads use the versioned portable file name from the manifest.',
    '',
    'CMD line-continuation rule:',
    '  The ^ character is only for CMD/BAT line continuation.',
    '  It must be the final character on the line. Do not put spaces after it.',
    '  For BigFix deployment, a single msiexec command line is usually safer.',
    '',
    'JSON MSI deployment:',
    '  Not included in this release. Use MSI properties for silent configuration.',
    '',
    'MSI configuration properties:',
    '  PCNINJA_ENABLE_SCHEDULE',
    '  PCNINJA_FREQUENCY',
    '  PCNINJA_TIME',
    '  PCNINJA_DAY_OF_WEEK',
    '  PCNINJA_MONTHLY_DAY',
    '  PCNINJA_RUN_AT_STARTUP',
    '  PCNINJA_STARTUP_DELAY',
    '  PCNINJA_RUN_IF_MISSED',
    '  PCNINJA_WAKE_TO_RUN',
    '  PCNINJA_ALLOW_FIRMWARE',
    '  PCNINJA_REBOOT_PROMPT',
    '  PCNINJA_ENABLE_AUTORETRY',
    '  PCNINJA_RETRY_INITIAL_DELAY',
    '  PCNINJA_RETRY_MAX_ATTEMPTS',
    '  PCNINJA_RETRY_BACKOFF',
    '  PCNINJA_MINIMUM_COOLDOWN',
    '',
    'Boolean MSI values:',
    '  1/0, true/false, yes/no, and on/off are accepted.',
    '',
    'Important:',
    '  The MSI post-install configuration runs elevated as LocalSystem.',
    '  MSI post-install configuration log:',
    '  %ProgramData%\PcNinja\WinUpdateTool\Logs\MsiConfigure.log'
)

New-Item -ItemType Directory -Path $publicReleaseDir -Force | Out-Null
Copy-Item -LiteralPath $msiPath -Destination $publicMsiPath -Force
Copy-Item -LiteralPath $portableExePath -Destination $publicPortablePath -Force
Copy-Item -LiteralPath $examplesDir -Destination (Join-Path $publicReleaseDir 'deployment-examples') -Recurse -Force

$publicMsiHash = (Get-FileHash -LiteralPath $publicMsiPath -Algorithm SHA256).Hash
$publicPortableHash = (Get-FileHash -LiteralPath $publicPortablePath -Algorithm SHA256).Hash
$releaseBaseUrl = "https://github.com/$Repository/releases/download/$ReleaseTag"
$publicMsiUrl = "$releaseBaseUrl/$([System.Uri]::EscapeDataString($publicMsiFileName))"
$publicPortableUrl = "$releaseBaseUrl/$([System.Uri]::EscapeDataString($publicPortableFileName))"

$manifest = [ordered]@{
    channel = if ($versionInfo -and $versionInfo.releaseChannel) { [string]$versionInfo.releaseChannel } else { 'stable' }
    publicLabel = $PublicLabel
    version = $Version
    minimumSupportedVersion = $Version
    releaseNotesUrl = "https://github.com/$Repository/releases/tag/$ReleaseTag"
    msi = [ordered]@{
        fileName = $publicMsiFileName
        url = $publicMsiUrl
        sha256 = $publicMsiHash
    }
    portable = [ordered]@{
        fileName = $publicPortableFileName
        url = $publicPortableUrl
        sha256 = $publicPortableHash
    }
    signing = [ordered]@{
        required = [bool]($signingCertificate)
        expectedPublisher = 'PcNinja'
    }
}

$manifestPath = Join-Path $publicReleaseDir 'update-manifest.json'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8NoBom)

Set-Content -LiteralPath (Join-Path $publicReleaseDir "$PublicLabel-RELEASE-NOTES.txt") -Encoding UTF8 -Value @(
    "PcNinja WinUpdate Tool $PublicLabel Release Notes",
    '',
    $(if ($PublicLabel -match '-RC') { 'Release candidate for the V2 line.' } else { 'Official stable release of the V2 line.' }),
    '',
    'Highlights:',
    '- Fixes Hebrew and other non-ASCII update titles displaying as mojibake in the Available Updates window and application logs.',
    '- Uses explicit UTF-8 encoding for both PowerShell subprocess output and the UI readers that capture it.',
    '',
    'Previous V2.2.6 improvements:',
    '- Validates update package filenames, extensions, and SHA256 hashes before accepting an update manifest.',
    '- Downloads app updates to a temporary file and publishes them only after hash verification.',
    '- Saves configuration and run-state JSON through atomic file replacement to avoid partial files.',
    '',
    'Earlier V2.2.5 improvements:',
    '- Rebuilds the Portable EXE as a Windows GUI host that runs the PowerShell payload in-process instead of extracting and executing embedded EXE files.',
    '- Fixes the Portable UI launch after UAC by running the in-process PowerShell GUI in an explicit STA runspace and recording bootstrap failures in the portable runtime Logs folder.',
    '- Fixes normal Portable double-click launches by allowing the elevated WinForms process to open with a visible normal window instead of inheriting a hidden startup state.',
    '- Embeds named scripts and assets directly instead of an opaque portable payload ZIP to reduce unsigned antivirus false-positive risk.',
    '- Uses CreateNoWindow for background update checks, WAN lookup, update operations, and relaunch monitoring.',
    '- Replaces MSI CMD custom actions with a hidden managed maintenance host for process shutdown, configuration, and cleanup.',
    '- Fixes MSI Task Scheduler configuration by passing the complete installed script path to the deferred maintenance action instead of a quoted trailing-backslash directory.',
    '- Replaces existing PcNinja WinUpdate scheduled tasks across legacy task paths before registering one canonical task, preventing duplicates after MSI upgrades.',
    '- Allows corrected RC builds with the same MSI version to replace an earlier RC package during in-place upgrade testing.',
    '- Replaces the legacy single-frame V2 icon with multi-resolution transparent Windows ICO assets.',
    '- Uses the approved transparent laptop-ninja artwork for the installed host, taskbar/window, MSI branding, shortcuts, uninstall entry, and Portable EXE download.',
    '- Sets the Windows AppUserModelID on the host process and Start Menu shortcut so the branded icon is retained on the Taskbar.',
    '- Removes the in-app header logo so the V2 title bar no longer shows a dark logo inside the dark UI frame.',
    '- Adds a softer PcNinja alert sound for important warning, error, and question dialogs.',
    '- Keeps routine informational dialogs silent and suppresses the harsh default Windows MessageBox sound.',
    '- Adds shared version manifest foundation.',
    '- Adds app update check/download/install CLI foundations.',
    '- Adds public update-manifest.json for GitHub Releases.',
    '- Fixes V2 UI manual run, Snooz run, reset, and schedule actions to launch WinUpdateTool.ps1.',
    '- Simplifies V2 navigation: Settings owns schedule, app update stays in the sidebar, and duplicate quick actions were removed.',
    '- Adds non-blocking V2 preview scan and live-follow log refresh.',
    '- Restores the V1-style manual update workflow with Windows, optional, driver, and firmware scopes.',
    '- Restores restart handling, Windows Update reset access, and Snooz only when Windows Update is actually busy.',
    '- Adds portable EXE app updates that download the next versioned EXE beside the running portable file.',
    '- Hardens CLI JSON output for Windows PowerShell 5.1 and removes generic object lists from V2 preview output.',
    '- Fixes V2 available-update preview serialization when Windows Update returns real update candidates.',
    '- Fixes the V2 schedule summary falsely showing Task not installed after a schedule is saved.',
    '- Treats no-update preview scans as successful and ignores helper output before the preview JSON result.',
    '- Labels the V2 log filter box and reduces follow-mode flicker by scrolling only when log text changes.',
    '- Reworks the V2 Drivers tab into audit, PcNinja tools, and manufacturer reference sections.',
    '- Rebalances the V2 Settings layout with wider wake and retry sections plus lower action buttons.',
    '- Makes V2 Logs resize with the window, adds Open Log File, wraps long lines, and follows with live append.',
    '- Adds responsive V2 page layout rules so cards and controls adapt to narrow VM windows and maximized screens.',
    '- Removes unwanted Dashboard scrollbars in the normal V2 window size.',
    '- Automatically checks GitHub for tool updates after the UI opens and shows an update dialog only when a newer release exists.',
    '- Adds MSI relaunch handoff and portable EXE download-and-run handoff for user-approved tool updates.',
    '- Adds a public support log bundle export button in Logs.',
    '- Updates footer result status after scans and background runs complete.',
    '- Aligns the public label and MSI/ProductVersion metadata so Windows uninstall views match the RC build.',
    '- Adds host, CPU, RAM, and free-disk details to the V2 System Status sidebar.',
    '- Adds Remote Assistance and official PcNinja site links to the V2 Updates helpful-links panel.',
    '- Repositions the Available Updates View List action and fixes top-tab resizing at narrow widths.',
    '- Moves the V2 Schedule helper text below the schedule fields to avoid visual interference with the time selector.',
    '- Renames the Drivers tools panel to PcNinja Free Tools and simplifies the link labels.',
    '- Reapplies tab layout after form and tab-host resize events so restored windows keep all top tabs visible.',
    '- Uses invariant English date formatting in the V2 UI even on non-English Windows locales.',
    '- Enables double buffering on the V2 form, panels, and cards to reduce resize/redraw artifacts.',
    '- Keeps long log lines on one line with horizontal scrolling so live-follow does not jump during wrapped lines.',
    '- Fixes V2 available-update preview result handling so successful scans do not surface as generic Failed popups.',
    '- Filters warning/info stream noise from V2 preview JSON output so Check Available Updates can complete in MSI and portable builds.',
    '- Adds Clear Schedule in V2 Settings and removes all PcNinja WinUpdate Tool scheduled tasks during cleanup.',
    '- Sets a larger V2 minimum window size based on VM layout validation.',
    '- Moves Settings Save/Clear schedule actions into the top header beside Settings and Help.',
    '- Keeps Settings and Logs layouts stable after first paint, maximize, restore, and manual resizing.',
    '- Changes the Help button to open the GitHub V2 user guide.',
    '- Adds logged-on user, LAN/WAN IP, GPU, motherboard, and BIOS summary data to the V2 System Status sidebar.',
    '- Uses conditional log scrollbars so the log window does not show forced sliders when content does not require them.',
    '- Uses the approved transparent laptop-ninja artwork across the runtime icon, MSI, shortcuts, uninstall assets, and downloadable Portable EXE.',
    '- Removes the compact in-app header logo and keeps the branding on the window icon instead of inside the dark header.',
    '- Fixes the Windows & Office Activation link label so the ampersand displays correctly.',
    '- Moves the Logs filter field beside Open Log File.',
    '- Removes the compact in-app header logo treatment from the V2 header.',
    '- Rewrites restart-state details so users see a clear restart/no-restart message instead of raw registry diagnostics.',
    '- Fixes the V2 window closing seconds after launch: the WAN IP lookup now uses file-redirected process output instead of thread-based output events that crashed the PowerShell host.',
    '- Adds a PCNINJA_V2_UI_SMOKE_MS override so UI smoke runs can stay open long enough to cover asynchronous startup work.',
    '- Moves the Logs Export Bundle action onto the Application Logs title row, always visible above the filter field.',
    '- Inlines the Retry Policy description with its card title and re-spaces the retry rows for a cleaner Settings layout.',
    '- Removes leftover anchor settings that fought the responsive layout, fixing the stretched filter box and the failure combo clipped at the right edge in small windows.',
    '- Recomputes the responsive layout whenever a tab is opened so pages no longer show clipped footers or missing scrollbars until a manual resize.',
    '- Reads the tool update manifest from the main branch now that development converges on a single stable branch.',
    '- Preserves portable-mode detection across UAC elevation by forwarding the portable source path as a command-line argument, so portable installs download the new portable EXE beside the running file instead of the MSI.',
    '- Sizes the Drivers File password frame to its text so it no longer looks oversized at the minimum window size.',
    '- Keeps Windows Update engine behavior based on V1.1.2.',
    '',
    'Notes:',
    '- This release is unsigned unless signing was enabled during build.',
    '- Destructive Windows Update reset testing should be done in a VM.'
)

$signingStatus = if ($signingCertificate) { 'signed' } else { 'unsigned' }
Set-Content -LiteralPath (Join-Path $publicReleaseDir 'SIGNING-INSTRUCTIONS.txt') -Encoding UTF8 -Value @(
    "Signing status: $signingStatus",
    '',
    'If this release is unsigned, Windows SmartScreen or endpoint security tools may warn before execution.',
    '',
    'After signing, regenerate SHA256SUMS.txt and update-manifest.json.'
)

Set-Content -LiteralPath (Join-Path $publicReleaseDir 'PUBLIC-RELEASE-README.txt') -Encoding UTF8 -Value @(
    "PcNinja WinUpdate Tool $PublicLabel Public Release",
    '',
    'Files:',
    "- $publicMsiFileName",
    "- $publicPortableFileName",
    '- update-manifest.json',
    '- deployment-examples\',
    '- SHA256SUMS.txt',
    '',
    'Installed CLI examples:',
    '  "%ProgramFiles%\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" /?',
    '  "%ProgramFiles%\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode Status -Json',
    '  "%ProgramFiles%\PcNinja\WinUpdateTool\PcNinja.WinUpdateTool.Cli.exe" -Mode AppUpdateCheck -Json',
    '',
    'Portable examples:',
    "  $publicPortableFileName /?",
    "  $publicPortableFileName -Mode Status -Json",
    "  $publicPortableFileName -Mode AppUpdateCheck -Json",
    "  $publicPortableFileName -Mode AppUpdateDownload -UpdatePackageType Portable -Json",
    '',
    "Signing status: $signingStatus"
)

$shaLines = foreach ($file in (Get-ChildItem -LiteralPath $publicReleaseDir -File -Recurse | Sort-Object FullName)) {
    if ($file.Name -eq 'SHA256SUMS.txt') {
        continue
    }

    $relativePath = $file.FullName.Substring($publicReleaseDir.Length).TrimStart('\')
    '{0}  {1}' -f (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash, $relativePath
}

Set-Content -LiteralPath (Join-Path $publicReleaseDir 'SHA256SUMS.txt') -Value $shaLines -Encoding ASCII

Compress-Archive -Path (Join-Path $publicReleaseDir '*') -DestinationPath $publicZipPath -Force
$publicZipHash = (Get-FileHash -LiteralPath $publicZipPath -Algorithm SHA256).Hash
Set-Content -LiteralPath ($publicZipPath + '.sha256.txt') -Value ("{0}  {1}" -f $publicZipHash, $publicZipFileName) -Encoding ASCII

Get-FileHash -LiteralPath $msiPath, $portableExePath, $hostExePath, $cliExePath, $publicMsiPath, $publicPortablePath, $publicZipPath -Algorithm SHA256 |
    Select-Object Algorithm, Hash, Path
