package com.anamika.ai.files;

import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.*;

public final class FileExportManager {
    private FileExportManager(){}

    public static Uri exportToDownloads(Context c,File source,String mime)throws Exception{
        if(c==null||source==null||!source.isFile()) throw new FileNotFoundException("Output file not found.");
        String type=(mime==null||mime.isEmpty())?"application/octet-stream":mime;
        if(Build.VERSION.SDK_INT>=29){
            ContentValues v=new ContentValues();
            v.put(MediaStore.MediaColumns.DISPLAY_NAME,source.getName());
            v.put(MediaStore.MediaColumns.MIME_TYPE,type);
            v.put(MediaStore.MediaColumns.RELATIVE_PATH,Environment.DIRECTORY_DOWNLOADS+"/Anamika");
            v.put(MediaStore.MediaColumns.IS_PENDING,1);
            Uri uri=c.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,v);
            if(uri==null) throw new IOException("Cannot create Downloads item.");
            boolean ok=false;
            try(OutputStream out=c.getContentResolver().openOutputStream(uri);InputStream in=new FileInputStream(source)){
                if(out==null)throw new IOException("Cannot open Downloads output.");
                byte[] b=new byte[256*1024];int n;while((n=in.read(b))>0)out.write(b,0,n);
                ok=true;
            }finally{
                ContentValues done=new ContentValues();done.put(MediaStore.MediaColumns.IS_PENDING,0);
                c.getContentResolver().update(uri,done,null,null);
                if(!ok) try{c.getContentResolver().delete(uri,null,null);}catch(Exception ignored){}
            }
            return uri;
        }
        File dir=Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
        if(!dir.exists())dir.mkdirs();
        File out=new File(dir,source.getName());
        try(InputStream in=new FileInputStream(source);OutputStream os=new FileOutputStream(out)){
            byte[] b=new byte[256*1024];int n;while((n=in.read(b))>0)os.write(b,0,n);
        }
        return Uri.fromFile(out);
    }
}
