#target photoshop
var folder = Folder.selectDialog("Select image folder");
if (folder) {
    var files = folder.getFiles(function(f) { return f instanceof File && /\.(jpg|jpeg|png)$/i.test(f.name); });
    if (!files.length) {
        alert("No JPG/PNG files found.");
    } else {
        var max = 24, count = Math.min(files.length, max);
        var cols = 4, cellW = 400, cellH = 300, rows = Math.ceil(count / cols);
        var sheet = app.documents.add(UnitValue(cols * cellW, "px"), UnitValue(rows * cellH, "px"), 72, "ProScript Contact Sheet", NewDocumentMode.RGB, DocumentFill.WHITE);
        for (var i = 0; i < count; i++) {
            var d = null;
            try {
                d = app.open(files[i]);
                d.resizeImage(UnitValue(360, "px"), UnitValue(250, "px"), 72, ResampleMethod.BICUBIC);
                d.activeLayer.duplicate(sheet);
                d.close(SaveOptions.DONOTSAVECHANGES);
                var l = sheet.activeLayer; l.name = files[i].name;
                l.translate((i % cols) * cellW + 20, (Math.floor(i / cols)) * cellH + 20);
            } catch(e) { try { if (d) d.close(SaveOptions.DONOTSAVECHANGES); } catch(x){} }
        }
        alert("Contact sheet created with " + count + " image(s).");
    }
}
