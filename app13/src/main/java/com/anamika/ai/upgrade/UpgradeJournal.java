package com.anamika.ai.upgrade;

import android.content.Context;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Append-only private audit journal for owner self-upgrade operations. */
public final class UpgradeJournal {
    private UpgradeJournal(){}

    public static void record(Context c,String state,String detail){
        try{
            File dir=new File(c.getFilesDir(),"v13_upgrade");
            if(!dir.exists()&&!dir.mkdirs())return;
            File f=new File(dir,"journal.jsonl");
            JSONObject o=new JSONObject()
                    .put("time_ms",System.currentTimeMillis())
                    .put("state",state==null?"":state)
                    .put("detail",detail==null?"":detail);
            try(FileOutputStream out=new FileOutputStream(f,true)){
                out.write((o.toString()+"\n").getBytes(StandardCharsets.UTF_8));
            }
        }catch(Exception ignored){}
    }
}
