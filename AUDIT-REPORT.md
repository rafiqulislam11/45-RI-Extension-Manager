# RI Extension Manager — Deep Technical Audit Report
**Project:** RI Extension Manager / Pro Script Runner  
**Audit Date:** 2026-10-11  
**Architecture:** Adobe CEP (Common Extensibility Platform) Extension (CSXS 7.0 / Chromium CEF / ExtendScript ES3)  
**Target Hosts:** Adobe Photoshop 2020–2026+ (21.x–27.x), Adobe Illustrator 2020–2026+ (24.x–30.x)

---

## 1. Executive Summary

A comprehensive architectural and code audit of the RI Extension Manager project revealed why the Script Runner previously failed to execute actions in Adobe Photoshop and Illustrator. The core failure was **not merely cosmetic**; it was caused by **ExtendScript engine scope isolation (`#targetengine`)**, **unregistered host script objects**, **unhandled host differences**, **modal blocking dialogs in ExtendScript**, and **missing per-user installer automation**.

All defects have been isolated, documented with root causes and file/line references, repaired, and validated through an automated test suite.

---

## 2. Defects, Root Causes, and Applied Fixes

### Defect 1: ExtendScript `#targetengine "ProScriptRunnerHost"` Engine Scope Mismatch
- **Files & Lines:** `jsx/host.jsx` (Lines 2, 74)
- **Severity:** **CRITICAL (Blocker)**
- **Root Cause:**  
  ExtendScript supports named execution engines via `#targetengine "<name>"`. In Adobe Photoshop, CEP's JavaScript-to-ExtendScript bridge (`csInterface.evalScript(...)`) evaluates code in the **default transient/main engine** unless specifically instructed otherwise.  
  Because `host.jsx` declared `#targetengine "ProScriptRunnerHost"`, `ProScriptRunner` was instantiated inside an isolated engine. When `js/main.js` called `evalInHost('typeof ProScriptRunner')` or `evalInHost('ProScriptRunner.run(...)')`, Photoshop searched the default engine, found `undefined`, and returned `"EvalScript error."` / `"ReferenceError: ProScriptRunner is undefined"`.
- **Fix:**  
  Removed the isolated `#targetengine "ProScriptRunnerHost"` directive from `host.jsx`. The bootstrap now runs in the standard CEP engine and attaches `ProScriptRunner` directly to `$.global.ProScriptRunner` and global scope, making it immediately visible to all `csInterface.evalScript()` calls.
- **Test Status:** **PASS** (Verified in both automated JS test suite and ExtendScript harness).

---

### Defect 2: Host Dispatcher Naming Inconsistency (`PSR_Photoshop` vs `ProScriptRunner`)
- **Files & Lines:** `jsx/photoshop.jsx` (Line 4), `jsx/illustrator.jsx` (Line 4), `jsx/runner.jsx` (Line 6)
- **Severity:** **HIGH**
- **Root Cause:**  
  `jsx/photoshop.jsx` defined its engine as `var PSR_Photoshop = (function () { ... })()`, and `jsx/illustrator.jsx` defined `PSR_Illustrator`. Neither file bound itself to `ProScriptRunner` if loaded directly or without `host.jsx`. Additionally, `runner.jsx` contained an older, competing definition of `ProScriptRunner` that lacked the JSON polyfill and host fallback.
- **Fix:**  
  1. Both `photoshop.jsx` and `illustrator.jsx` now attach to `$.global` and automatically assign `$.global.ProScriptRunner` if not already defined.
  2. `host.jsx` dynamically inspects `app.name` and delegates calls to the appropriate engine.
  3. `runner.jsx` was rewritten as a clean compatibility alias delegating to `PSR_Photoshop`.
- **Test Status:** **PASS**

---

### Defect 3: Cross-Host `#include` Collision
- **Files & Lines:** `jsx/host.jsx` (Lines 43–44)
- **Severity:** **HIGH**
- **Root Cause:**  
  `host.jsx` statically used `#include "photoshop.jsx"` followed by `#include "illustrator.jsx"`. ExtendScript `#include` operates at preprocessor time, embedding all Illustrator code inside Photoshop and vice-versa. While protected inside closures, evaluating Illustrator-specific DOM APIs or Photoshop ActionDescriptors in the wrong application created potential syntax and runtime instability.
- **Fix:**  
  Replaced static dual `#include` with dynamic runtime evaluation based on `app.name`:
  - When running inside Photoshop, only `photoshop.jsx` is evaluated.
  - When running inside Illustrator, only `illustrator.jsx` is evaluated.
- **Test Status:** **PASS**

---

### Defect 4: ExtendScript Modal Dialog Blocking (`confirm()` / `prompt()`)
- **Files & Lines:** `jsx/photoshop.jsx` (Lines 61, 87, 113, 153, 163, 212, 224, 246, 258, 278, 284)
- **Severity:** **HIGH**
- **Root Cause:**  
  Multiple ExtendScript functions used synchronous modal dialogs (`prompt()`, `confirm()`, `alert()`). In Photoshop 2020 through 2026, modal dialogs invoked during a CEP `evalScript` call can freeze or lock up the Chromium CEF message loop. Moreover, in modern CEP runtimes with strict modal sandboxing, modal ExtendScript dialogs can steal OS focus or crash the panel.
- **Fix:**  
  Refactored all parameter-accepting functions (`upscaleCustom`, `addNoise`, `addGrain`, `fitCanvas`, `resizeImage`, `watermark`) to accept parameters passed directly through the JSON payload from the HTML UI. The UI now provides clean, non-blocking input controls (text inputs, dimension fields, presets dropdown), eliminating the need for blocking modal prompts in ExtendScript.
- **Test Status:** **PASS**

---

### Defect 5: Unsaved Document Export Failure
- **Files & Lines:** `jsx/photoshop.jsx` (Lines 299, 307, 315, 323, 344), `jsx/illustrator.jsx` (Lines 100, 105, 110)
- **Severity:** **MEDIUM**
- **Root Cause:**  
  When an export script (`exportJpg`, `exportPng`, `exportWeb`, `saveCopyPsd`) was run on an unsaved document (`!d.saved`), the code immediately aborted with `"Save the document before JPG export"` because `d.fullName` does not exist for unsaved files.
- **Fix:**  
  Added a defensive `getExportFolder(d)` helper. If the document has not yet been saved to disk, the exporter falls back safely to the user's `My Documents` folder (`Folder.myDocuments`) and reports the complete saved file path in the activity log.
- **Test Status:** **PASS**

---

### Defect 6: Mock Browser Canvas & Misleading "Credits" System
- **Files & Lines:** `index.html` (Lines 13–53, 156–160), `js/main.js` (Lines 150–250, 364–366, 386–388)
- **Severity:** **MEDIUM** (Design Integrity & Transparency)
- **Root Cause:**  
  The extension UI displayed a mock "Open Image" file upload canvas with a fake before/after split viewer, despite running inside Photoshop. Furthermore, an artificial "1833 credits" balance was deducted each time a user ran a local ExtendScript automation on their own computer, displaying "Insufficient Credits" if balance reached zero.
- **Fix:**  
  1. Replaced the fake web canvas with a **Live Active Document Card** that queries Photoshop in real time (`ProScriptRunner.getHostInfo()`), displaying the real file name, dimensions, ppi, color mode, bit depth, and save state.
  2. Removed artificial demo credits and deductions. All 44 local automations are genuinely functional with no artificial paywall.
  3. Replaced mock buttons with real action controls and added a live **Activity Log** displaying exact timestamps, execution statuses, and generated output paths.
- **Test Status:** **PASS**

---

### Defect 7: Installation Paths and CSXS Registry Gaps
- **Files & Lines:** `INSTALL-NOW.bat`, `install-unsigned-extension.bat`, `Fix-PS2020-Admin.bat`
- **Severity:** **HIGH**
- **Root Cause:**  
  1. Batch scripts previously copied files to `%APPDATA%\Adobe\CEP\extensions\ProScriptRunner_DualHost`, whereas the bundle ID declared in `manifest.xml` is `com.proscriptrunner.dualhost`. This created orphaned duplicate folders.
  2. Registry loops previously only set CSXS 7–16, omitting CSXS 4–6 and future CSXS 17–20 (Photoshop 2025/2026+).
  3. Batch scripts required manual elevated prompts when standard per-user installs only require `HKCU` permissions.
- **Fix:**  
  1. Built a native compiled executable installer (`RI-Extension-Installer.exe`) using the built-in Microsoft .NET C# compiler (`csc.exe`).
  2. Detects installed Photoshop 2020–2026 and Illustrator versions from Registry and `Program Files`.
  3. Configures `PlayerDebugMode = "1"` across CSXS 4 through 20.
  4. Automatically backs up existing installations before updating and supports automated rollback.
  5. Cleans obsolete duplicate folders (`ProScriptRunner_DualHost`, `ProScriptRunner_PS2020`).
- **Test Status:** **PASS**

---

## 3. Summary Audit Table

| ID | Component | File & Line | Severity | Root Cause | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **DEF-01** | Bridge | `jsx/host.jsx:2` | CRITICAL | `#targetengine "ProScriptRunnerHost"` scoped runner away from `evalScript` | **FIXED / PASS** |
| **DEF-02** | Dispatcher | `jsx/photoshop.jsx:4` | HIGH | `PSR_Photoshop` was not bound to `ProScriptRunner` in default engine | **FIXED / PASS** |
| **DEF-03** | Bridge | `jsx/host.jsx:43-44` | HIGH | Unconditional `#include` of Illustrator code in Photoshop and vice versa | **FIXED / PASS** |
| **DEF-04** | ExtendScript | `jsx/photoshop.jsx` | HIGH | Modal `prompt()` and `confirm()` blocked CEP CEF message loop | **FIXED / PASS** |
| **DEF-05** | Export | `jsx/photoshop.jsx:299` | MEDIUM | Unsaved documents crashed export scripts due to missing `d.fullName` | **FIXED / PASS** |
| **DEF-06** | UI / UX | `index.html`, `js/main.js` | MEDIUM | Fake before/after canvas, demo credits lock, and non-functional export button | **FIXED / PASS** |
| **DEF-07** | Installer | `INSTALL-NOW.bat` | HIGH | Target folder name mismatch; CSXS registry version range incomplete | **FIXED / PASS** |
| **DEF-08** | Manifest | `CSXS/manifest.xml:12` | MEDIUM | Host version min-bound was overly restrictive (`19.0`) | **FIXED / PASS** |
