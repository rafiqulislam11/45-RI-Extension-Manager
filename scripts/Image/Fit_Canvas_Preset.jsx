#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{var p=prompt("1=1080x1080\n2=1080x1350\n3=1080x1920\n4=1200x628\n5=1920x1080","1"),s={"1":[1080,1080],"2":[1080,1350],"3":[1080,1920],"4":[1200,628],"5":[1920,1080]}[p];if(s){app.activeDocument.resizeCanvas(UnitValue(s[0],"px"),UnitValue(s[1],"px"),AnchorPosition.MIDDLECENTER);alert("Canvas updated.");}}