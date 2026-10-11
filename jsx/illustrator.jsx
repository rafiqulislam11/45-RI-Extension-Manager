/* Pro Script Runner - Illustrator ExtendScript Engine
   Target: Adobe Illustrator 2020 through 2026+ (CEP / CSXS)
*/

var PSR_Illustrator = (function () {

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

    function getHostInfo() {
        if (!hasDoc()) {
            return JSON.stringify({
                app: "Illustrator",
                version: (typeof app !== "undefined" && app.version) ? app.version : "Unknown",
                hasDoc: false,
                ready: true,
                doc: null
            });
        }
        try {
            var d = app.activeDocument;
            var abIndex = d.artboards.getActiveArtboardIndex();
            var abRect = d.artboards[abIndex].artboardRect;
            var w = Math.round(Math.abs(abRect[2] - abRect[0]));
            var h = Math.round(Math.abs(abRect[1] - abRect[3]));

            return JSON.stringify({
                app: "Illustrator",
                version: app.version,
                hasDoc: true,
                ready: true,
                doc: {
                    name: d.name,
                    width: w,
                    height: h,
                    artboards: d.artboards.length,
                    items: d.pageItems.length,
                    saved: d.saved,
                    path: (d.saved ? d.fullName.fsName : "")
                }
            });
        } catch (e) {
            return JSON.stringify({
                app: "Illustrator",
                version: (app && app.version) ? app.version : "",
                hasDoc: true,
                ready: true,
                doc: null,
                error: e.message
            });
        }
    }

    function docInfo() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        var ab = d.artboards[d.artboards.getActiveArtboardIndex()].artboardRect;
        var w = Math.round(Math.abs(ab[2] - ab[0])), h = Math.round(Math.abs(ab[1] - ab[3]));
        return ok("Document: " + d.name +
                  "\nActive Artboard: " + w + " × " + h + " pt" +
                  "\nArtboards: " + d.artboards.length +
                  "\nPage Items: " + d.pageItems.length +
                  "\nStatus: " + (d.saved ? "Saved" : "Unsaved"));
    }

    function scaleArtwork(factor, label) {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        try {
            d.selectObjectsOnActiveArtboard();
            if (d.selection && d.selection.length) {
                for (var i = 0; i < d.selection.length; i++) {
                    try {
                        d.selection[i].resize(factor * 100, factor * 100, true, true, true, true, factor * 100, Transformation.CENTER);
                    } catch (e) {
                        d.selection[i].resize(factor * 100, factor * 100);
                    }
                }
                app.selection = null;
                return ok("Artwork scaled " + label + " (" + Math.round(factor * 100) + "%).");
            }
            return err("No artwork found on the active artboard.");
        } catch (e) {
            app.selection = null;
            return err("Scale failed: " + e.message);
        }
    }

    function upscale2x() { return scaleArtwork(2, "2×"); }

    function fitArtboard() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        try {
            d.selectObjectsOnActiveArtboard();
            var s = d.selection;
            if (!s || !s.length) {
                app.selection = null;
                return err("No artwork found on the active artboard.");
            }
            var b = s[0].visibleBounds.slice(0);
            for (var i = 1; i < s.length; i++) {
                var x = s[i].visibleBounds;
                b[0] = Math.min(b[0], x[0]);
                b[1] = Math.max(b[1], x[1]);
                b[2] = Math.max(b[2], x[2]);
                b[3] = Math.min(b[3], x[3]);
            }
            var ab = d.artboards[d.artboards.getActiveArtboardIndex()];
            ab.artboardRect = [b[0], b[1], b[2], b[3]];
            app.selection = null;
            return ok("Active artboard fitted to artwork bounds: " +
                      Math.round(Math.abs(b[2] - b[0])) + " × " + Math.round(Math.abs(b[1] - b[3])) + " pt.");
        } catch (e) {
            app.selection = null;
            return err("Fit artboard failed: " + e.message);
        }
    }

    function alignCenter() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        try {
            d.selectObjectsOnActiveArtboard();
            var s = d.selection;
            if (!s || !s.length) {
                app.selection = null;
                return err("No artwork found on the active artboard.");
            }
            var b = s[0].visibleBounds.slice(0);
            for (var i = 1; i < s.length; i++) {
                var x = s[i].visibleBounds;
                b[0] = Math.min(b[0], x[0]);
                b[1] = Math.max(b[1], x[1]);
                b[2] = Math.max(b[2], x[2]);
                b[3] = Math.min(b[3], x[3]);
            }
            var ab = d.artboards[d.artboards.getActiveArtboardIndex()].artboardRect;
            var cx = (ab[0] + ab[2]) / 2, cy = (ab[1] + ab[3]) / 2;
            var gx = (b[0] + b[2]) / 2, gy = (b[1] + b[3]) / 2;
            var dx = cx - gx, dy = cy - gy;
            for (var j = 0; j < s.length; j++) {
                s[j].translate(dx, dy);
            }
            app.selection = null;
            return ok("Artwork centered on active artboard.");
        } catch (e) {
            app.selection = null;
            return err("Center failed: " + e.message);
        }
    }

    function outlineText() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        try {
            app.activeDocument.selectObjectsOnActiveArtboard();
            var n = 0;
            for (var i = 0; i < app.selection.length; i++) {
                if (app.selection[i].typename === "TextFrame") {
                    app.selection[i].createOutline();
                    n++;
                }
            }
            app.selection = null;
            return ok("Outlined " + n + " text object(s).");
        } catch (e) {
            app.selection = null;
            return err("Outline text failed: " + e.message);
        }
    }

    function expandAppearance() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        try {
            app.activeDocument.selectObjectsOnActiveArtboard();
            if (!app.selection.length) {
                app.selection = null;
                return err("No artwork found on the active artboard.");
            }
            app.executeMenuCommand("expandStyle");
            app.selection = null;
            return ok("Appearance expanded on selected artboard items.");
        } catch (e) {
            app.selection = null;
            return err("Expand appearance failed: " + e.message);
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

    function saveAI() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + "_copy.ai");
        var o = new IllustratorSaveOptions();
        d.saveAs(f, o);
        return ok("AI copy saved:\n" + f.fsName);
    }

    function exportSVG() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + ".svg");
        var o = new ExportOptionsSVG();
        o.embedRasterImages = true;
        o.fontSubsetting = SVGFontSubsetting.GLYPHSUSED;
        d.exportFile(f, ExportType.SVG, o);
        return ok("SVG exported:\n" + f.fsName);
    }

    function exportPNG() {
        if (!hasDoc()) return err("No Illustrator document is open.");
        var d = app.activeDocument;
        var folder = getExportFolder(d);
        var base = folder.fsName + "/" + getBaseFileName(d);
        var f = new File(base + ".png");
        var o = new ExportOptionsPNG24();
        o.antiAliasing = true;
        o.transparency = true;
        o.artBoardClipping = true;
        d.exportFile(f, ExportType.PNG24, o);
        return ok("PNG exported:\n" + f.fsName);
    }

    function run(payload) {
        var p = parsePayload(payload);
        try {
            switch (p.id) {
                case "ai-doc-info": return docInfo();
                case "ai-upscale-2x": return upscale2x();
                case "ai-fit-artboard": return fitArtboard();
                case "ai-center-artwork": return alignCenter();
                case "ai-outline-text": return outlineText();
                case "ai-expand-appearance": return expandAppearance();
                case "ai-save-copy": return saveAI();
                case "ai-export-svg": return exportSVG();
                case "ai-export-png": return exportPNG();
                default: return err("This script action is not supported in Illustrator: " + p.id);
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

// Attach to globals
if (typeof $.global !== "undefined") {
    $.global.PSR_Illustrator = PSR_Illustrator;
    if (typeof $.global.ProScriptRunner === "undefined") {
        $.global.ProScriptRunner = PSR_Illustrator;
    }
}
