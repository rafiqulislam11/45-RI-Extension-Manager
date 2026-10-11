#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else if (!app.activeDocument.saved) {
    alert("Save the document first.");
} else {
    var d = app.activeDocument;
    var base = d.fullName.parent.fsName + "/" + decodeURI(d.name).replace(/\.[^\.]+$/, "") + "_copy.ai";
    var f = new File(base), o = new IllustratorSaveOptions();
    d.saveCopyAs(f, o);
    alert("AI copy saved:\n" + f.fsName);
}
