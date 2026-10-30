using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("PcNinja WinUpdate Tool Portable")]
[assembly: AssemblyCompany("PcNinja")]
[assembly: AssemblyProduct("PcNinja WinUpdate Tool")]
[assembly: AssemblyCopyright("Copyright (c) PcNinja")]
[assembly: AssemblyVersion("2.2.6.0")]
[assembly: AssemblyFileVersion("2.2.6.0")]
[assembly: AssemblyInformationalVersion("V2.2.6")]

internal static class PortableLauncher
{
    private const string Version = "2.2.6.0";
    private const string PublicLabel = "V2.2.6";
    private const string AppUserModelId = "PcNinja.WinUpdateTool";
    private const uint AttachParentProcess = 0xFFFFFFFF;

    private sealed class PortableResource
    {
        internal PortableResource(string resourceName, string relativePath)
        {
            ResourceName = resourceName;
            RelativePath = relativePath;
        }

        internal string ResourceName { get; private set; }
        internal string RelativePath { get; private set; }
    }

    private static readonly PortableResource[] Resources = new[]
    {
        new PortableResource("PcNinjaPortable.WinUpdateTool.ps1", "WinUpdateTool.ps1"),
        new PortableResource("PcNinjaPortable.WinUpdateTool.V2Ui.ps1", "WinUpdateTool.V2Ui.ps1"),
        new PortableResource("PcNinjaPortable.WinUpdateCore.psm1", "WinUpdateCore.psm1"),
        new PortableResource("PcNinjaPortable.version.json", "version.json"),
        new PortableResource("PcNinjaPortable.Ninja-DMT.png", Path.Combine("assets", "Ninja-DMT.png")),
        new PortableResource("PcNinjaPortable.Ninja-DMT-header.png", Path.Combine("assets", "Ninja-DMT-header.png")),
        new PortableResource("PcNinjaPortable.PcNinja.ico", Path.Combine("assets", "PcNinja.ico")),
        new PortableResource("PcNinjaPortable.PcNinja-SoftAlert.wav", Path.Combine("assets", "PcNinja-SoftAlert.wav"))
    };

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AttachConsole(uint processId);

    [STAThread]
    private static int Main(string[] args)
    {
        bool uiRequest = IsUiRequest(args);
        bool hasConsole = TryAttachParentConsole();

        try
        {
            WriteBootstrapLog("Launcher started. UI=" + uiRequest + "; Elevated=" + IsAdministrator());
            TrySetAppUserModelId();

            if (IsHelpRequest(args))
            {
                if (hasConsole)
                {
                    Console.Write(GetHelpText());
                }
                else
                {
                    ShowHelpWindow();
                }

                return 0;
            }

            if (uiRequest && !IsAdministrator())
            {
                WriteBootstrapLog("Requesting elevation for the portable UI.");
                return RelaunchElevated(args);
            }

            string extractRoot = GetExtractRoot();
            ExtractRuntimeFiles(extractRoot);
            WriteBootstrapLog("Portable runtime extracted to " + extractRoot);
            ConfigurePortableEnvironment();
            Directory.SetCurrentDirectory(extractRoot);

            string scriptPath = Path.Combine(extractRoot, "WinUpdateTool.ps1");
            if (!File.Exists(scriptPath))
            {
                throw new FileNotFoundException("The portable runtime script was not extracted.", scriptPath);
            }

            int exitCode = RunPowerShellScript(scriptPath, args, uiRequest);
            WriteBootstrapLog("PowerShell runtime completed with exit code " + exitCode);
            return exitCode;
        }
        catch (Exception ex)
        {
            WriteBootstrapLog("Launcher failure: " + ex);
            if (uiRequest || !hasConsole)
            {
                MessageBox.Show(
                    "PcNinja WinUpdate Tool portable failed to start:\r\n\r\n" + ex.Message,
                    "PcNinja WinUpdate Tool",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
            else
            {
                Console.Error.WriteLine("PcNinja WinUpdate Tool portable failed: " + ex.Message);
            }

            return 1;
        }
    }

    private static string GetExtractRoot()
    {
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(localAppData, "PcNinja", "WinUpdateTool", "Portable", Version);
    }

    private static void ExtractRuntimeFiles(string extractRoot)
    {
        Directory.CreateDirectory(extractRoot);
        string normalizedRoot = Path.GetFullPath(extractRoot + Path.DirectorySeparatorChar);
        Assembly assembly = Assembly.GetExecutingAssembly();

        foreach (PortableResource item in Resources)
        {
            string targetPath = Path.GetFullPath(Path.Combine(extractRoot, item.RelativePath));
            if (!targetPath.StartsWith(normalizedRoot, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("A portable resource resolved outside the runtime directory.");
            }

            string targetDirectory = Path.GetDirectoryName(targetPath);
            if (!String.IsNullOrWhiteSpace(targetDirectory))
            {
                Directory.CreateDirectory(targetDirectory);
            }

            using (Stream resourceStream = assembly.GetManifestResourceStream(item.ResourceName))
            {
                if (resourceStream == null)
                {
                    throw new InvalidOperationException("Embedded portable resource is missing: " + item.ResourceName);
                }

                string temporaryPath = targetPath + ".new";
                using (FileStream output = new FileStream(temporaryPath, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    resourceStream.CopyTo(output);
                }

                if (File.Exists(targetPath))
                {
                    File.Delete(targetPath);
                }

                File.Move(temporaryPath, targetPath);
            }
        }
    }

    private static void ConfigurePortableEnvironment()
    {
        string executablePath = Application.ExecutablePath;
        Environment.SetEnvironmentVariable("PCNINJA_PORTABLE_MODE", "1", EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable("PCNINJA_PORTABLE_SOURCE_EXE", executablePath, EnvironmentVariableTarget.Process);
        Environment.SetEnvironmentVariable("PSExecutionPolicyPreference", "Bypass", EnvironmentVariableTarget.Process);

        string sourceDirectory = Path.GetDirectoryName(executablePath);
        if (!String.IsNullOrWhiteSpace(sourceDirectory))
        {
            Environment.SetEnvironmentVariable("PCNINJA_PORTABLE_SOURCE_DIR", sourceDirectory, EnvironmentVariableTarget.Process);
        }
    }

    private static int RunPowerShellScript(string scriptPath, string[] args, bool uiRequest)
    {
        Dictionary<string, object> parameters = ParsePowerShellParameters(args);

        if (uiRequest && !parameters.ContainsKey("Mode"))
        {
            parameters.Add("Mode", "UI");
        }

        parameters["PortableSourceExe"] = Application.ExecutablePath;

        InitialSessionState sessionState = InitialSessionState.CreateDefault();
        using (Runspace runspace = RunspaceFactory.CreateRunspace(sessionState))
        using (PowerShell powerShell = PowerShell.Create())
        {
            runspace.ApartmentState = System.Threading.ApartmentState.STA;
            runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
            runspace.Open();
            powerShell.Runspace = runspace;
            WriteBootstrapLog("STA PowerShell runspace opened.");

            powerShell.AddCommand(scriptPath);

            foreach (KeyValuePair<string, object> parameter in parameters)
            {
                powerShell.AddParameter(parameter.Key, parameter.Value);
            }

            Collection<PSObject> output = powerShell.Invoke();

            if (!uiRequest)
            {
                foreach (PSObject item in output)
                {
                    if (item != null)
                    {
                        Console.WriteLine(item.ToString());
                    }
                }

                foreach (ErrorRecord error in powerShell.Streams.Error)
                {
                    Console.Error.WriteLine(error.ToString());
                }
            }

            if (powerShell.Streams.Error.Count > 0)
            {
                if (uiRequest)
                {
                    throw new RuntimeException(powerShell.Streams.Error[0].ToString());
                }

                return 1;
            }
        }

        return 0;
    }

    private static void WriteBootstrapLog(string message)
    {
        try
        {
            string logRoot = Path.Combine(GetExtractRoot(), "Logs");
            Directory.CreateDirectory(logRoot);
            string logPath = Path.Combine(logRoot, "PortableLauncher.log");
            File.AppendAllText(logPath, DateTime.Now.ToString("s") + " " + message + Environment.NewLine);
        }
        catch
        {
        }
    }

    private static Dictionary<string, object> ParsePowerShellParameters(string[] args)
    {
        Dictionary<string, object> parameters = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);

        for (int index = 0; index < args.Length; index++)
        {
            string arg = args[index];
            if (String.IsNullOrWhiteSpace(arg) || (!arg.StartsWith("-", StringComparison.Ordinal) && !arg.StartsWith("/", StringComparison.Ordinal)))
            {
                continue;
            }

            string name = arg.TrimStart('-', '/');
            if (String.IsNullOrWhiteSpace(name))
            {
                continue;
            }

            object value = true;
            if ((index + 1) < args.Length)
            {
                string next = args[index + 1];
                if (!String.IsNullOrEmpty(next) && !next.StartsWith("-", StringComparison.Ordinal) && !next.StartsWith("/", StringComparison.Ordinal))
                {
                    value = next;
                    index++;
                }
            }

            parameters[name] = value;
        }

        return parameters;
    }

    private static bool IsUiRequest(string[] args)
    {
        if (args == null || args.Length == 0)
        {
            return true;
        }

        for (int index = 0; index < args.Length - 1; index++)
        {
            if (String.Equals(args[index], "-Mode", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(args[index], "/Mode", StringComparison.OrdinalIgnoreCase))
            {
                return String.Equals(args[index + 1], "UI", StringComparison.OrdinalIgnoreCase);
            }
        }

        return false;
    }

    private static bool IsHelpRequest(string[] args)
    {
        foreach (string arg in args)
        {
            if (String.Equals(arg, "/?", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(arg, "-?", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(arg, "--help", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(arg, "-help", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(arg, "/help", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsAdministrator()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    private static int RelaunchElevated(string[] args)
    {
        List<string> elevatedArgs = new List<string>(args ?? new string[0]);
        if (elevatedArgs.Count == 0)
        {
            elevatedArgs.Add("-Mode");
            elevatedArgs.Add("UI");
        }

        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = Application.ExecutablePath;
        startInfo.Arguments = JoinArguments(elevatedArgs.ToArray());
        startInfo.WorkingDirectory = Path.GetDirectoryName(Application.ExecutablePath);
        startInfo.UseShellExecute = true;
        startInfo.Verb = "runas";
        startInfo.WindowStyle = ProcessWindowStyle.Normal;

        try
        {
            Process.Start(startInfo);
            return 0;
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            if (ex.NativeErrorCode == 1223)
            {
                return 1223;
            }

            throw;
        }
    }

    private static bool TryAttachParentConsole()
    {
        try
        {
            if (!AttachConsole(AttachParentProcess))
            {
                return false;
            }

            StreamWriter output = new StreamWriter(Console.OpenStandardOutput(), Console.OutputEncoding);
            output.AutoFlush = true;
            Console.SetOut(output);

            StreamWriter error = new StreamWriter(Console.OpenStandardError(), Console.OutputEncoding);
            error.AutoFlush = true;
            Console.SetError(error);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static void ShowHelpWindow()
    {
        Application.EnableVisualStyles();

        using (Form form = new Form())
        using (Label note = new Label())
        using (TextBox helpText = new TextBox())
        using (Button okButton = new Button())
        {
            form.Text = "PcNinja WinUpdate Tool CLI Help";
            form.StartPosition = FormStartPosition.CenterScreen;
            form.Size = new Size(780, 560);
            form.MinimumSize = new Size(640, 420);
            form.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            note.Text = "Use from Run, CMD, PowerShell, or deployment tools. The text box is selectable and copyable.";
            note.AutoSize = false;
            note.Location = new Point(18, 18);
            note.Size = new Size(724, 26);

            helpText.Multiline = true;
            helpText.ReadOnly = true;
            helpText.WordWrap = false;
            helpText.ScrollBars = ScrollBars.Both;
            helpText.Font = new Font("Consolas", 9F);
            helpText.Text = GetHelpText();
            helpText.Location = new Point(18, 54);
            helpText.Size = new Size(724, 400);
            helpText.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;

            okButton.Text = "OK";
            okButton.Size = new Size(104, 34);
            okButton.Location = new Point(638, 470);
            okButton.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            okButton.DialogResult = DialogResult.OK;

            form.Controls.Add(note);
            form.Controls.Add(helpText);
            form.Controls.Add(okButton);
            form.AcceptButton = okButton;
            form.ShowDialog();
        }
    }

    private static string GetHelpText()
    {
        string executableName = Path.GetFileName(Application.ExecutablePath);
        if (String.IsNullOrWhiteSpace(executableName))
        {
            executableName = "WinUpdate Tool by PcNinja.exe";
        }

        StringBuilder builder = new StringBuilder();
        builder.AppendFormat("PcNinja WinUpdate Tool Portable {0} ({1})\r\n\r\n", Version, PublicLabel);
        builder.AppendLine("Portable usage:");
        builder.AppendFormat("  {0}\r\n", executableName);
        builder.AppendFormat("  {0} /?\r\n", executableName);
        builder.AppendFormat("  {0} -Mode Status -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode PreviewUpdates -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode DriverAudit -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode CollectLogs -OutputPath C:\\Temp -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode RunUpdates -Silent -RunType Manual -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode ResetWindowsUpdate -ConfirmReset -Json\r\n", executableName);
        builder.AppendFormat("  {0} -Mode AppUpdateCheck -Json\r\n", executableName);
        builder.AppendLine();
        builder.AppendLine("Portable runtime path:");
        builder.AppendFormat("  %LOCALAPPDATA%\\PcNinja\\WinUpdateTool\\Portable\\{0}\r\n", Version);
        return builder.ToString();
    }

    private static string JoinArguments(string[] args)
    {
        if (args == null || args.Length == 0)
        {
            return String.Empty;
        }

        List<string> quoted = new List<string>();
        foreach (string arg in args)
        {
            quoted.Add(QuoteArgument(arg));
        }

        return String.Join(" ", quoted.ToArray());
    }

    private static string QuoteArgument(string arg)
    {
        if (String.IsNullOrEmpty(arg))
        {
            return "\"\"";
        }

        if (arg.IndexOfAny(new[] { ' ', '\t', '"' }) < 0)
        {
            return arg;
        }

        StringBuilder builder = new StringBuilder();
        builder.Append('"');
        int backslashCount = 0;

        foreach (char character in arg)
        {
            if (character == '\\')
            {
                backslashCount++;
                continue;
            }

            if (character == '"')
            {
                builder.Append('\\', (backslashCount * 2) + 1);
                builder.Append('"');
                backslashCount = 0;
                continue;
            }

            builder.Append('\\', backslashCount);
            builder.Append(character);
            backslashCount = 0;
        }

        builder.Append('\\', backslashCount * 2);
        builder.Append('"');
        return builder.ToString();
    }

    private static void TrySetAppUserModelId()
    {
        try
        {
            SetCurrentProcessExplicitAppUserModelID(AppUserModelId);
        }
        catch
        {
        }
    }
}
