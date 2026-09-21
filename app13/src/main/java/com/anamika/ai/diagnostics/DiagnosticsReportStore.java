package com.anamika.ai.diagnostics;

import com.anamika.ai.core.AndroidCompat;

import android.content.Context;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Stores redacted diagnostics reports in Anamika private storage. */
public final class DiagnosticsReportStore {
    private DiagnosticsReportStore(){}

    public static File save(Context c,SelfTestEngine.Result result) throws Exception {
        return saveJson(c,result.timeMs,result.json());
    }

    public static File save(Context c,FullDiagnosticsEngine.Result result) throws Exception {
        return saveJson(c,result.timeMs,result.json());
    }

    private static File saveJson(Context c,long timeMs,JSONObject json) throws Exception {
        File dir=new File(c.getFilesDir(),"diagnostics");
        if(!dir.exists()&&!dir.mkdirs())
            throw new IllegalStateException("Cannot create diagnostics directory.");

        byte[] bytes=json.toString(2).getBytes(StandardCharsets.UTF_8);

        File stamped=new File(dir,"diagnostics_"+timeMs+".json");
        try(FileOutputStream out=new FileOutputStream(stamped,false)){
            out.write(bytes);
            out.getFD().sync();
        }

        File latest=new File(dir,"latest.json");
        try(FileOutputStream out=new FileOutputStream(latest,false)){
            out.write(bytes);
            out.getFD().sync();
        }

        prune(dir,10);
        return stamped;
    }

    public static File latest(Context c){
        return new File(new File(c.getFilesDir(),"diagnostics"),"latest.json");
    }

    public static String readLatest(Context c){
        try{
            File f=latest(c);
            if(!f.isFile())return "No diagnostics report yet.";
            return new String(AndroidCompat.readAllBytes(f)),StandardCharsets.UTF_8);
        }catch(Exception e){
            return "Diagnostics report unavailable: "+safe(e);
        }
    }

    private static void prune(File dir,int keep){
        File[] files=dir.listFiles((d,n)->n.startsWith("diagnostics_")&&n.endsWith(".json"));
        if(files==null||files.length<=keep)return;
        java.util.Arrays.sort(files,(a,b)->Long.compare(b.lastModified(),a.lastModified()));
        for(int i=keep;i<files.length;i++)try{files[i].delete();}catch(Exception ignored){}
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
