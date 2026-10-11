#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else {
    var d = app.activeDocument;
    d.selectObjectsOnActiveArtboard();
    if (d.selection && d.selection.length) {
        for (var i = 0; i < d.selection.length; i++) {
            try { d.selection[i].resize(200, 200, true, true, true, true, 200, Transformation.CENTER); } catch(e) { d.selection[i].resize(200, 200); }
        }
        app.selection = null;
        alert("Artwork scaled 2× (200%).");
    } else {
        alert("No artwork found on active artboard.");
    }
}
