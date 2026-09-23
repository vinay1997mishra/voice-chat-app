package com.anamika.ai.research;

import android.content.Context;
import android.content.SharedPreferences;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;

/** Explicit owner-started notebook for text visible through Android Accessibility. */
public final class ResearchStore {
    private static final String PREF="anamika13_research";
    private static final String ACTIVE="active";
    private static final String FILE="file";
    private static final String QUERY="query";

    private ResearchStore(){}

    public static String start(Context c,String query){
        try{
            File dir=new File(c.getFilesDir(),"research");
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create research folder.");
            File f=new File(dir,"session_"+System.currentTimeMillis()+".jsonl");
            JSONObject head=new JSONObject()
                    .put("type","start")
                    .put("query",query==null?"":query)
                    .put("time_ms",System.currentTimeMillis());
            append(f,head.toString());
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putBoolean(ACTIVE,true)
                    .putString(FILE,f.getAbsolutePath())
                    .putString(QUERY,query==null?"":query)
                    .apply();
            return "Research started. Visible text from screens you open can be saved locally.\n"+f.getAbsolutePath();
        }catch(Exception e){
            return "Research start failed: "+safe(e);
        }
    }

    public static String stop(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        String path=p.getString(FILE,"");
        p.edit().putBoolean(ACTIVE,false).apply();
        return path.isEmpty()?"No research session exists.":"Research stopped. Saved locally:\n"+path;
    }

    public static String status(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        return "Research: "+(p.getBoolean(ACTIVE,false)?"ON":"OFF")+
                "\nQuery: "+p.getString(QUERY,"")+
                "\nFile: "+p.getString(FILE,"");
    }

    public static void recordWindow(Context c,String pkg,AccessibilityNodeInfo root){
        try{
            SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
            if(!p.getBoolean(ACTIVE,false)||root==null)return;
            String path=p.getString(FILE,"");
            if(path.isEmpty())return;
            Set<String> seen=new HashSet<>();
            JSONArray text=new JSONArray();
            collect(root,seen,text,0,200);
            if(text.length()==0)return;
            JSONObject row=new JSONObject()
                    .put("type","screen")
                    .put("time_ms",System.currentTimeMillis())
                    .put("package",pkg==null?"":pkg)
                    .put("text",text);
            append(new File(path),row.toString());
        }catch(Throwable ignored){}
    }

    private static void collect(AccessibilityNodeInfo n,Set<String> seen,JSONArray out,int depth,int max)throws Exception{
        if(n==null||depth>20||out.length()>=max)return;
        add(n.getText(),seen,out,max);
        add(n.getContentDescription(),seen,out,max);
        for(int i=0;i<n.getChildCount()&&out.length()<max;i++){
            AccessibilityNodeInfo child=n.getChild(i);
            if(child!=null){
                try{collect(child,seen,out,depth+1,max);}finally{child.recycle();}
            }
        }
    }

    private static void add(CharSequence cs,Set<String> seen,JSONArray out,int max){
        if(cs==null||out.length()>=max)return;
        String s=cs.toString().trim();
        if(s.length()<2||s.length()>1000||!seen.add(s))return;
        out.put(s);
    }

    private static void append(File f,String line)throws Exception{
        try(FileOutputStream out=new FileOutputStream(f,true)){
            out.write((line+"\n").getBytes(StandardCharsets.UTF_8));
        }
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
