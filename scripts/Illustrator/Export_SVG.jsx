#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else if (!app.activeDocument.saved) {
    alert("Save the document first.");
} else {
    var d = app.activeDocument;
    var base = d.fullName.parent.fsName + "/" + decodeURI(d.name).replace(/\.[^\.]+$/, "") + ".svg";
    var f = new File(base), o = new ExportOptionsSVG();
    o.embedRasterImages = true; o.fontSubsetting = SVGFontSubsetting.GLYPHSUSED;
    d.exportFile(f, ExportType.SVG, o);
    alert("SVG exported:\n" + f.fsName);
}
