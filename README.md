# Pro Script Runner v1.3.0 — Photoshop 2020 (v1.2.0)

A production-oriented starter CEP panel for Adobe Photoshop 2020 (21.x), modeled after the supplied Pro Script Runner v1.3.0 screenshot.

## Included
## Speed-focused tools added in v1.2.0

### Image workflow
- 2× Upscale
- Gradient Map
- Enhance
- Auto Tone / Contrast / Color
- Noise
- Film Grain
- Sharpen
- Vibrance
- Black & White
- Trim transparent edges
- Social/media canvas presets: 1080×1080, 1080×1350, 1080×1920, 1200×628, 1920×1080
- Custom image resize
- RGB 8-bit conversion

### Layer workflow
- Remove hidden layers
- Cleanup empty top-level art layers
- Duplicate active layer
- Flatten
- Watermark text

### Export workflow
- JPG
- PNG
- Quick Web JPG
- Save PSD copy

### Batch workflow
- Batch JPG
- Batch 2× Upscale
- Batch Web JPG
- Batch file rename
- Contact sheet creation


New image-processing tools in v1.1.0:
- Image Upscale 2× using Photoshop Bicubic Smoother
- Image to Gradient / Gradient Map adjustment layer
- Add Noise with adjustable amount
- Add Film Grain with adjustable amount and soft-light layer
- AI-Style Enhance workflow (non-destructive duplicate + sharpening)
- Auto Tone + Auto Contrast + Auto Color
- Sharpen
- Black & White
- Vibrance adjustment layer
- PNG export
- Batch 2× upscale

- CEP panel manifest targeting Photoshop 2020+
- Dark professional UI
- Account display
- Local credits counter
- Script categories and search-ready script registry
- Photoshop ExtendScript bridge
- Real script execution inside Photoshop
- Document information
- Flatten image
- Duplicate active layer
- Export active document to JPG
- Batch PSD/PSB to JPG
- Activity log
- Settings
- Standalone `.jsx` scripts for Photoshop's File > Scripts menu

## Important

This package is a working local extension starter. The account, credits and Buy More Credits controls are intentionally local/demo-only. For real users, payments and credit enforcement, connect them to your own secure backend. Never trust client-side credit values for billing.

## Universal Windows Installation (Photoshop CC to 2026+)

1. Close Photoshop and Illustrator completely.
2. Right-click [`INSTALL-NOW.bat`](file:///c:/Users/RAFIQULISLAM/Desktop/All%20Apps/10-%20APPS%20GENERATE/45-RI-Extension-Manager/INSTALL-NOW.bat) and select **Run as administrator**.
   - This automatically enables CSXS 4-20 PlayerDebugMode and installs the extension files to `%APPDATA%\Adobe\CEP\extensions\ProScriptRunner_DualHost`.
3. Open your Photoshop or Illustrator:
   - **Photoshop CC 2014 – 2020:** `Window > Extensions > Pro Script Runner`
   - **Photoshop 2021 – 2026+:** `Window > Extensions (legacy) > Pro Script Runner`
   - **Illustrator CC – 2026+:** `Window > Extensions > Pro Script Runner`

If Photoshop does not show the extension:
- Run [`Fix-PS2020-Admin.bat`](file:///c:/Users/RAFIQULISLAM/Desktop/All%20Apps/10-%20APPS%20GENERATE/45-RI-Extension-Manager/Fix-PS2020-Admin.bat) as Administrator.
- In Photoshop 2021+, verify `Edit > Preferences > Plugins > Load Extension Panels` is checked.

## Running standalone scripts

The `.jsx` files in `scripts` can also be copied to a Photoshop Scripts folder and launched from:
`File > Scripts`.

## Production roadmap

- Real authentication API
- Secure server-side credit ledger
- Stripe/PayPal/local payment integration
- Admin dashboard
- Script upload/publishing
- Script versioning
- Per-script credit pricing
- Usage analytics
- License/device management
- Signed ZXP distribution


## v1.3 Adobe Stock Workflow

New tools include:
- 4K UHD and 8K UHD aspect-ratio-preserving upscale presets.
- Custom long-edge upscale.
- Adobe Stock pre-flight: 4–100 MP pixel-range check, RGB/8-bit check, and manual-quality review reminders.
- Stock Prep checklist with optional RGB 8-bit conversion.
- High-quality stock JPG export using a duplicated working document and sRGB conversion attempt, leaving the original document unchanged.
- Batch 4K and 8K upscale/export.

### Important
Photoshop 2020 ExtendScript performs high-quality resampling; it is **not** an AI Super Resolution engine. Upscaling cannot guarantee added real detail or Adobe Stock acceptance. Always inspect the result at 100% and verify Adobe Stock's current contributor requirements before submission.


## Dual Host Support
This build supports Photoshop 2020 (PHSP 21.x) and Adobe Illustrator via the same CEP panel. The extension detects the host application and loads the appropriate ExtendScript runner. Photoshop exposes the Stock/Image/Layer/Batch tools; Illustrator exposes vector-safe document, scaling, artboard, text-outline, appearance and export tools.
