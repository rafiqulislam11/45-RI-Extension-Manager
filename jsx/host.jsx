/* Cross-host ExtendScript bootstrap for Photoshop & Illustrator CEP */
/* Note: Do NOT use a custom isolated #targetengine here to prevent scope separation from evalScript */

if (typeof $.global === "undefined") {
    $.global = this;
}

// Lightweight ES3 JSON polyfill for ExtendScript
if (typeof $.global.JSON === "undefined" || !$.global.JSON) {
    $.global.JSON = {
        parse: function (s) {
            if (typeof s !== "string") return s;
            var str = s.replace(/^\s+|\s+$/g, "");
            return eval("(" + str + ")");
        },
        stringify: function (obj) {
            if (obj === null) return "null";
            if (obj === undefined) return undefined;
            var t = typeof obj;
            if (t === "number" || t === "boolean") return String(obj);
            if (t === "string") {
                return '"' + obj.replace(/\\/g, "\\\\")
                                .replace(/"/g, '\\"')
                                .replace(/\n/g, "\\n")
                                .replace(/\r/g, "\\r") + '"';
            }
            if (obj instanceof Array) {
                var a = [];
                for (var i = 0; i < obj.length; i++) {
                    a.push(this.stringify(obj[i]));
                }
                return "[" + a.join(",") + "]";
            }
            if (t === "object") {
                var pairs = [];
                for (var k in obj) {
                    if (obj.hasOwnProperty(k)) {
                        pairs.push('"' + k + '":' + this.stringify(obj[k]));
                    }
                }
                return "{" + pairs.join(",") + "}";
            }
            return String(obj);
        }
    };
}
var JSON = $.global.JSON;

// Determine host application
var _psrAppName = (typeof app !== "undefined" && app && app.name) ? String(app.name).toLowerCase() : "";
var _psrIsIllustrator = (_psrAppName.indexOf("illustrator") !== -1);

// Safely load the appropriate host engine
(function () {
    try {
        var baseDir = "";
        if (typeof $.fileName !== "undefined" && $.fileName) {
            baseDir = (new File($.fileName)).parent.fsName;
        }
        if (_psrIsIllustrator) {
            if (typeof PSR_Illustrator === "undefined") {
                if (baseDir) {
                    var fAi = new File(baseDir + "/illustrator.jsx");
                    if (fAi.exists) $.evalFile(fAi);
                }
            }
        } else {
            if (typeof PSR_Photoshop === "undefined") {
                if (baseDir) {
                    var fPs = new File(baseDir + "/photoshop.jsx");
                    if (fPs.exists) $.evalFile(fPs);
                }
            }
        }
    } catch (loadErr) {
        // Fallback to static include if dynamic evalFile fails
        try {
            if (_psrIsIllustrator) {
                #include "illustrator.jsx"
            } else {
                #include "photoshop.jsx"
            }
        } catch (incErr) {}
    }
})();

// Unified ProScriptRunner API
var ProScriptRunner = (function () {
    function getRunner() {
        if (_psrIsIllustrator) {
            return (typeof PSR_Illustrator !== "undefined") ? PSR_Illustrator : null;
        }
        return (typeof PSR_Photoshop !== "undefined") ? PSR_Photoshop : null;
    }

    return {
        isReady: function () {
            return (getRunner() !== null);
        },
        getHostInfo: function () {
            var runner = getRunner();
            if (runner && typeof runner.getHostInfo === "function") {
                return runner.getHostInfo();
            }
            var hasDoc = (typeof app !== "undefined" && app && app.documents && app.documents.length > 0);
            return JSON.stringify({
                app: _psrIsIllustrator ? "Illustrator" : "Photoshop",
                version: (typeof app !== "undefined" && app && app.version) ? app.version : "Unknown",
                hasDoc: hasDoc,
                ready: (runner !== null),
                doc: null
            });
        },
        run: function (payload) {
            try {
                var runner = getRunner();
                if (runner && typeof runner.run === "function") {
                    return runner.run(payload);
                }
                var appName = (typeof app !== "undefined" && app && app.name) ? app.name : "host";
                return "PSR_ERR|Script runner is not initialized for " + appName;
            } catch (e) {
                return "PSR_ERR|" + (e && e.message ? e.message : String(e));
            }
        }
    };
})();

$.global.ProScriptRunner = ProScriptRunner;
