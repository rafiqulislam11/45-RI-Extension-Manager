#target photoshop
if(!app.documents.length){alert("No document is open.");}
else if(!app.activeDocument.saved){alert("Save the document first.");}
else{var d=app.activeDocument,base=d.fullName.parent.fsName+"/"+decodeURI(d.name).replace(/\.[^\.]+$/,""),f=new File(base+"_copy.psd");d.saveAs(f,new PhotoshopSaveOptions(),true,Extension.LOWERCASE);alert("PSD copy saved:\n"+f.fsName);}