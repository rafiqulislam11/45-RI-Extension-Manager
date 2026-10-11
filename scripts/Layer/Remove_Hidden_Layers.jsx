#target photoshop
if(!app.documents.length){alert("No document is open.");}
else if(confirm("Delete hidden top-level layers?")){var d=app.activeDocument,n=0;for(var i=d.layers.length-1;i>=0;i--){try{if(!d.layers[i].visible){d.layers[i].remove();n++;}}catch(e){}}alert("Removed "+n+" layer(s).");}