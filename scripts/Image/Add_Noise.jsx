#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{
 var a=prompt("Noise amount (0.1–20):","4");
 if(a!==null){a=parseFloat(a);if(!isNaN(a)&&a>0){a=Math.min(20,Math.max(.1,a));app.activeDocument.activeLayer.applyAddNoise(a,NoiseDistribution.GAUSSIAN,true);alert("Noise added: "+a+"%.");}}
}