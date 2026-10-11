using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Security.Principal;
using Microsoft.Win32;

namespace RIExtensionInstaller
{
    class Program
    {
        private const string ExtensionBundleId = "com.proscriptrunner.dualhost";
        private const string ExtensionDisplayName = "Pro Script Runner (RI Extension Manager)";
        private const string Version = "3.1.0";

        private static string LogFile;
        private static bool IsSilent = false;

        static int Main(string[] args)
        {
            LogFile = Path.Combine(Path.GetTempPath(), "RI_Extension_Installer.log");
            Log("=================================================");
            Log(string.Format("{0} - v{1}", ExtensionDisplayName, Version));
            Log("Installer started: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            Log("=================================================");

            string action = "install";
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i].ToLowerInvariant();
                if (a == "--uninstall" || a == "-u" || a == "/u") action = "uninstall";
                else if (a == "--check" || a == "--status" || a == "-c" || a == "/c") action = "check";
                else if (a == "--silent" || a == "-s" || a == "/s") IsSilent = true;
                else if (a == "--help" || a == "-h" || a == "/?")
                {
                    ShowHelp();
                    return 0;
                }
            }

            Console.Title = ExtensionDisplayName + " Installer";
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("================================================================");
            Console.WriteLine("  " + ExtensionDisplayName);
            Console.WriteLine("  Universal Installer for Adobe Photoshop & Illustrator (2020-2026)");
            Console.WriteLine("================================================================");
            Console.ResetColor();
            Console.WriteLine();

            try
            {
                switch (action)
                {
                    case "uninstall":
                        return DoUninstall();
                    case "check":
                        return DoCheck();
                    default:
                        return DoInstall();
                }
            }
            catch (Exception ex)
            {
                LogError("Unhandled exception: " + ex.Message);
                LogError(ex.StackTrace);
                if (!IsSilent)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("\n[ERROR] An unexpected error occurred: " + ex.Message);
                    Console.ResetColor();
                    Console.WriteLine("Press any key to exit...");
                    Console.ReadKey();
                }
                return 1;
            }
        }

        static void ShowHelp()
        {
            Console.WriteLine("Usage: RI-Extension-Installer.exe [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  (no args)       Install or update the extension interactively");
            Console.WriteLine("  --uninstall, -u Remove the extension cleanly");
            Console.WriteLine("  --check, -c     Check system compatibility and installed Adobe versions");
            Console.WriteLine("  --silent, -s    Run silently without prompting");
            Console.WriteLine("  --help, -h      Show this help information");
        }

        static int DoCheck()
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("[1/3] Detecting Adobe Applications...");
            Console.ResetColor();

            List<string> psVersions = DetectPhotoshopVersions();
            List<string> aiVersions = DetectIllustratorVersions();

            if (psVersions.Count > 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  Photoshop detected: " + string.Join(", ", psVersions.ToArray()));
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkYellow;
                Console.WriteLine("  Photoshop: Not detected in standard locations.");
            }

            if (aiVersions.Count > 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  Illustrator detected: " + string.Join(", ", aiVersions.ToArray()));
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkYellow;
                Console.WriteLine("  Illustrator: Not detected in standard locations.");
            }
            Console.ResetColor();

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[2/3] Checking CEP PlayerDebugMode Registry Status...");
            Console.ResetColor();
            int enabledKeys = 0;
            for (int v = 4; v <= 20; v++)
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\Adobe\CSXS." + v))
                {
                    if (k != null)
                    {
                        object val = k.GetValue("PlayerDebugMode");
                        if (val != null && val.ToString() == "1") enabledKeys++;
                    }
                }
            }
            Console.WriteLine("  Active CSXS Debug keys (HKCU): " + enabledKeys + " / 17");

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[3/3] Checking Extension Installation...");
            Console.ResetColor();
            string targetDir = GetTargetExtensionDir();
            if (Directory.Exists(targetDir) && File.Exists(Path.Combine(targetDir, "CSXS", "manifest.xml")))
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  Extension is currently INSTALLED at:");
                Console.WriteLine("  " + targetDir);
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkYellow;
                Console.WriteLine("  Extension is NOT currently installed.");
            }
            Console.ResetColor();

            Console.WriteLine("\nLog written to: " + LogFile);
            if (!IsSilent)
            {
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
            }
            return 0;
        }

        static int DoInstall()
        {
            Log("Beginning installation process...");

            // 1. Detect Adobe
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("[1/4] Detecting Adobe Applications...");
            Console.ResetColor();
            List<string> psVersions = DetectPhotoshopVersions();
            List<string> aiVersions = DetectIllustratorVersions();
            if (psVersions.Count > 0)
                Console.WriteLine("  Photoshop found: " + string.Join(", ", psVersions.ToArray()));
            if (aiVersions.Count > 0)
                Console.WriteLine("  Illustrator found: " + string.Join(", ", aiVersions.ToArray()));
            if (psVersions.Count == 0 && aiVersions.Count == 0)
                Console.WriteLine("  Note: No active Adobe installation found in registry (will install for all future installations).");

            // 2. Configure Registry
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[2/4] Configuring CEP PlayerDebugMode for Photoshop 2020-2026...");
            Console.ResetColor();
            EnablePlayerDebugMode();
            Console.WriteLine("  [OK] CSXS 4-20 PlayerDebugMode enabled in HKCU.");

            // 3. Locate Payload
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[3/4] Preparing payload and backing up existing installation...");
            Console.ResetColor();
            string targetDir = GetTargetExtensionDir();
            string backupDir = null;

            if (Directory.Exists(targetDir))
            {
                backupDir = CreateBackup(targetDir);
                if (backupDir != null)
                {
                    Console.WriteLine("  [OK] Created backup at: " + Path.GetFileName(backupDir));
                }
            }

            // 4. Install files
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[4/4] Installing extension files to per-user CEP directory...");
            Console.ResetColor();

            bool copySuccess = false;
            try
            {
                if (Directory.Exists(targetDir))
                {
                    Directory.Delete(targetDir, true);
                }
                Directory.CreateDirectory(targetDir);

                // Source resolution: check beside exe, or parent dir, or ZXP
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string zxpFile = FindZxpPackage(baseDir);

                if (File.Exists(Path.Combine(baseDir, "CSXS", "manifest.xml")))
                {
                    Log("Installing directly from directory: " + baseDir);
                    CopyDirectory(baseDir, targetDir);
                    copySuccess = true;
                }
                else if (File.Exists(Path.Combine(baseDir, "..", "CSXS", "manifest.xml")))
                {
                    string parentDir = Path.GetFullPath(Path.Combine(baseDir, ".."));
                    Log("Installing from parent directory: " + parentDir);
                    CopyDirectory(parentDir, targetDir);
                    copySuccess = true;
                }
                else if (!string.IsNullOrEmpty(zxpFile) && File.Exists(zxpFile))
                {
                    Log("Extracting from ZXP package: " + zxpFile);
                    ExtractZxp(zxpFile, targetDir);
                    copySuccess = true;
                }
                else
                {
                    throw new FileNotFoundException("Could not find extension source files or ZXP package.");
                }

                // Clean obsolete duplicate folders if present
                CleanObsoleteFolders();

                // Validate installation
                string manifestPath = Path.Combine(targetDir, "CSXS", "manifest.xml");
                string htmlPath = Path.Combine(targetDir, "index.html");
                if (!File.Exists(manifestPath) || !File.Exists(htmlPath))
                {
                    throw new Exception("Installation verification failed: required files missing.");
                }
            }
            catch (Exception ex)
            {
                LogError("Installation failed: " + ex.Message);
                if (backupDir != null && Directory.Exists(backupDir))
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("  [!] Error occurred: " + ex.Message);
                    Console.WriteLine("  Rolling back from backup...");
                    Console.ResetColor();
                    try
                    {
                        if (Directory.Exists(targetDir)) Directory.Delete(targetDir, true);
                        Directory.CreateDirectory(targetDir);
                        CopyDirectory(backupDir, targetDir);
                        Console.WriteLine("  Rollback completed.");
                    }
                    catch (Exception rbEx)
                    {
                        LogError("Rollback failed: " + rbEx.Message);
                    }
                }
                throw;
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n================================================================");
            Console.WriteLine("  SUCCESS! " + ExtensionDisplayName + " is installed!");
            Console.WriteLine("================================================================");
            Console.ResetColor();

            Console.WriteLine("\nWhere to open in Photoshop:");
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("  * Photoshop 2021 through 2026+:");
            Console.WriteLine("    Window > Extensions (legacy) > Pro Script Runner");
            Console.WriteLine();
            Console.WriteLine("  * Photoshop CC 2014 through 2020:");
            Console.WriteLine("    Window > Extensions > Pro Script Runner");
            Console.WriteLine();
            Console.WriteLine("  * Adobe Illustrator:");
            Console.WriteLine("    Window > Extensions > Pro Script Runner");
            Console.ResetColor();

            Console.WriteLine("\nImportant notes:");
            Console.WriteLine("  1. Restart Photoshop/Illustrator completely if it was open.");
            Console.WriteLine("  2. In Photoshop 2021+, if Extensions is grayed out, ensure:");
            Console.WriteLine("     Edit > Preferences > Plugins > [x] Load Extension Panels is checked.");

            Log("Installation completed successfully.");
            Console.WriteLine("\nLog file: " + LogFile);

            if (!IsSilent)
            {
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
            }
            return 0;
        }

        static int DoUninstall()
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("[1/2] Removing extension folders...");
            Console.ResetColor();

            string extRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"Adobe\CEP\extensions");
            string[] targets = new string[] {
                ExtensionBundleId,
                "ProScriptRunner_DualHost",
                "ProScriptRunner_PS2020",
                "com.proscriptrunner.dualhost.panel"
            };

            int removed = 0;
            foreach (string folderName in targets)
            {
                string p = Path.Combine(extRoot, folderName);
                if (Directory.Exists(p))
                {
                    try
                    {
                        Directory.Delete(p, true);
                        Console.WriteLine("  [OK] Removed: " + folderName);
                        Log("Deleted folder: " + p);
                        removed++;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("  [!] Could not delete " + folderName + ": " + ex.Message);
                        LogError("Delete failed: " + ex.Message);
                    }
                }
            }

            if (removed == 0)
            {
                Console.WriteLine("  No installed Pro Script Runner extension was found.");
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  [OK] Successfully uninstalled " + removed + " folder(s).");
                Console.ResetColor();
            }

            Log("Uninstall completed.");
            if (!IsSilent)
            {
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
            }
            return 0;
        }

        static string GetTargetExtensionDir()
        {
            string extRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"Adobe\CEP\extensions");
            return Path.Combine(extRoot, ExtensionBundleId);
        }

        static string CreateBackup(string targetDir)
        {
            try
            {
                string backupParent = Path.Combine(Path.GetDirectoryName(targetDir), ".backups");
                Directory.CreateDirectory(backupParent);
                string backupDir = Path.Combine(backupParent, ExtensionBundleId + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss"));
                CopyDirectory(targetDir, backupDir);
                Log("Backup created at: " + backupDir);
                return backupDir;
            }
            catch (Exception ex)
            {
                LogError("Backup warning: " + ex.Message);
                return null;
            }
        }

        static void CleanObsoleteFolders()
        {
            try
            {
                string extRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"Adobe\CEP\extensions");
                string[] obsolete = new string[] { "ProScriptRunner_DualHost", "ProScriptRunner_PS2020" };
                foreach (string obs in obsolete)
                {
                    string p = Path.Combine(extRoot, obs);
                    if (Directory.Exists(p))
                    {
                        Directory.Delete(p, true);
                        Log("Cleaned legacy duplicate: " + p);
                    }
                }
            }
            catch (Exception ex)
            {
                LogError("Cleanup warning: " + ex.Message);
            }
        }

        static void CopyDirectory(string sourceDir, string targetDir)
        {
            Directory.CreateDirectory(targetDir);
            foreach (string file in Directory.GetFiles(sourceDir))
            {
                string fileName = Path.GetFileName(file);
                // Skip git, temp, and build artifacts
                if (fileName.StartsWith(".git") || fileName.EndsWith(".tmp") || fileName == "RI-Extension-Installer.exe")
                    continue;

                string dest = Path.Combine(targetDir, fileName);
                File.Copy(file, dest, true);
            }

            foreach (string subDir in Directory.GetDirectories(sourceDir))
            {
                string dirName = Path.GetFileName(subDir);
                // Skip non-runtime directories
                if (dirName == ".git" || dirName == "Installer" || dirName == "scratch" || dirName == ".backups" || dirName == ".system_generated")
                    continue;

                string destSub = Path.Combine(targetDir, dirName);
                CopyDirectory(subDir, destSub);
            }
        }

        static string FindZxpPackage(string startDir)
        {
            string p1 = Path.Combine(startDir, "Installer", "ProScriptRunner_Adobe_DualHost_v1.3.zxp");
            if (File.Exists(p1)) return p1;
            string p2 = Path.Combine(startDir, "ProScriptRunner_Adobe_DualHost_v1.3.zxp");
            if (File.Exists(p2)) return p2;
            string p3 = Path.Combine(startDir, "..", "Installer", "ProScriptRunner_Adobe_DualHost_v1.3.zxp");
            if (File.Exists(p3)) return Path.GetFullPath(p3);
            return null;
        }

        static void ExtractZxp(string zxpPath, string destDir)
        {
            ZipFile.ExtractToDirectory(zxpPath, destDir);
            Log("Extracted ZXP to: " + destDir);
        }

        static void EnablePlayerDebugMode()
        {
            for (int v = 4; v <= 20; v++)
            {
                try
                {
                    string subKey = @"Software\Adobe\CSXS." + v;
                    using (RegistryKey k = Registry.CurrentUser.CreateSubKey(subKey))
                    {
                        if (k != null)
                        {
                            k.SetValue("PlayerDebugMode", "1", RegistryValueKind.String);
                            k.SetValue("LogLevel", "6", RegistryValueKind.String);
                        }
                    }
                }
                catch (Exception ex)
                {
                    LogError("Registry HKCU CSXS." + v + " error: " + ex.Message);
                }
            }

            // If running as Admin, also set HKLM
            if (IsAdministrator())
            {
                for (int v = 4; v <= 20; v++)
                {
                    try
                    {
                        string subKey = @"SOFTWARE\Adobe\CSXS." + v;
                        using (RegistryKey k = Registry.LocalMachine.CreateSubKey(subKey))
                        {
                            if (k != null) k.SetValue("PlayerDebugMode", "1", RegistryValueKind.String);
                        }
                        string wowKey = @"SOFTWARE\WOW6432Node\Adobe\CSXS." + v;
                        using (RegistryKey k = Registry.LocalMachine.CreateSubKey(wowKey))
                        {
                            if (k != null) k.SetValue("PlayerDebugMode", "1", RegistryValueKind.String);
                        }
                    }
                    catch { }
                }
                Log("Configured HKLM registry keys (Admin mode).");
            }
        }

        static bool IsAdministrator()
        {
            try
            {
                WindowsIdentity id = WindowsIdentity.GetCurrent();
                WindowsPrincipal principal = new WindowsPrincipal(id);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        static List<string> DetectPhotoshopVersions()
        {
            List<string> versions = new List<string>();
            string[] keys = new string[] {
                @"Software\Adobe\Photoshop",
                @"SOFTWARE\Adobe\Photoshop",
                @"SOFTWARE\WOW6432Node\Adobe\Photoshop"
            };

            foreach (string root in keys)
            {
                try
                {
                    RegistryKey baseKey = root.StartsWith("Software") ? Registry.CurrentUser.OpenSubKey(root) : Registry.LocalMachine.OpenSubKey(root);
                    if (baseKey != null)
                    {
                        foreach (string sub in baseKey.GetSubKeyNames())
                        {
                            string yr = MapVersionToYear("Photoshop", sub);
                            if (!string.IsNullOrEmpty(yr) && !versions.Contains(yr))
                                versions.Add(yr);
                        }
                    }
                }
                catch { }
            }

            // Filesystem fallback
            string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string[] years = new string[] { "2020", "2021", "2022", "2023", "2024", "2025", "2026" };
            foreach (string y in years)
            {
                if (Directory.Exists(Path.Combine(progFiles, "Adobe", "Adobe Photoshop " + y)))
                {
                    if (!versions.Contains(y)) versions.Add(y);
                }
            }

            return versions;
        }

        static List<string> DetectIllustratorVersions()
        {
            List<string> versions = new List<string>();
            string[] keys = new string[] {
                @"Software\Adobe\Illustrator",
                @"SOFTWARE\Adobe\Illustrator",
                @"SOFTWARE\WOW6432Node\Adobe\Illustrator"
            };

            foreach (string root in keys)
            {
                try
                {
                    RegistryKey baseKey = root.StartsWith("Software") ? Registry.CurrentUser.OpenSubKey(root) : Registry.LocalMachine.OpenSubKey(root);
                    if (baseKey != null)
                    {
                        foreach (string sub in baseKey.GetSubKeyNames())
                        {
                            string yr = MapVersionToYear("Illustrator", sub);
                            if (!string.IsNullOrEmpty(yr) && !versions.Contains(yr))
                                versions.Add(yr);
                        }
                    }
                }
                catch { }
            }

            string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string[] years = new string[] { "2020", "2021", "2022", "2023", "2024", "2025", "2026" };
            foreach (string y in years)
            {
                if (Directory.Exists(Path.Combine(progFiles, "Adobe", "Adobe Illustrator " + y)))
                {
                    if (!versions.Contains(y)) versions.Add(y);
                }
            }

            return versions;
        }

        static string MapVersionToYear(string app, string verStr)
        {
            if (string.IsNullOrEmpty(verStr)) return null;
            if (app == "Photoshop")
            {
                if (verStr.StartsWith("21")) return "2020";
                if (verStr.StartsWith("22")) return "2021";
                if (verStr.StartsWith("23")) return "2022";
                if (verStr.StartsWith("24")) return "2023";
                if (verStr.StartsWith("25")) return "2024";
                if (verStr.StartsWith("26")) return "2025";
                if (verStr.StartsWith("27")) return "2026";
            }
            else if (app == "Illustrator")
            {
                if (verStr.StartsWith("24")) return "2020";
                if (verStr.StartsWith("25")) return "2021";
                if (verStr.StartsWith("26")) return "2022";
                if (verStr.StartsWith("27")) return "2023";
                if (verStr.StartsWith("28")) return "2024";
                if (verStr.StartsWith("29")) return "2025";
                if (verStr.StartsWith("30")) return "2026";
            }
            return null;
        }

        static void Log(string msg)
        {
            try
            {
                File.AppendAllText(LogFile, "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + Environment.NewLine);
            }
            catch { }
        }

        static void LogError(string msg)
        {
            Log("[ERROR] " + msg);
        }
    }
}
