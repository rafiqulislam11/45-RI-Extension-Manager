#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else {
    app.activeDocument.selectObjectsOnActiveArtboard();
    var n = 0;
    for (var i = 0; i < app.selection.length; i++) {
        if (app.selection[i].typename === "TextFrame") {
            app.selection[i].createOutline(); n++;
        }
    }
    app.selection = null;
    alert("Outlined " + n + " text object(s).");
}
