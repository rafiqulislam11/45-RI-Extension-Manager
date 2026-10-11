/* Pro Script Runner - Photoshop Runner Alias
   This file provides compatibility for scripts or manifests referencing runner.jsx.
   It delegates directly to the robust PSR_Photoshop engine.
*/
#target photoshop

(function () {
    var baseDir = "";
    try {
        if (typeof $.fileName !== "undefined" && $.fileName) {
            baseDir = (new File($.fileName)).parent.fsName;
            var psFile = new File(baseDir + "/photoshop.jsx");
            if (psFile.exists) {
                $.evalFile(psFile);
            }
        }
    } catch (e) {}
})();

var ProScriptRunner = (typeof PSR_Photoshop !== "undefined") ? PSR_Photoshop : {
    run: function (payload) {
        return "PSR_ERR|Photoshop engine not initialized.";
    }
};

if (typeof $.global !== "undefined") {
    $.global.ProScriptRunner = ProScriptRunner;
}
