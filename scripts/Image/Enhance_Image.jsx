#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{
 var l=app.activeDocument.activeLayer.duplicate();l.name="ProScript Enhanced";l.applyUnSharpMask(45,1.2,2);alert("Enhanced layer created.");
}