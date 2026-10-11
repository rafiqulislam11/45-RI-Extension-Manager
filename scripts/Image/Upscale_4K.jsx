#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else {
    var d = app.activeDocument;
    var w = d.width.as("px"), h = d.height.as("px");
    var scale = Math.min(3840 / w, 2160 / h);
    if (scale <= 1) {
        alert("Image is already within 4K UHD: " + Math.round(w) + " × " + Math.round(h) + " px.");
    } else {
        var nw = Math.round(w * scale), nh = Math.round(h * scale);
        d.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
        alert("Upscaled to 4K UHD: " + nw + " × " + nh + " px.");
    }
}
