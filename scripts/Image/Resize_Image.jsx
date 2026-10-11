#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{var d=app.activeDocument,w=prompt("Width (px):",d.width.as("px")),h=prompt("Height (px):",d.height.as("px"));if(w&&h){d.resizeImage(UnitValue(parseFloat(w),"px"),UnitValue(parseFloat(h),"px"),d.resolution,ResampleMethod.BICUBIC);alert("Resize complete.");}}