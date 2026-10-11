#target photoshop
if (!app.documents.length) { alert("No document is open."); }
else if (!app.activeDocument.saved) { alert("Save the document first."); }
else {
  var d=app.activeDocument;
  var base=d.fullName.parent.fsName+"/"+decodeURI(d.name).replace(/\.[^\.]+$/,"");
  var f=new File(base+"_export.jpg");
  var o=new JPEGSaveOptions(); o.quality=10;
  d.saveAs(f,o,true,Extension.LOWERCASE);
  alert("Exported:\n"+f.fsName);
}
