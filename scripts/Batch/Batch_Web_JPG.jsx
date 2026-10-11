#target photoshop
var folder = Folder.selectDialog("Select a folder");
if (folder) {
    var files = folder.getFiles(function(f) { return f instanceof File && /\.(jpg|jpeg|png|tif|tiff|psd|psb)$/i.test(f.name); });
    if (!files.length) {
        alert("No supported images found.");
    } else {
        var out = new Folder(folder.fsName + "/ProScript Web");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            var d = null;
            try {
                d = app.open(files[i]);
                var name = files[i].name.replace(/\.[^\.]+$/, ""), f = new File(out.fsName + "/" + name + "_web.jpg");
                var o = new JPEGSaveOptions(); o.quality = 8;
                d.saveAs(f, o, true, Extension.LOWERCASE);
                d.close(SaveOptions.DONOTSAVECHANGES); done++;
            } catch(e) { try { if (d) d.close(SaveOptions.DONOTSAVECHANGES); } catch(x){} }
        }
        alert("Batch web export complete: " + done + " of " + files.length);
    }
}
