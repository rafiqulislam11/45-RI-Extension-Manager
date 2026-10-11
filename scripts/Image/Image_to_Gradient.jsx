#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{
 try{
  var idMk=charIDToTypeID("Mk  "),desc=new ActionDescriptor(),ref=new ActionReference();
  ref.putClass(stringIDToTypeID("adjustmentLayer"));
  desc.putReference(charIDToTypeID("null"),ref);
  var ld=new ActionDescriptor(),tr=new ActionReference();
  tr.putClass(stringIDToTypeID("gradientMap"));
  ld.putReference(charIDToTypeID("Type"),tr);
  desc.putObject(charIDToTypeID("Usng"),stringIDToTypeID("adjustmentLayer"),ld);
  executeAction(idMk,desc,DialogModes.NO);
  alert("Gradient Map layer created.");
 }catch(e){alert("Gradient operation failed: "+e.message);}
}