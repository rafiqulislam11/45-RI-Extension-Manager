#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else {
    var d = app.activeDocument, ab = d.artboards[d.artboards.getActiveArtboardIndex()].artboardRect;
    var w = Math.abs(ab[2] - ab[0]), h = Math.abs(ab[1] - ab[3]);
    alert("Document: " + d.name + "\nActive Artboard: " + Math.round(w) + " × " + Math.round(h) + " pt\nArtboards: " + d.artboards.length + "\nItems: " + d.pageItems.length);
}
