#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else {
    var d = app.activeDocument, w = Math.round(d.width.as("px")), h = Math.round(d.height.as("px"));
    var mp = (w * h) / 1000000, issues = [], notes = [];
    if (mp < 4) issues.push("Pixel count is below 4 MP.");
    if (mp > 100) issues.push("Pixel count is above 100 MP.");
    if (d.mode !== DocumentMode.RGB) issues.push("Color mode is not RGB.");
    if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) issues.push("Bit depth is not 8-bit.");
    if (d.resolution < 72) notes.push("Resolution is below 72 ppi.");
    try { if (d.layers.length > 1) notes.push("Multiple layers detected; review flattened appearance before export."); } catch(e){}
    notes.push("Adobe Stock uploads should be JPEG/sRGB; PNG has separate requirements.");
    notes.push("Inspect at 100% for noise, halos, banding, blur and unwanted text/logos.");

    var msg = "ADOBE STOCK PRE-FLIGHT\n\nSize: " + w + " × " + h + " px\nPixel count: " + mp.toFixed(2) + " MP\nResolution: " + d.resolution + " ppi\nMode: " + d.mode + "\nBits: " + d.bitsPerChannel + "\n\n";
    msg += issues.length ? "WARNINGS:\n• " + issues.join("\n• ") + "\n\n" : "TECHNICAL PIXEL/MODE CHECK: OK\n\n";
    msg += "MANUAL REVIEW:\n• " + notes.join("\n• ");
    alert(msg);
}
