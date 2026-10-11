#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else {
    app.activeDocument.selectObjectsOnActiveArtboard();
    if (!app.selection.length) {
        alert("No artwork found on active artboard.");
    } else {
        app.executeMenuCommand("expandStyle");
        app.selection = null;
        alert("Appearance expanded where supported.");
    }
}
