#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else {
    var d = app.activeDocument, w = Math.round(d.width.as("px")), h = Math.round(d.height.as("px"));
    var report = [
        "Size: " + w + " × " + h + " px",
        "Resolution: " + d.resolution + " ppi",
        "Mode: " + d.mode,
        "Bits: " + d.bitsPerChannel
    ];
    if (d.mode !== DocumentMode.RGB || d.bitsPerChannel !== BitsPerChannelType.EIGHT) {
        if (confirm("Document is not RGB 8-bit. Convert it now for a safer export workflow?")) {
            if (d.mode !== DocumentMode.RGB) d.changeMode(ChangeMode.RGB);
            if (d.bitsPerChannel !== BitsPerChannelType.EIGHT) d.bitsPerChannel = BitsPerChannelType.EIGHT;
            report.push("Converted to RGB 8-bit.");
        }
    }
    alert("STOCK PREP CHECKLIST\n\n" + report.join("\n") + "\n\nBefore submission, review artifacts, noise, halos and overall commercial suitability.");
}
