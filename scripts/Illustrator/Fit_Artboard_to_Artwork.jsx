#target illustrator
if (!app.documents.length) {
    alert("No Illustrator document is open.");
} else {
    var d = app.activeDocument;
    d.selectObjectsOnActiveArtboard();
    var s = d.selection;
    if (!s || !s.length) {
        alert("No artwork found on active artboard.");
    } else {
        var b = s[0].visibleBounds.slice(0);
        for (var i = 1; i < s.length; i++) {
            var x = s[i].visibleBounds;
            b[0] = Math.min(b[0], x[0]); b[1] = Math.max(b[1], x[1]);
            b[2] = Math.max(b[2], x[2]); b[3] = Math.min(b[3], x[3]);
        }
        var ab = d.artboards[d.artboards.getActiveArtboardIndex()];
        ab.artboardRect = [b[0], b[1], b[2], b[3]];
        app.selection = null;
        alert("Active artboard fitted to artwork bounds.");
    }
}
