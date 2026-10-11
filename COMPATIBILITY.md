# RI Extension Manager — Host Compatibility Specification

## 1. Adobe Technology Architecture

This project is built using Adobe's **Common Extensibility Platform (CEP)**, consisting of:
- **Chromium Embedded Framework (CEF)** for the HTML5/CSS/JavaScript user interface panel.
- **ExtendScript (Adobe ES3 JavaScript engine)** for direct document manipulation, layer creation, resampling, and file export.
- **CSXS Infrastructure** for inter-process communication between the web panel and the host application.

### CEP vs. UXP Status
- In **Photoshop 2020 (v21)**, CEP is the standard native extension framework.
- In **Photoshop 2021 through 2026+ (v22–v27)**, Adobe introduced the Unified Extensibility Platform (UXP), but continues to support legacy CEP panels under the menu item `Window > Extensions (legacy)`.
- In **Illustrator 2020 through 2026+ (v24–v30)**, CEP panels remain fully supported under `Window > Extensions`.

---

## 2. Adobe Photoshop Compatibility Matrix

| Version | Marketing Name | CSXS Version | Support Level | Menu Location | Notes |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **v21.x** | Photoshop 2020 | CSXS 9 / 10 | **Fully Supported** | `Window > Extensions` | Native CEP; full ActionDescriptor & DOM support. |
| **v22.x** | Photoshop 2021 | CSXS 10 | **Fully Supported** | `Window > Extensions (legacy)` | Requires "Load Extension Panels" in Preferences. |
| **v23.x** | Photoshop 2022 | CSXS 10 / 11 | **Fully Supported** | `Window > Extensions (legacy)` | Requires "Load Extension Panels" in Preferences. |
| **v24.x** | Photoshop 2023 | CSXS 11 | **Fully Supported** | `Window > Extensions (legacy)` | Requires "Load Extension Panels" in Preferences. |
| **v25.x** | Photoshop 2024 | CSXS 11 / 12 | **Fully Supported** | `Window > Extensions (legacy)` | Tested on local environment; full DOM support. |
| **v26.x** | Photoshop 2025 | CSXS 12 | **Fully Supported** | `Window > Extensions (legacy)` | Supported via CSXS 12 registry key. |
| **v27.x** | Photoshop 2026+ | CSXS 13 | **Compatible** | `Window > Extensions (legacy)` | Future-proofed via CSXS 4–20 registry loops. |

---

## 3. Adobe Illustrator Compatibility Matrix

| Version | Marketing Name | CSXS Version | Support Level | Menu Location | Notes |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **v24.x** | Illustrator 2020 | CSXS 9 / 10 | **Fully Supported** | `Window > Extensions` | Tested on local environment; vector DOM active. |
| **v25.x** | Illustrator 2021 | CSXS 10 | **Fully Supported** | `Window > Extensions` | Full artboard & vector transform support. |
| **v26.x** | Illustrator 2022 | CSXS 10 / 11 | **Fully Supported** | `Window > Extensions` | Full artboard & vector transform support. |
| **v27.x** | Illustrator 2023 | CSXS 11 | **Fully Supported** | `Window > Extensions` | Full artboard & vector transform support. |
| **v28.x** | Illustrator 2024 | CSXS 11 / 12 | **Fully Supported** | `Window > Extensions` | Full artboard & vector transform support. |
| **v29.x** | Illustrator 2025 | CSXS 12 | **Fully Supported** | `Window > Extensions` | Full artboard & vector transform support. |
| **v30.x** | Illustrator 2026+ | CSXS 13 | **Compatible** | `Window > Extensions` | Future-proofed via CSXS 4–20 registry loops. |

---

## 4. Feature Availability by Host Application

### Photoshop Exclusive Features (36 Automations)
- **Image Operations:** Document Information, Image Upscale 2× (Bicubic Smoother), Upscale to 4K UHD, Upscale to 8K UHD, Custom Long-Edge Upscale, Image to Gradient Map, Detail & Edge Enhance, Auto Tone/Contrast/Color, Add Noise, Add Film Grain, Smart Sharpen, Vibrance Boost, Black & White conversion, Trim Transparent Pixels, Fit Canvas Presets, Custom Resize Image, Convert to RGB 8-bit.
- **Stock Pre-Flight:** Adobe Stock Quality Check (Megapixel, RGB, 8-bit, PPI), Stock Prep Checklist.
- **Layer Workflow:** Remove Hidden Layers, Cleanup Empty Layers, Duplicate Active Layer, Flatten Document, Add Text Watermark.
- **Export Workflow:** Export Active as JPG, Export Active as PNG, Quick Web JPG, Stock High-Quality JPG, Save Copy as PSD.
- **Batch Processing:** Batch PSD/PSB to JPG, Batch Upscale 2×, Batch Upscale 4K, Batch Upscale 8K, Batch Web JPG, Batch Sequential Rename, Contact Sheet Creation.

### Illustrator Exclusive Features (9 Automations)
- Document Information (artboard size, count, page items count)
- Scale Artwork 2× (uniform transform from center)
- Fit Artboard to Artwork bounds
- Center Artwork on Active Artboard
- Convert Text Objects to Outlines
- Expand Appearance
- Save Copy as AI file
- Export SVG with font subsetting
- Export Transparent PNG-24

---

## 5. Known Adobe CEP Limitations & Mitigations

1. **Photoshop 2021+ Legacy Menu Placement:**  
   Adobe relocated all CEP panels to `Window > Extensions (legacy)` to distinguish them from UXP plugins.  
   *Mitigation:* The installer and documentation clearly instruct users on locating the legacy menu.
2. **"Extensions (legacy)" Grayed Out:**  
   In some fresh installations of Photoshop 2021–2026, legacy extensions are disabled by default.  
   *Mitigation:* Enable in `Edit > Preferences > Plugins > [x] Load Extension Panels` and restart Photoshop.
3. **Upscaling Technology Transparency:**  
   ExtendScript does not have access to Adobe Camera Raw AI Super Resolution or neural filters without proprietary SDK access.  
   *Mitigation:* All upscaling automations are explicitly documented as high-quality **Bicubic Smoother interpolation**, preserving aspect ratio without making false claims of artificial neural generation.
