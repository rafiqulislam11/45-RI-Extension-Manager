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
        var cx = (ab[0] + ab[2]) / 2, cy = (ab[1] + ab[3]) / 2;
        var gx = (b[0] + b[2]) / 2, gy = (b[1] + b[3]) / 2;
        var dx = cx - gx, dy = cy - gy;
        for (var j = 0; j < s.length; j++) s[j].translate(dx, dy);
        app.selection = null;
        alert("Artwork centered on active artboard.");
    }
}
