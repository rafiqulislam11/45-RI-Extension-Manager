#target photoshop
if(!app.documents.length){alert("No document is open.");}
else{
 var a=prompt("Film grain amount (0.1–12):","3");
 if(a!==null){a=parseFloat(a);if(!isNaN(a)&&a>0){a=Math.min(12,Math.max(.1,a));var l=app.activeDocument.activeLayer.duplicate();l.name="ProScript Film Grain";l.applyAddNoise(a,NoiseDistribution.GAUSSIAN,true);l.blendMode=BlendMode.SOFTLIGHT;l.opacity=32;alert("Film grain added.");}}
}