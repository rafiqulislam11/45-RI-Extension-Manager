#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else if (!app.activeDocument.saved) {
    alert("Save the document first.");
} else {
    var d = app.activeDocument;
    var base = d.fullName.parent.fsName + "/" + decodeURI(d.name).replace(/\.[^\.]+$/, "") + ".png";
    var f = new File(base), o = new ExportOptionsPNG24();
    o.antiAliasing = true; o.transparency = true; o.artBoardClipping = true;
    d.exportFile(f, ExportType.PNG24, o);
    alert("PNG exported:\n" + f.fsName);
}
