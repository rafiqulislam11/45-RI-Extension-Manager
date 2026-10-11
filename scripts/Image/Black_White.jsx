#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{app.activeDocument.activeLayer.desaturate();alert("Black & white conversion complete.");}