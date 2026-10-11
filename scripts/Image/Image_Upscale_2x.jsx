#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{
 var d=app.activeDocument,w=d.width.as("px")*2,h=d.height.as("px")*2;
 if(confirm("Upscale to 200%?\n"+w+" × "+h+" px")){
   d.resizeImage(UnitValue(w,"px"),UnitValue(h,"px"),d.resolution,ResampleMethod.BICUBICSMOOTHER);
   alert("2× Upscale complete.");
 }
}