# RI Extension Manager v3.0 Audit

## Verified foundation
- Existing v2.0 WPF/PowerShell manager retained.
- ZXP install, batch install, extension scan, Adobe detection, enable/disable and uninstall code retained.
- Bundled Pro Script Runner inspected.

## Registered real features
- Photoshop: 35
- Illustrator: 9
- Total: 44

## v3 additions in this package
- `Data/FeatureRegistry.json` — machine-readable feature/action registry.
- `Data/Feature-Library.html` — searchable Feature Library.
- `Open-Feature-Library.bat` — one-click launcher.
- v3 documentation and changelog.

## Important
The manager can catalog and inspect the real actions exposed by the bundled CEP extension. Direct execution still occurs inside the Adobe CEP panel through its existing `evalScript` bridge; the manager does not fake execution.
