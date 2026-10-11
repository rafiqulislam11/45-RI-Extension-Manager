#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else {
    var edge = prompt("Maximum long edge in pixels:", "3840");
    if (edge !== null) {
        edge = parseFloat(edge);
        if (isNaN(edge) || edge < 1) {
            alert("Invalid long-edge size.");
        } else {
            var d = app.activeDocument, w = d.width.as("px"), h = d.height.as("px"), scale = edge / Math.max(w, h);
            if (scale <= 1) {
                alert("Image is already at or above requested long edge.");
            } else {
                var nw = Math.round(w * scale), nh = Math.round(h * scale);
                d.resizeImage(UnitValue(nw, "px"), UnitValue(nh, "px"), d.resolution, ResampleMethod.BICUBICSMOOTHER);
                alert("Custom upscale complete: " + nw + " × " + nh + " px.");
            }
        }
    }
}
