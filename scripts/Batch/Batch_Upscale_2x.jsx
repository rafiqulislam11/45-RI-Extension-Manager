#target photoshop
var folder = Folder.selectDialog("Select a folder containing images");
if (folder) {
    var files = folder.getFiles(function(f) { return f instanceof File && /\.(psd|psb|jpg|jpeg|png|tif|tiff)$/i.test(f.name); });
    if (!files.length) {
        alert("No supported images found.");
    } else {
        var out = new Folder(folder.fsName + "/ProScript Upscaled 2x");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            var d = null;
            try {
                d = app.open(files[i]);
                var w = d.width.as("px") * 2, h = d.height.as("px") * 2;
                d.resizeImage(UnitValue(w, "px"), UnitValue(h, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
                var name = files[i].name.replace(/\.[^\.]+$/, ""), f = new File(out.fsName + "/" + name + "_2x.jpg");
                var o = new JPEGSaveOptions(); o.quality = 10;
                d.saveAs(f, o, true, Extension.LOWERCASE);
                d.close(SaveOptions.DONOTSAVECHANGES); done++;
            } catch(e) { try { if (d) d.close(SaveOptions.DONOTSAVECHANGES); } catch(x){} }
        }
        alert("Batch 2× complete: " + done + " of " + files.length);
    }
}
