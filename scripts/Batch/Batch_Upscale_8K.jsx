#target photoshop
var folder = Folder.selectDialog("Select a folder containing images");
if (folder) {
    var files = folder.getFiles(function(f) { return f instanceof File && /\.(psd|psb|jpg|jpeg|png|tif|tiff)$/i.test(f.name); });
    if (!files.length) {
        alert("No supported images found.");
    } else {
        var out = new Folder(folder.fsName + "/ProScript 8K");
        if (!out.exists) out.create();
        var done = 0;
        for (var i = 0; i < files.length; i++) {
            var d = null;
            try {
                d = app.open(files[i]);
                var w = d.width.as("px"), h = d.height.as("px"), scale = Math.min(7680 / w, 4320 / h);
                if (scale > 1) d.resizeImage(UnitValue(Math.round(w * scale), "px"), UnitValue(Math.round(h * scale), "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
                var name = files[i].name.replace(/\.[^\.]+$/, "") + "_8k.jpg";
                var f = new File(out.fsName + "/" + name), o = new JPEGSaveOptions(); o.quality = 12; o.embedColorProfile = true;
                d.saveAs(f, o, true, Extension.LOWERCASE);
                d.close(SaveOptions.DONOTSAVECHANGES); done++;
            } catch(e) { try { if (d) d.close(SaveOptions.DONOTSAVECHANGES); } catch(x){} }
        }
        alert("Batch 8K complete: " + done + " of " + files.length);
    }
}
