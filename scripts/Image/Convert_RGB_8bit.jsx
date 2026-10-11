#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{var d=app.activeDocument;if(d.mode!==DocumentMode.RGB)d.changeMode(ChangeMode.RGB);if(d.bitsPerChannel!==BitsPerChannelType.EIGHT)d.bitsPerChannel=BitsPerChannelType.EIGHT;alert("Converted to RGB 8-bit.");}