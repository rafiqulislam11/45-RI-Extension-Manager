#target photoshop
if(!app.documents.length){alert("No document is open.");}else{app.activeDocument.trim(TrimType.TRANSPARENT,true,true,true,true);alert("Transparent edges trimmed.");}