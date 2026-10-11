#target photoshop
if (!app.documents.length) { alert("No document is open."); }
else if (confirm("Flatten the active document?")) { app.activeDocument.flatten(); alert("Done."); }
