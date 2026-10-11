#target photoshop
if(!app.documents.length){alert("No document is open.");}
else if(!app.activeDocument.saved){alert("Save the document first.");}
else{var d=app.activeDocument,base=d.fullName.parent.fsName+"/"+decodeURI(d.name).replace(/\.[^\.]+$/,""),f=new File(base+"_web.jpg"),o=new JPEGSaveOptions();o.quality=8;d.saveAs(f,o,true,Extension.LOWERCASE);alert("Web JPG exported:\n"+f.fsName);}