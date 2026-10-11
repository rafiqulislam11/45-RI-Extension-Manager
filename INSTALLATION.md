# RI Extension Manager — Installation & Maintenance Guide

## 1. Quick One-Click Installation (Recommended)

1. **Close Photoshop and Illustrator completely** before installing.
2. Double-click [`RI-Extension-Installer.exe`](file:///c:/Users/RAFIQULISLAM/Desktop/All%20Apps/10-%20APPS%20GENERATE/45-RI-Extension-Manager/RI-Extension-Installer.exe) (or right-click [`INSTALL-NOW.bat`](file:///c:/Users/RAFIQULISLAM/Desktop/All%20Apps/10-%20APPS%20GENERATE/45-RI-Extension-Manager/INSTALL-NOW.bat) and choose **Run as administrator**).
3. The installer will:
   - Detect installed Adobe Photoshop (2020–2026) and Illustrator versions.
   - Configure Windows Registry keys for CSXS 4 through 20 (`PlayerDebugMode = 1`).
   - Create an automated backup of any existing installation.
   - Copy all runtime files to `%APPDATA%\Adobe\CEP\extensions\com.proscriptrunner.dualhost`.
   - Clean up obsolete legacy folders.
   - Verify all essential files are present.
4. Launch Photoshop or Illustrator.
5. Open the panel:
   - **Photoshop 2021 through 2026+:** `Window > Extensions (legacy) > Pro Script Runner`
   - **Photoshop CC 2014 through 2020:** `Window > Extensions > Pro Script Runner`
   - **Adobe Illustrator:** `Window > Extensions > Pro Script Runner`

---

## 2. Command-Line Installer Options

`RI-Extension-Installer.exe` supports command-line switches for unattended or scripted management:

```cmd
:: Install or update interactively
RI-Extension-Installer.exe

:: Silent installation (no interactive prompts, exits on completion)
RI-Extension-Installer.exe --silent

:: Check installation status and detected Adobe versions
RI-Extension-Installer.exe --check

:: Cleanly uninstall extension
RI-Extension-Installer.exe --uninstall

:: Show command-line help
RI-Extension-Installer.exe --help
```

---

## 3. How to Update

When an update is released:
1. Run `RI-Extension-Installer.exe` or `INSTALL-NOW.bat`.
2. The installer automatically detects the existing installation, creates a timestamped snapshot in:
   `%APPDATA%\Adobe\CEP\extensions\.backups\com.proscriptrunner.dualhost_<YYYYMMDD_HHMMSS>`
3. The new payload files are deployed into the extension directory.

---

## 4. Rollback to Previous Version

If you need to revert to an earlier installation:
1. Navigate to the backup directory:
   `%APPDATA%\Adobe\CEP\extensions\.backups\`
2. Locate the desired timestamped backup folder.
3. Copy its contents into:
   `%APPDATA%\Adobe\CEP\extensions\com.proscriptrunner.dualhost\`
4. Restart Photoshop or Illustrator.

---

## 5. Clean Uninstallation

To remove the extension completely:
1. Run:
   ```cmd
   RI-Extension-Installer.exe --uninstall
   ```
2. The installer will remove the extension folder and any legacy duplicates.
3. If you also wish to disable CEP PlayerDebugMode in Windows Registry, run:
   [`disable-cep-debug-mode.bat`](file:///c:/Users/RAFIQULISLAM/Desktop/All%20Apps/10-%20APPS%20GENERATE/45-RI-Extension-Manager/disable-cep-debug-mode.bat).

---

## 6. Troubleshooting & Common Questions

### Q1: The panel does not appear in Photoshop 2021, 2022, 2023, 2024, or 2025.
- **Solution A:** Look under **`Window > Extensions (legacy)`**, NOT `Window > Extensions`. Modern Photoshop places CEP panels under the "legacy" submenu.
- **Solution B:** In Photoshop, go to **`Edit > Preferences > Plugins`** (or `Preferences > Extensions`). Make sure **`Load Extension Panels`** is checked. Restart Photoshop.

### Q2: The panel says "No document open".
- **Solution:** Open any Photoshop image or PSD file. The panel's Active Document Card will automatically update with the document name, resolution, dimensions, and color mode. You can also click the refresh icon (`↻`) at any time.

### Q3: How do I verify the installation log?
- The installer writes an execution log to:
  `%TEMP%\RI_Extension_Installer.log`
