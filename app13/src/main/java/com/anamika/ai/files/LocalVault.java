package com.anamika.ai.files;

import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Private app storage for owner notes and generated artifacts. */
public final class LocalVault {
    private LocalVault(){}

    public static File root(Context c){
        File f=new File(c.getFilesDir(),"vault");
        if(!f.exists())f.mkdirs();
        return f;
    }

    public static String saveText(Context c,String name,String content){
        try{
            String safeName=(name==null?"note.txt":name).replaceAll("[^A-Za-z0-9._-]+","_");
            if(safeName.isEmpty())safeName="note.txt";
            File f=new File(root(c),safeName);
            try(FileOutputStream out=new FileOutputStream(f,false)){
                out.write((content==null?"":content).getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            return "Saved in private vault: "+f.getAbsolutePath();
        }catch(Exception e){
            return "Vault save failed: "+safe(e);
        }
    }

    public static String summary(Context c){
        File dir=root(c);
        File[] files=dir.listFiles();
        long bytes=0;
        int count=0;
        if(files!=null)for(File f:files)if(f.isFile()){count++;bytes+=f.length();}
        return "Private vault\nFiles: "+count+"\nSize: "+bytes+" bytes\nPath: "+dir.getAbsolutePath();
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
