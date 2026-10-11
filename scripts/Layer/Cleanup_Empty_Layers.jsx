#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else if (confirm("Remove empty top-level art layers?")) {
    var d = app.activeDocument, count = 0;
    for (var i = d.layers.length - 1; i >= 0; i--) {
        var l = d.layers[i];
        try {
            if (l.typename === "ArtLayer" && l.bounds[0].as("px") === l.bounds[2].as("px") && l.bounds[1].as("px") === l.bounds[3].as("px")) {
                l.remove(); count++;
            }
        } catch(e){}
    }
    alert("Removed " + count + " empty layer(s).");
}
