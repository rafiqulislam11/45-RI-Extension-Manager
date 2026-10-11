#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{app.activeDocument.activeLayer.applyUnSharpMask(65,1.1,2);alert("Sharpen complete.");}