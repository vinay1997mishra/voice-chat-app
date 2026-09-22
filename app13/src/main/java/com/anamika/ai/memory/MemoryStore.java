package com.anamika.ai.memory;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/** Private local conversation journal and one explicit owner note. */
public final class MemoryStore {
    private static final String PREF="anamika13_memory";
    private static final String NOTE="owner_note";
    private static final long MAX_HISTORY=2L*1024L*1024L;

    private MemoryStore(){}

    public static void appendTurn(Context c,String role,String text){
        if(text==null||text.trim().isEmpty())return;
        try{
            File dir=new File(c.getFilesDir(),"memory");
            if(!dir.exists()&&!dir.mkdirs())return;
            File f=new File(dir,"conversation.jsonl");
            if(f.length()>MAX_HISTORY){
                File old=new File(dir,"conversation.previous.jsonl");
                if(old.exists())old.delete();
                if(!f.renameTo(old)) return;
            }
            JSONObject o=new JSONObject()
                    .put("time_ms",System.currentTimeMillis())
                    .put("role",role==null?"":role)
                    .put("text",text);
            try(FileOutputStream out=new FileOutputStream(f,true)){
                out.write((o.toString()+"\n").getBytes(StandardCharsets.UTF_8));
            }
        }catch(Exception ignored){}
    }

    public static String saveNote(Context c,String note){
        String n=note==null?"":note.trim();
        c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit().putString(NOTE,n).apply();
        return n.isEmpty()?"Memory note cleared.":"Memory note saved locally.";
    }

    public static String promptContext(Context c,int maxTurns,int maxChars){
        int turns=Math.max(1,Math.min(40,maxTurns));
        int chars=Math.max(1000,Math.min(32000,maxChars));
        String note=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(NOTE,"");
        File f=new File(new File(c.getFilesDir(),"memory"),"conversation.jsonl");

        List<String> picked=new ArrayList<>();
        if(f.isFile()){
            try{
                String raw=new String(java.nio.file.Files.readAllBytes(f.toPath()),StandardCharsets.UTF_8);
                String[] lines=raw.split("\\r?\\n");
                for(int i=lines.length-1;i>=0&&picked.size()<turns;i--){
                    String line=lines[i].trim();
                    if(line.isEmpty())continue;
                    try{
                        JSONObject o=new JSONObject(line);
                        String role=o.optString("role","").trim();
                        String text=o.optString("text","").trim();
                        if(text.isEmpty())continue;
                        String label="owner".equalsIgnoreCase(role)?"Owner":"Anamika";
                        picked.add(0,label+": "+text);
                    }catch(Exception ignored){}
                }
            }catch(Exception ignored){}
        }

        StringBuilder b=new StringBuilder();
        if(!note.trim().isEmpty())b.append("OWNER MEMORY NOTE:\n").append(note.trim()).append("\n\n");
        if(!picked.isEmpty()){
            b.append("RECENT CHAT HISTORY:\n");
            for(String x:picked){
                if(b.length()+x.length()+1>chars)break;
                b.append(x).append("\n");
            }
        }
        String out=b.toString().trim();
        if(out.length()>chars)out=out.substring(out.length()-chars);
        return out;
    }

    public static String summary(Context c){
        String note=c.getSharedPreferences(PREF,Context.MODE_PRIVATE).getString(NOTE,"");
        File f=new File(new File(c.getFilesDir(),"memory"),"conversation.jsonl");
        return "Local memory\nOwner note: "+(note.isEmpty()?"none":note)+
                "\nConversation history: "+(f.isFile()?f.length()+" bytes":"empty");
    }
}
