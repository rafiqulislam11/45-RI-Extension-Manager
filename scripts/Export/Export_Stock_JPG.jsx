#target photoshop
if (!app.documents.length) {
    alert("No Photoshop document is open.");
} else if (!app.activeDocument.saved) {
    alert("Save the document before stock export.");
} else {
    var d = app.activeDocument;
    var w = d.width.as("px"), h = d.height.as("px"), mp = (w * h) / 1000000;
    if (mp < 4 || mp > 100) {
        alert("Stock export stopped: image is " + mp.toFixed(2) + " MP. Target range is 4–100 MP.");
    } else {
        var base = d.fullName.parent.fsName + "/" + decodeURI(d.name).replace(/\.[^\.]+$/, "");
        var f = new File(base + "_stock.jpg"), work = null;
        try {
            work = d.duplicate();
            if (work.mode !== DocumentMode.RGB) work.changeMode(ChangeMode.RGB);
            if (work.bitsPerChannel !== BitsPerChannelType.EIGHT) work.bitsPerChannel = BitsPerChannelType.EIGHT;
            try { work.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, true); } catch(err){}
            var o = new JPEGSaveOptions(); o.quality = 12; o.embedColorProfile = true;
            work.saveAs(f, o, true, Extension.LOWERCASE);
            work.close(SaveOptions.DONOTSAVECHANGES); work = null;
            var mb = f.length / 1048576;
            alert("Stock-ready JPG copy exported:\n" + f.fsName + "\nSize: " + mb.toFixed(2) + " MB");
        } catch(e) {
            try { if (work) work.close(SaveOptions.DONOTSAVECHANGES); } catch(x){}
            alert("Export failed: " + e.message);
        }
    }
}
