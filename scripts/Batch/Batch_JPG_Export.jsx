#target photoshop
var folder=Folder.selectDialog("Select PSD/PSB folder");
if(folder){
  var fs=folder.getFiles(function(f){return f instanceof File && /\.(psd|psb)$/i.test(f.name);});
  var out=new Folder(folder.fsName+"/ProScript JPG"); if(!out.exists) out.create();
  var done=0;
  for(var i=0;i<fs.length;i++){
    try{
      var d=app.open(fs[i]);
      var f=new File(out.fsName+"/"+fs[i].name.replace(/\.[^\.]+$/,"")+".jpg");
      var o=new JPEGSaveOptions(); o.quality=10;
      d.saveAs(f,o,true,Extension.LOWERCASE);
      d.close(SaveOptions.DONOTSAVECHANGES); done++;
    }catch(e){}
  }
  alert("Batch complete: "+done+" of "+fs.length);
}
