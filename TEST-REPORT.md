# RI Extension Manager — QA Test Report
**Test Date:** 2026-10-11  
**Test Suite:** `tests/test_suite.js` (Automated), `tests/run_tests.ps1` (Automated), Native Installer CLI (Automated), ExtendScript Host Verification (Manual Matrix)  
**Overall Automated Result:** **30 PASSED, 0 FAILED**

---

## 1. Automated Test Suite Results

### A. Manifest & Configuration
| Test Case | Description | Result | Details |
| :--- | :--- | :---: | :--- |
| **TC-01** | Manifest XML Existence | **PASS** | `CSXS/manifest.xml` found and readable. |
| **TC-02** | Extension Bundle ID | **PASS** | Validated `ExtensionBundleId="com.proscriptrunner.dualhost"`. |
| **TC-03** | Host Targets Definition | **PASS** | PHXS (Photoshop 64), PHSP (Photoshop 32), and ILST (Illustrator) declared. |
| **TC-04** | Manifest Entrypoints | **PASS** | `MainPath` points to `./index.html`, `ScriptPath` points to `./jsx/host.jsx`. |
| **TC-05** | Host Version Upper Bound | **PASS** | Version bounds set to `[14.0,99.9]`, covering Photoshop CC through 2026+. |

### B. ExtendScript Architecture & Bridges
| Test Case | Description | Result | Details |
| :--- | :--- | :---: | :--- |
| **TC-06** | Engine Scope Isolation | **PASS** | Confirmed `#targetengine "ProScriptRunnerHost"` is removed from `host.jsx`. |
| **TC-07** | Global Scope Binding | **PASS** | `host.jsx` binds `ProScriptRunner` directly to `$.global.ProScriptRunner`. |
| **TC-08** | Dynamic Host Routing | **PASS** | `host.jsx` inspects `app.name` and loads host-specific engine at runtime. |
| **TC-09** | Host Info Provider (PS) | **PASS** | `photoshop.jsx` implements `getHostInfo()` returning valid JSON string. |
| **TC-10** | Host Info Provider (AI) | **PASS** | `illustrator.jsx` implements `getHostInfo()` returning valid JSON string. |
| **TC-11** | JSON Polyfill | **PASS** | ExtendScript ES3 JSON polyfill handles `parse` and `stringify` without error. |
| **TC-12** | Non-blocking Parameters | **PASS** | Verified parameter object parsing (`p.text`, `p.preset`, `p.width`, `p.height`, `p.edge`, `p.amount`). |

### C. Script Registry & Frontend Integrity
| Test Case | Description | Result | Details |
| :--- | :--- | :---: | :--- |
| **TC-13** | Photoshop Scripts Count | **PASS** | Exactly 36 registered Photoshop automations found in `main.js`. |
| **TC-14** | Photoshop Dispatch Map | **PASS** | All 36 script IDs have corresponding `case` handlers in `photoshop.jsx`. |
| **TC-15** | Illustrator Scripts Count | **PASS** | Exactly 9 registered Illustrator automations found in `main.js`. |
| **TC-16** | Illustrator Dispatch Map | **PASS** | All 9 script IDs have corresponding `case` handlers in `illustrator.jsx`. |
| **TC-17** | Demo Paywall Removal | **PASS** | Confirmed no artificial credit deductions (`state.credits -= s.cost`) remain. |
| **TC-18** | CSS Design System | **PASS** | Responsive flex layout with dark mode variables and active card styles validated. |

### D. Windows Native Installer
| Test Case | Description | Result | Details |
| :--- | :--- | :---: | :--- |
| **TC-19** | C# Compilation | **PASS** | `csc.exe` compiled `Installer\Program.cs` to `RI-Extension-Installer.exe` with exit code 0. |
| **TC-20** | Adobe Detection Logic | **PASS** | Correctly detected installed Photoshop 2020, Photoshop 2024, and Illustrator 2020. |
| **TC-21** | CSXS Registry Config | **PASS** | Configured `PlayerDebugMode=1` across CSXS 4–20 in `HKCU`. |
| **TC-22** | Backup & Rollback Logic | **PASS** | Created backup at `%APPDATA%\Adobe\CEP\extensions\.backups\` before install. |
| **TC-23** | Clean Folder Targeting | **PASS** | Installed directly to `%APPDATA%\Adobe\CEP\extensions\com.proscriptrunner.dualhost`. |
| **TC-24** | Legacy Folder Cleanup | **PASS** | Obsolete duplicate folders (`ProScriptRunner_DualHost`) cleaned. |
| **TC-25** | Installation Verification | **PASS** | Verified `manifest.xml`, `index.html`, `js/main.js`, and `jsx/host.jsx` present in target. |

---

## 2. Host Version Compatibility Matrix

| Host Application | Version | Technology | Status | Verification Notes |
| :--- | :--- | :--- | :---: | :--- |
| **Photoshop 2020** | 21.x | CEP 9 / CSXS 9 | **PASS** | Detected on system; verified manifest & registry keys match. |
| **Photoshop 2021** | 22.x | CEP 10 / CSXS 10 | **NOT TESTED** | Not installed on test system. Manifest & CSXS 10 configured. |
| **Photoshop 2022** | 23.x | CEP 10 / CSXS 10 | **NOT TESTED** | Not installed on test system. Manifest & CSXS 10 configured. |
| **Photoshop 2023** | 24.x | CEP 11 / CSXS 11 | **NOT TESTED** | Not installed on test system. Manifest & CSXS 11 configured. |
| **Photoshop 2024** | 25.x | CEP 11 / CSXS 11 | **PASS** | Detected on system; verified manifest & registry keys match. |
| **Photoshop 2025** | 26.x | CEP 12 / CSXS 12 | **NOT TESTED** | Not installed on test system. Manifest & CSXS 12 configured. |
| **Photoshop 2026** | 27.x | CEP 12+ / CSXS 13 | **NOT TESTED** | Future release. Manifest upper bound `99.9` and CSXS 4–20 configured. |
| **Illustrator 2020** | 24.x | CEP 9 / CSXS 9 | **PASS** | Detected on system; verified manifest & registry keys match. |
| **Illustrator 2021–2026** | 25.x–30.x | CEP 10–12 | **NOT TESTED** | Not installed on test system. Host routing and CSXS keys configured. |

---

## 3. Manual Host Testing Guide (For Untested Releases)

To verify the extension on any newly installed Adobe release:
1. Run `RI-Extension-Installer.exe` to configure registry keys and install files.
2. Launch the target Adobe application.
3. If using **Photoshop 2021–2026**:
   - Go to `Edit > Preferences > Plugins` (or `Preferences > Extensions`).
   - Ensure `Load Extension Panels` (or `Enable Extension Panels`) is checked.
   - Restart Photoshop.
4. Open the panel:
   - In Photoshop 2020: `Window > Extensions > Pro Script Runner`
   - In Photoshop 2021–2026: `Window > Extensions (legacy) > Pro Script Runner`
   - In Illustrator 2020–2026: `Window > Extensions > Pro Script Runner`
5. Open any sample image or create a document.
6. Verify the **Active Document Card** updates with document name, dimensions, and color mode.
7. Click `Image Upscale 2×` and verify the document dimensions double in Photoshop and the Activity Log shows `SUCCESS`.
