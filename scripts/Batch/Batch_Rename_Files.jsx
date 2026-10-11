#target photoshop
var folder = Folder.selectDialog("Select a folder to rename image files");
if (folder) {
    var prefix = prompt("Prefix:", "Design");
    if (prefix !== null) {
        var files = folder.getFiles(function(f) { return f instanceof File && /\.(jpg|jpeg|png|tif|tiff|psd|psb)$/i.test(f.name); });
        if (!files.length) {
            alert("No supported files found.");
        } else {
            var done = 0;
            for (var i = 0; i < files.length; i++) {
                try {
                    var ext = files[i].name.match(/\.[^\.]+$/)[0];
                    var target = new File(folder.fsName + "/" + prefix + "_" + ("000" + (i + 1)).slice(-3) + ext);
                    if (files[i].rename(target.name)) done++;
                } catch(e){}
            }
            alert("Renamed " + done + " file(s).");
        }
    }
}
