#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{app.activeDocument.autoTone();app.activeDocument.autoContrast();app.activeDocument.autoColor();alert("Auto enhancement complete.");}