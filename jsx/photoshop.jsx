/* Pro Script Runner - Photoshop ExtendScript Engine (v3.1 Robust Edition)
   Target: Adobe Photoshop 2020 through 2026+ (CEP / CSXS)
   Engineered with defensive checks for Background layers, Color Modes, ActionManager events, and unsaved documents.
*/

var PSR_Photoshop = (function () {

    function parsePayload(payload) {
        if (!payload) return { id: "" };
        if (typeof payload === "object") return payload;
        if (typeof payload === "string") {
            var s = payload.replace(/^\s+|\s+$/g, "");
            if (s.indexOf("{") === -1 && s.indexOf(":") === -1) {
                return { id: s };
            }
            try {
                if (typeof JSON !== "undefined" && JSON && typeof JSON.parse === "function") {
                    var parsed = JSON.parse(s);
                    if (typeof parsed === "string") {
                        try { parsed = JSON.parse(parsed); } catch (e0) { return { id: parsed }; }
                    }
                    return parsed;
                }
            } catch (e1) {}
            try {
                var ev = eval("(" + s + ")");
                if (typeof ev === "string") {
                    try { ev = eval("(" + ev + ")"); } catch (e02) { return { id: ev }; }
                }
                return ev;
            } catch (e2) {}
            return { id: s };
        }
        return { id: "" };
    }

    function hasDoc() {
        return (typeof app !== "undefined" && app.documents && app.documents.length > 0);
    }

    function err(msg) { return "PSR_ERR|" + msg; }
    function ok(msg) { return "PSR_OK|" + msg; }

    // Ensure document is in RGB 8-bit mode for layer & adjustment features
    function ensureRgbMode(d) {
        if (d.mode === DocumentMode.INDEXEDCOLOR || d.mode === DocumentMode.BITMAP) {
            try { d.changeMode(ChangeMode.RGB); } catch (e) {}
        }
    }

    // Safely get active layer, handling Background layers, text, smart objects
    function getSafeWorkingLayer() {
        var d = app.activeDocument;
        ensureRgbMode(d);
        if (!d.activeLayer) {
            if (d.layers.length > 0) d.activeLayer = d.layers[0];
            else throw new Error("No layers found in document.");
        }
        var l = d.activeLayer;

        // If it's a locked Background layer, convert to standard ArtLayer so all layer ops succeed
        if (l.isBackgroundLayer) {
            try {
                l.isBackgroundLayer = false;
                l.name = "Layer 0";
            } catch (bgErr) {}
        }

        // If text, shape, or adjustment layer, try rasterizing if pixel operation is needed
        try {
            if (l.kind === LayerKind.TEXT || l.kind === LayerKind.SOLIDFILL || l.kind === LayerKind.GRADIENTFILL) {
                l.rasterize(RasterizeType.ENTIRELAYER);
            }
        } catch (rErr) {}

        return d.activeLayer;
    }

    function getHostInfo() {
        if (!hasDoc()) {
            return JSON.stringify({
                app: "Photoshop",
                version: (typeof app !== "undefined" && app.version) ? app.version : "Unknown",
                hasDoc: false,
                ready: true,
                doc: null
            });
        }
        try {
            var d = app.activeDocument;
            var w = Math.round(d.width.as("px"));
            var h = Math.round(d.height.as("px"));
            var res = Math.round(d.resolution);
            var modeStr = String(d.mode).replace(/^DocumentMode\./, "");
            var bits = 8;
            try {
                if (d.bitsPerChannel === BitsPerChannelType.SIXTEEN) bits = 16;
                else if (d.bitsPerChannel === BitsPerChannelType.THIRTYTWO) bits = 32;
            } catch (bErr) {}

            return JSON.stringify({
                app: "Photoshop",
                version: app.version,
                hasDoc: true,
                ready: true,
                doc: {
                    name: d.name,
                    width: w,
                    height: h,
                    resolution: res,
                    mode: modeStr,
                    bits: bits,
                    saved: d.saved,
                    path: (d.saved ? d.fullName.fsName : ""),
                    layersCount: d.layers ? d.layers.length : 0
                }
            });
        } catch (e) {
            return JSON.stringify({
                app: "Photoshop",
                version: (app && app.version) ? app.version : "",
                hasDoc: true,
                ready: true,
                doc: null,
                error: e.message
            });
        }
    }

    function documentInfo() {
        if (!hasDoc()) return err("No Photoshop document is open. Open an image or PSD first.");
        var d = app.activeDocument;
        var modeStr = String(d.mode).replace(/^DocumentMode\./, "");
        var bits = 8;
        try {
            if (d.bitsPerChannel === BitsPerChannelType.SIXTEEN) bits = 16;
            else if (d.bitsPerChannel === BitsPerChannelType.THIRTYTWO) bits = 32;
        } catch (bErr) {}

        var info = "Document: " + d.name +
                   "\nDimensions: " + Math.round(d.width.as("px")) + " × " + Math.round(d.height.as("px")) + " px" +
                   "\nResolution: " + Math.round(d.resolution) + " ppi" +
                   "\nColor Mode: " + modeStr + " (" + bits + "-bit)" +
                   "\nLayers: " + (d.layers ? d.layers.length : 1) +
                   "\nSave State: " + (d.saved ? "Saved (" + d.fullName.fsName + ")" : "Unsaved");
        return ok(info);
    }

    function resizeWithin(maxW, maxH, label) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var w = d.width.as("px"), h = d.height.as("px");
        var scale = Math.min(maxW / w, maxH / h);
        if (scale <= 1) {
            return ok("Image (" + Math.round(w) + " × " + Math.round(h) + " px) is already within target " + label + " (" + maxW + " × " + maxH + " px).");
        }
        var nw = Math.round(w * scale), nh = Math.round(h * scale);
        d.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
        return ok("Upscaled to " + nw + " × " + nh + " px (Bicubic Smoother resampling, aspect ratio preserved).");
    }

    function upscale2x(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var nw = Math.round(d.width.as("px") * 2);
        var nh = Math.round(d.height.as("px") * 2);
        d.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
        return ok("Upscaled 2× to " + nw + " × " + nh + " px (Bicubic Smoother interpolation).");
    }

    function upscale4k() { return resizeWithin(3840, 2160, "4K UHD"); }
    function upscale8k() { return resizeWithin(7680, 4320, "8K UHD"); }

    function upscaleCustom(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var edge = (p && p.edge) ? parseFloat(p.edge) : 3840;
        if (isNaN(edge) || edge < 10) edge = 3840;

        var d = app.activeDocument;
        var w = d.width.as("px"), h = d.height.as("px");
        var scale = edge / Math.max(w, h);
        if (scale <= 1) {
            return ok("Image long edge is already " + Math.round(Math.max(w, h)) + " px (>= requested " + edge + " px).");
        }
        var nw = Math.round(w * scale), nh = Math.round(h * scale);
        d.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
        return ok("Custom upscale complete: " + nw + " × " + nh + " px.");
    }

    function imageToGradient() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        ensureRgbMode(d);
        try {
            // Standard ActionManager gradientMap adjustment layer
            var desc = new ActionDescriptor(), ref = new ActionReference();
            ref.putClass(stringIDToTypeID("adjustmentLayer"));
            desc.putReference(charIDToTypeID("null"), ref);
            var ld = new ActionDescriptor(), tr = new ActionReference();
            tr.putClass(stringIDToTypeID("gradientMapClass"));
            ld.putReference(charIDToTypeID("Type"), tr);
            desc.putObject(charIDToTypeID("Usng"), stringIDToTypeID("adjustmentLayer"), ld);
            executeAction(charIDToTypeID("Mk  "), desc, DialogModes.NO);
            return ok("Gradient Map adjustment layer created.");
        } catch (e1) {
            try {
                // Secondary fallback using charID
                var desc2 = new ActionDescriptor(), ref2 = new ActionReference();
                ref2.putClass(charIDToTypeID("AdjL"));
                desc2.putReference(charIDToTypeID("null"), ref2);
                var ld2 = new ActionDescriptor(), tr2 = new ActionReference();
                tr2.putClass(charIDToTypeID("GdMp"));
                ld2.putReference(charIDToTypeID("Type"), tr2);
                desc2.putObject(charIDToTypeID("Usng"), charIDToTypeID("AdjL"), ld2);
                executeAction(charIDToTypeID("Mk  "), desc2, DialogModes.NO);
                return ok("Gradient Map adjustment layer created.");
            } catch (e2) {
                return err("Gradient Map creation failed: " + e2.message);
            }
        }
    }

    function enhance() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        try {
            var d = app.activeDocument;
            ensureRgbMode(d);
            var l = getSafeWorkingLayer();
            var dup = l.duplicate();
            dup.name = "RI Enhanced Detail";
            d.activeLayer = dup;
            try { dup.rasterize(RasterizeType.ENTIRELAYER); } catch (r) {}
            dup.applyUnSharpMask(55, 1.2, 2);
            return ok("Enhanced detail layer created with controlled unsharp mask.");
        } catch (e) {
            return err("Enhance failed: " + e.message);
        }
    }

    function autoEnhance() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        try {
            var d = app.activeDocument;
            ensureRgbMode(d);
            var applied = [];
            try { d.autoTone(); applied.push("Auto Tone"); } catch (e1) {}
            try { d.autoContrast(); applied.push("Auto Contrast"); } catch (e2) {}
            try { d.autoColor(); applied.push("Auto Color"); } catch (e3) {}

            if (applied.length === 0) return err("Auto Enhance was not supported in current mode.");
            return ok(applied.join(" + ") + " applied successfully.");
        } catch (e) {
            return err("Auto enhance failed: " + e.message);
        }
    }

    function addNoise(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var a = (p && p.amount) ? parseFloat(p.amount) : 4;
        if (isNaN(a) || a <= 0) a = 4;
        a = Math.min(20, Math.max(0.1, a));

        try {
            var l = getSafeWorkingLayer();
            l.applyAddNoise(a, NoiseDistribution.GAUSSIAN, true);
            return ok("Gaussian monochromatic noise added: " + a + "%.");
        } catch (e) {
            return err("Add Noise failed: " + e.message);
        }
    }

    function addGrain(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var a = (p && p.amount) ? parseFloat(p.amount) : 3;
        if (isNaN(a) || a <= 0) a = 3;
        a = Math.min(12, Math.max(0.1, a));

        try {
            var d = app.activeDocument;
            var l = getSafeWorkingLayer();
            var dup = l.duplicate();
            dup.name = "RI Film Grain";
            d.activeLayer = dup;
            try { dup.rasterize(RasterizeType.ENTIRELAYER); } catch (r) {}
            dup.applyAddNoise(a, NoiseDistribution.GAUSSIAN, true);
            dup.blendMode = BlendMode.SOFTLIGHT;
            dup.opacity = 35;
            return ok("Film grain layer created (Soft Light blend, " + a + "% noise).");
        } catch (e) {
            return err("Film grain failed: " + e.message);
        }
    }

    function sharpen() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        try {
            var l = getSafeWorkingLayer();
            l.applyUnSharpMask(65, 1.1, 2);
            return ok("Smart edge sharpening applied (Unsharp Mask 65%, 1.1px).");
        } catch (e) {
            return err("Sharpen failed: " + e.message);
        }
    }

    function vibrance() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        ensureRgbMode(d);
        try {
            var desc = new ActionDescriptor(), ref = new ActionReference();
            ref.putClass(stringIDToTypeID("adjustmentLayer"));
            desc.putReference(charIDToTypeID("null"), ref);
            var ld = new ActionDescriptor(), tr = new ActionReference();
            tr.putClass(stringIDToTypeID("vibrance"));
            ld.putReference(charIDToTypeID("Type"), tr);
            desc.putObject(charIDToTypeID("Usng"), stringIDToTypeID("adjustmentLayer"), ld);
            executeAction(charIDToTypeID("Mk  "), desc, DialogModes.NO);
            return ok("Vibrance adjustment layer created.");
        } catch (e) {
            return err("Vibrance adjustment layer failed: " + e.message);
        }
    }

    function grayscale() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        try {
            var l = getSafeWorkingLayer();
            l.desaturate();
            return ok("Active layer desaturated to black & white.");
        } catch (e) {
            return err("Black & white failed: " + e.message);
        }
    }

    function trim() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        try {
            // If document has only Background layer, convert it to standard layer first
            if (d.layers.length === 1 && d.layers[0].isBackgroundLayer) {
                d.layers[0].isBackgroundLayer = false;
            }
            d.trim(TrimType.TRANSPARENT, true, true, true, true);
            return ok("Transparent boundary pixels trimmed.");
        } catch (e) {
            // Fallback: trim top-left pixel color if no transparency
            try {
                d.trim(TrimType.TOPLEFT, true, true, true, true);
                return ok("Outer border trimmed (matched to top-left pixel color).");
            } catch (e2) {
                return err("Trim failed: " + e.message);
            }
        }
    }

    function fitCanvas(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var preset = (p && p.preset) ? String(p.preset) : "1";
        var sizes = {
            "1": [1080, 1080],
            "2": [1080, 1350],
            "3": [1080, 1920],
            "4": [1200, 628],
            "5": [1920, 1080]
        };
        var s = sizes[preset] || [1080, 1080];
        var d = app.activeDocument;
        d.resizeCanvas(UnitValue(s[0], "px"), UnitValue(s[1], "px"), AnchorPosition.MIDDLECENTER);
        return ok("Canvas fitted to preset: " + s[0] + " × " + s[1] + " px.");
    }

    function resizeImage(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var w = (p && p.width) ? parseFloat(p.width) : Math.round(d.width.as("px"));
        var h = (p && p.height) ? parseFloat(p.height) : Math.round(d.height.as("px"));
        if (isNaN(w) || isNaN(h) || w <= 0 || h <= 0) return err("Invalid dimensions.");

        d.resizeImage(UnitValue(w, "px"), UnitValue(h, "px"), d.resolution, ResampleMethod.BICUBIC);
        return ok("Image resized to " + Math.round(w) + " × " + Math.round(h) + " px.");
    }

    function convertRGB8() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        try {
            var changes = [];
            if (d.mode !== DocumentMode.RGB) {
                d.changeMode(ChangeMode.RGB);
                changes.push("Mode -> RGB");
            }
            if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) {
                d.bitsPerChannel = BitsPerChannelType.EIGHT;
                changes.push("Depth -> 8-bit");
            }
            if (changes.length === 0) {
                return ok("Document is already RGB 8-bit.");
            }
            return ok("Document converted: " + changes.join(", ") + ".");
        } catch (e) {
            return err("RGB 8-bit conversion failed: " + e.message);
        }
    }

    function stockQualityCheck() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var w = Math.round(d.width.as("px")), h = Math.round(d.height.as("px"));
        var mp = (w * h) / 1000000;
        var issues = [], passed = [];

        if (mp < 4) issues.push("Pixel count (" + mp.toFixed(2) + " MP) is below Adobe Stock minimum (4 MP).");
        else passed.push("Pixel count: " + mp.toFixed(2) + " MP (>= 4 MP).");

        if (mp > 100) issues.push("Pixel count (" + mp.toFixed(2) + " MP) exceeds 100 MP maximum.");

        if (d.mode !== DocumentMode.RGB) issues.push("Color mode is " + d.mode + " (Adobe Stock requires RGB).");
        else passed.push("Color mode: RGB.");

        if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) issues.push("Bit depth is not 8-bit.");
        else passed.push("Bit depth: 8-bit.");

        if (d.resolution < 72) issues.push("Resolution is " + d.resolution + " ppi (recommended >= 72 ppi).");
        else passed.push("Resolution: " + Math.round(d.resolution) + " ppi.");

        var summary = "ADOBE STOCK PRE-FLIGHT RESULTS:\n";
        if (issues.length === 0) {
            summary += "STATUS: PASS (All technical specifications met)\n• " + passed.join("\n• ");
        } else {
            summary += "STATUS: " + issues.length + " WARNING(S)\nWARNINGS:\n• " + issues.join("\n• ") + "\n\nPASSED:\n• " + passed.join("\n• ");
        }
        return ok(summary);
    }

    function stockPrep() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var changes = [];
        if (d.mode !== DocumentMode.RGB) {
            d.changeMode(ChangeMode.RGB);
            changes.push("Converted to RGB");
        }
        if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) {
            d.bitsPerChannel = BitsPerChannelType.EIGHT;
            changes.push("Converted to 8-bit");
        }
        var msg = "Stock preparation completed.\n";
        msg += changes.length ? "Normalizations applied: " + changes.join(", ") + "\n" : "Mode and bit depth are already optimal (RGB 8-bit).\n";
        msg += "Note: Inspect sharpness, noise, and halos at 100% zoom before final upload.";
        return ok(msg);
    }

    function removeHidden() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var count = 0;

        function cleanCollection(col) {
            for (var i = col.length - 1; i >= 0; i--) {
                try {
                    var item = col[i];
                    if (!item.visible) {
                        item.remove();
                        count++;
                    } else if (item.typename === "LayerSet") {
                        cleanCollection(item.layers);
                    }
                } catch (e) {}
            }
        }

        cleanCollection(d.layers);
        return ok("Removed " + count + " hidden layer(s) and group(s).");
    }

    function cleanupEmpty() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var count = 0;
        for (var i = d.layers.length - 1; i >= 0; i--) {
            var l = d.layers[i];
            try {
                if (!l.isBackgroundLayer && l.typename === "ArtLayer" &&
                    l.bounds[0].as("px") === l.bounds[2].as("px") &&
                    l.bounds[1].as("px") === l.bounds[3].as("px")) {
                    l.remove();
                    count++;
                }
            } catch (e) {}
        }
        return ok("Cleaned up " + count + " empty layer(s).");
    }

    function duplicateLayer() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        if (!d.activeLayer) {
            if (d.layers.length > 0) d.activeLayer = d.layers[0];
            else return err("No layers found in document.");
        }
        var dup = d.activeLayer.duplicate();
        d.activeLayer = dup;
        return ok("Duplicated active layer: '" + dup.name + "'.");
    }

    function flatten() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        if (d.layers.length === 1 && d.layers[0].isBackgroundLayer) {
            return ok("Document is already flattened (single Background layer).");
        }
        d.flatten();
        return ok("Document flattened into single background layer.");
    }

    function watermark(p) {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var text = (p && p.text) ? String(p.text).trim() : "Pro Script Runner";
        if (!text) text = "Pro Script Runner";

        try {
            var d = app.activeDocument;
            ensureRgbMode(d);
            var w = d.width.as("px"), h = d.height.as("px");

            var layer = d.artLayers.add();
            layer.kind = LayerKind.TEXT;
            layer.name = "RI Watermark - " + text;

            var fontSize = Math.max(14, Math.min(60, Math.round(w / 35)));
            layer.textItem.size = UnitValue(fontSize, "px");
            layer.textItem.contents = text;

            // Position at bottom-right corner safely within bounds
            var estWidth = text.length * fontSize * 0.55;
            var posX = Math.max(20, w - estWidth - 30);
            var posY = Math.max(fontSize + 10, h - 30);
            layer.textItem.position = [UnitValue(posX, "px"), UnitValue(posY, "px")];
            layer.opacity = 50;

            return ok("Watermark added: '" + text + "' (Bottom-Right, 50% opacity).");
        } catch (e) {
            return err("Watermark failed: " + e.message);
        }
    }

    function getExportFolder(d) {
        if (d.saved) {
            try { return d.fullName.parent; } catch (e) {}
        }
        return Folder.myDocuments;
    }

    function getBaseFileName(d) {
        return decodeURI(d.name).replace(/\.[^\.]+$/, "");
    }

    function exportJpg() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_export.jpg");
        var o = new JPEGSaveOptions();
        o.quality = 10;
        o.embedColorProfile = true;
        d.saveAs(f, o, true, Extension.LOWERCASE);
        return ok("JPG exported successfully:\n" + f.fsName);
    }

    function exportPng() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_export.png");
        var o = new PNGSaveOptions();
        d.saveAs(f, o, true, Extension.LOWERCASE);
        return ok("PNG exported successfully:\n" + f.fsName);
    }

    function exportWeb() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_web.jpg");
        var o = new JPEGSaveOptions();
        o.quality = 8;
        o.embedColorProfile = true;
        d.saveAs(f, o, true, Extension.LOWERCASE);
        return ok("Web-optimized JPG exported:\n" + f.fsName);
    }

    function exportStockJpg() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var w = d.width.as("px"), h = d.height.as("px"), mp = (w * h) / 1000000;
        if (mp < 4 || mp > 100) {
            return err("Stock JPG export stopped: pixel count is " + mp.toFixed(2) + " MP (Adobe Stock range is 4–100 MP).");
        }
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_stock.jpg");
        var work = null;
        try {
            work = d.duplicate();
            if (work.mode !== DocumentMode.RGB) work.changeMode(ChangeMode.RGB);
            if (work.bitsPerChannel !== BitsPerChannelType.EIGHT) work.bitsPerChannel = BitsPerChannelType.EIGHT;
            try { work.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, true); } catch (pErr) {}
            var o = new JPEGSaveOptions();
            o.quality = 12;
            o.embedColorProfile = true;
            work.saveAs(f, o, true, Extension.LOWERCASE);
            work.close(SaveOptions.DONOTSAVECHANGES);
            work = null;
            var mb = f.length / 1048576;
            return ok("Stock-ready JPG exported:\n" + f.fsName + "\nFile size: " + mb.toFixed(2) + " MB");
        } catch (e) {
            if (work) {
                try { work.close(SaveOptions.DONOTSAVECHANGES); } catch (wErr) {}
            }
            return err("Stock JPG export failed: " + e.message);
        }
    }

    function saveCopyPsd() {
        if (!hasDoc()) return err("No Photoshop document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_copy.psd");
        var o = new PhotoshopSaveOptions();
        d.saveAs(f, o, true, Extension.LOWERCASE);
        return ok("PSD copy saved:\n" + f.fsName);
    }

    function batchJpg() {
        var folder = Folder.selectDialog("Select folder containing PSD/PSB files");
        if (!folder) return err("Batch operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(psd|psb)$/i.test(f.name);
        });
        if (!files.length) return err("No PSD or PSB files found in selected folder.");
        var out = new Folder(folder.fsName + "/ProScript_JPG");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            try {
                var doc = app.open(files[i]);
                var name = files[i].name.replace(/\.[^\.]+$/, "");
                var f = new File(out.fsName + "/" + name + ".jpg");
                var o = new JPEGSaveOptions();
                o.quality = 10;
                doc.saveAs(f, o, true, Extension.LOWERCASE);
                doc.close(SaveOptions.DONOTSAVECHANGES);
                done++;
            } catch (e) {}
        }
        return ok("Batch JPG complete: " + done + " of " + files.length + " exported to:\n" + out.fsName);
    }

    function batchUpscale() {
        var folder = Folder.selectDialog("Select folder of images to upscale 2×");
        if (!folder) return err("Batch operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(psd|psb|jpg|jpeg|png|tif|tiff)$/i.test(f.name);
        });
        if (!files.length) return err("No supported image files found.");
        var out = new Folder(folder.fsName + "/ProScript_Upscaled_2x");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            try {
                var doc = app.open(files[i]);
                var nw = Math.round(doc.width.as("px") * 2);
                var nh = Math.round(doc.height.as("px") * 2);
                doc.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), doc.resolution, ResampleMethod.BICUBICSMOOTHER);
                var name = files[i].name.replace(/\.[^\.]+$/, "");
                var f = new File(out.fsName + "/" + name + "_2x.jpg");
                var o = new JPEGSaveOptions();
                o.quality = 10;
                doc.saveAs(f, o, true, Extension.LOWERCASE);
                doc.close(SaveOptions.DONOTSAVECHANGES);
                done++;
            } catch (e) {}
        }
        return ok("Batch 2× complete: " + done + " of " + files.length + " upscaled to:\n" + out.fsName);
    }

    function batchResizeWithin(maxW, maxH, label) {
        var folder = Folder.selectDialog("Select folder of images for " + label + " batch");
        if (!folder) return err("Batch operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(psd|psb|jpg|jpeg|png|tif|tiff)$/i.test(f.name);
        });
        if (!files.length) return err("No supported image files found.");
        var out = new Folder(folder.fsName + "/ProScript_" + label);
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            try {
                var doc = app.open(files[i]);
                var w = doc.width.as("px"), h = doc.height.as("px");
                var scale = Math.min(maxW / w, maxH / h);
                if (scale > 1) {
                    var nw = Math.round(w * scale), nh = Math.round(h * scale);
                    doc.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), doc.resolution, ResampleMethod.BICUBICSMOOTHER);
                }
                var name = files[i].name.replace(/\.[^\.]+$/, "");
                var f = new File(out.fsName + "/" + name + "_" + label.toLowerCase().replace(/ /g, "_") + ".jpg");
                var o = new JPEGSaveOptions();
                o.quality = 10;
                doc.saveAs(f, o, true, Extension.LOWERCASE);
                doc.close(SaveOptions.DONOTSAVECHANGES);
                done++;
            } catch (e) {}
        }
        return ok("Batch " + label + " complete: " + done + " of " + files.length + " processed to:\n" + out.fsName);
    }

    function batchUpscale4k() { return batchResizeWithin(3840, 2160, "4K_UHD"); }
    function batchUpscale8k() { return batchResizeWithin(7680, 4320, "8K_UHD"); }

    function batchWeb() {
        var folder = Folder.selectDialog("Select folder of images for web export");
        if (!folder) return err("Batch operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(jpg|jpeg|png|tif|tiff|psd|psb)$/i.test(f.name);
        });
        if (!files.length) return err("No supported images found.");
        var out = new Folder(folder.fsName + "/ProScript_Web");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            try {
                var doc = app.open(files[i]);
                var name = files[i].name.replace(/\.[^\.]+$/, "");
                var f = new File(out.fsName + "/" + name + "_web.jpg");
                var o = new JPEGSaveOptions();
                o.quality = 8;
                doc.saveAs(f, o, true, Extension.LOWERCASE);
                doc.close(SaveOptions.DONOTSAVECHANGES);
                done++;
            } catch (e) {}
        }
        return ok("Batch web export complete: " + done + " of " + files.length + " exported to:\n" + out.fsName);
    }

    function batchRename() {
        var folder = Folder.selectDialog("Select folder containing image files to rename");
        if (!folder) return err("Operation cancelled.");
        var prefix = prompt("Filename prefix:", "Design");
        if (prefix === null) return err("Operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(jpg|jpeg|png|tif|tiff|psd|psb)$/i.test(f.name);
        });
        if (!files.length) return err("No supported files found.");
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            try {
                var extMatch = files[i].name.match(/\.[^\.]+$/);
                var ext = extMatch ? extMatch[0] : "";
                var numStr = ("000" + (i + 1)).slice(-3);
                var target = new File(folder.fsName + "/" + prefix + "_" + numStr + ext);
                if (files[i].rename(target.name)) done++;
            } catch (e) {}
        }
        return ok("Batch renamed " + done + " of " + files.length + " file(s).");
    }

    function contactSheet() {
        var folder = Folder.selectDialog("Select image folder for Contact Sheet");
        if (!folder) return err("Operation cancelled.");
        var files = folder.getFiles(function (f) {
            return f instanceof File && /\.(jpg|jpeg|png)$/i.test(f.name);
        });
        if (!files.length) return err("No JPG/PNG files found.");
        var count = Math.min(files.length, 24);
        var cols = 4, cellW = 400, cellH = 300, rows = Math.ceil(count / cols);
        var sheet = app.documents.add(UnitValue(cols * cellW, "px"), UnitValue(rows * cellH, "px"), 72, "ProScript Contact Sheet", NewDocumentMode.RGB, DocumentFill.WHITE);
        for (var i = 0; i < count; i++) {
            try {
                var doc = app.open(files[i]);
                doc.resizeImage(UnitValue(360, "px"), UnitValue(250, "px"), 72, ResampleMethod.BICUBIC);
                doc.activeLayer.duplicate(sheet);
                doc.close(SaveOptions.DONOTSAVECHANGES);
                var l = sheet.activeLayer;
                l.name = files[i].name;
                l.translate((i % cols) * cellW + 20, Math.floor(i / cols) * cellH + 20);
            } catch (e) {}
        }
        return ok("Contact sheet created with " + count + " thumbnail image(s).");
    }

    function run(payload) {
        var p = parsePayload(payload);
        try {
            switch (p.id) {
                case "doc-info": return documentInfo();
                case "upscale-2x": return upscale2x(p);
                case "upscale-4k": return upscale4k();
                case "upscale-8k": return upscale8k();
                case "upscale-custom": return upscaleCustom(p);
                case "image-to-gradient": return imageToGradient();
                case "enhance": return enhance();
                case "auto-enhance": return autoEnhance();
                case "add-noise": return addNoise(p);
                case "add-grain": return addGrain(p);
                case "sharpen": return sharpen();
                case "vibrance": return vibrance();
                case "grayscale": return grayscale();
                case "trim": return trim();
                case "fit-canvas": return fitCanvas(p);
                case "resize-image": return resizeImage(p);
                case "convert-rgb8": return convertRGB8();
                case "stock-quality-check": return stockQualityCheck();
                case "stock-prep": return stockPrep();
                case "remove-hidden": return removeHidden();
                case "cleanup-empty": return cleanupEmpty();
                case "duplicate-layer": return duplicateLayer();
                case "flatten": return flatten();
                case "watermark": return watermark(p);
                case "export-jpg": return exportJpg();
                case "export-png": return exportPng();
                case "export-web": return exportWeb();
                case "export-stock-jpg": return exportStockJpg();
                case "save-copy-psd": return saveCopyPsd();
                case "batch-jpg": return batchJpg();
                case "batch-upscale": return batchUpscale();
                case "batch-upscale-4k": return batchUpscale4k();
                case "batch-upscale-8k": return batchUpscale8k();
                case "batch-web": return batchWeb();
                case "batch-rename": return batchRename();
                case "contact-sheet": return contactSheet();
                default: return err("Unknown Photoshop script action: " + p.id);
            }
        } catch (e) {
            return err(e.message);
        }
    }

    return {
        getHostInfo: getHostInfo,
        run: run
    };
})();

// Attach to globals for both direct and host-based evaluation
if (typeof $.global !== "undefined") {
    $.global.PSR_Photoshop = PSR_Photoshop;
    if (typeof $.global.ProScriptRunner === "undefined") {
        $.global.ProScriptRunner = PSR_Photoshop;
    }
}
