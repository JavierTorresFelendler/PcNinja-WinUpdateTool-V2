using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

[assembly: AssemblyTitle("PcNinja WinUpdate Tool MSI Maintenance")]
[assembly: AssemblyCompany("PcNinja")]
[assembly: AssemblyProduct("PcNinja WinUpdate Tool")]
[assembly: AssemblyCopyright("Copyright (c) PcNinja")]
[assembly: AssemblyVersion("2.2.6.0")]
[assembly: AssemblyFileVersion("2.2.6.0")]
[assembly: AssemblyInformationalVersion("V2.2.6")]

internal static class MsiActionHost
{
    private static int Main(string[] args)
    {
        try
        {
            if (args == null || args.Length == 0)
            {
                return 0;
            }

            string action = args[0];
            if (String.Equals(action, "close", StringComparison.OrdinalIgnoreCase))
            {
                CloseRunningProcesses();
                return 0;
            }

            if (String.Equals(action, "configure", StringComparison.OrdinalIgnoreCase))
            {
                return RunHiddenPowerShell(GetScriptPath(args), Slice(args, 2));
            }

            if (String.Equals(action, "cleanup", StringComparison.OrdinalIgnoreCase))
            {
                return RunHiddenPowerShell(GetScriptPath(args), Slice(args, 2));
            }

            return 2;
        }
        catch (Exception ex)
        {
            WriteMaintenanceLog("host", String.Empty, ex.ToString(), 1);
            return 1;
        }
    }

    private static void CloseRunningProcesses()
    {
        foreach (string processName in new[] { "PcNinja.WinUpdateTool", "PcNinja.WinUpdateTool.Cli" })
        {
            foreach (Process process in Process.GetProcessesByName(processName))
            {
                try
                {
                    if (process.Id != Process.GetCurrentProcess().Id)
                    {
                        process.Kill();
                        process.WaitForExit(5000);
                    }
                }
                catch
                {
                }
                finally
                {
                    process.Dispose();
                }
            }
        }
    }

    private static string GetScriptPath(string[] args)
    {
        if (args == null || args.Length < 2 || String.IsNullOrWhiteSpace(args[1]))
        {
            throw new ArgumentException("The MSI maintenance script path was not supplied.");
        }

        return Path.GetFullPath(args[1]);
    }

    private static int RunHiddenPowerShell(string scriptPath, string[] args)
    {
        string scriptName = Path.GetFileName(scriptPath);
        if (!File.Exists(scriptPath))
        {
            WriteMaintenanceLog(scriptName, String.Empty, "Maintenance script was not found: " + scriptPath, 2);
            return 2;
        }

        string applicationDirectory = Path.GetDirectoryName(scriptPath);
        if (String.IsNullOrWhiteSpace(applicationDirectory))
        {
            applicationDirectory = AppDomain.CurrentDomain.BaseDirectory;
        }

        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe");

        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = powershell;
        startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " +
            QuoteArgument(scriptPath) + " " + JoinArguments(args);
        startInfo.WorkingDirectory = applicationDirectory;
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
        startInfo.RedirectStandardOutput = true;
        startInfo.RedirectStandardError = true;

        using (Process process = Process.Start(startInfo))
        {
            Task<string> outputTask = process.StandardOutput.ReadToEndAsync();
            Task<string> errorTask = process.StandardError.ReadToEndAsync();
            process.WaitForExit();
            Task.WaitAll(outputTask, errorTask);

            WriteMaintenanceLog(scriptName, outputTask.Result, errorTask.Result, process.ExitCode);
            return process.ExitCode;
        }
    }

    private static void WriteMaintenanceLog(string action, string output, string error, int exitCode)
    {
        try
        {
            string logRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "PcNinja",
                "WinUpdateTool",
                "Logs");
            Directory.CreateDirectory(logRoot);
            string logPath = Path.Combine(logRoot, "MsiActionHost.log");

            StringBuilder entry = new StringBuilder();
            entry.AppendFormat("{0:s} Action={1} ExitCode={2}\r\n", DateTime.Now, action, exitCode);
            if (!String.IsNullOrWhiteSpace(output))
            {
                entry.AppendLine(output.TrimEnd());
            }
            if (!String.IsNullOrWhiteSpace(error))
            {
                entry.AppendLine(error.TrimEnd());
            }

            File.AppendAllText(logPath, entry.ToString());
        }
        catch
        {
        }
    }

    private static string[] Slice(string[] args, int startIndex)
    {
        if (args == null || args.Length <= startIndex)
        {
            return new string[0];
        }

        string[] result = new string[args.Length - startIndex];
        Array.Copy(args, startIndex, result, 0, result.Length);
        return result;
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
}
