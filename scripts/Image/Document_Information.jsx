#target photoshop
if (!app.documents.length) { alert("No document is open."); }
else {
  var d=app.activeDocument;
  alert("Document: "+d.name+"\nSize: "+d.width.as("px")+" × "+d.height.as("px")+"\nResolution: "+d.resolution+" ppi\nMode: "+d.mode);
}
