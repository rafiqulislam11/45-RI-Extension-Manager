#target photoshop
if(!app.documents.length){alert("No document is open.");}
else if(!app.activeDocument.saved){alert("Save the document first.");}
else{var d=app.activeDocument,base=d.fullName.parent.fsName+"/"+decodeURI(d.name).replace(/\.[^\.]+$/,""),f=new File(base+"_export.png");d.saveAs(f,new PNGSaveOptions(),true,Extension.LOWERCASE);alert("PNG exported:\n"+f.fsName);}