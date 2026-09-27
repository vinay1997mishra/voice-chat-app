package com.anamika.ai.plugins;

import android.content.Context;
import android.content.SharedPreferences;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/** Records only UI metadata exposed by Android Accessibility for the owner-opened app. */
public final class BlueprintStore {
    private static final String PREF="anamika13_blueprint";
    private static final String PKG="active_package";
    private static final String FILE="active_file";

    private BlueprintStore(){}

    public static String start(Context c,String pkg,String label){
        try{
            File dir=new File(c.getFilesDir(),"blueprints");
            if(!dir.exists()&&!dir.mkdirs())throw new IllegalStateException("Cannot create blueprint folder.");
            String safe=(label==null||label.trim().isEmpty()?pkg:label).replaceAll("[^A-Za-z0-9._-]+","_");
            File f=new File(dir,safe+"_"+System.currentTimeMillis()+".jsonl");
            JSONObject header=new JSONObject()
                    .put("type","blueprint_start")
                    .put("package",pkg)
                    .put("label",label==null?"":label)
                    .put("created_ms",System.currentTimeMillis());
            append(f,header.toString());
            c.getSharedPreferences(PREF,Context.MODE_PRIVATE).edit()
                    .putString(PKG,pkg)
                    .putString(FILE,f.getAbsolutePath())
                    .apply();
            return "Blueprint scan started for "+label+"\n"+f.getAbsolutePath();
        }catch(Exception e){
            return "Blueprint start failed: "+safe(e);
        }
    }

    public static String stop(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        String path=p.getString(FILE,"");
        p.edit().remove(PKG).remove(FILE).apply();
        return path.isEmpty()?"No blueprint scan was active.":"Blueprint saved:\n"+path;
    }

    public static String status(Context c){
        SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
        String pkg=p.getString(PKG,"");
        String path=p.getString(FILE,"");
        return pkg.isEmpty()?"Blueprint scan: OFF":"Blueprint scan: ON\nPackage: "+pkg+"\nFile: "+path;
    }

    public static void recordWindow(Context c,String pkg,AccessibilityNodeInfo root,String event){
        try{
            SharedPreferences p=c.getSharedPreferences(PREF,Context.MODE_PRIVATE);
            String active=p.getString(PKG,"");
            String path=p.getString(FILE,"");
            if(active.isEmpty()||path.isEmpty()||!active.equals(pkg)||root==null)return;

            JSONArray nodes=new JSONArray();
            collect(root,nodes,0,250);
            JSONObject row=new JSONObject()
                    .put("type","window")
                    .put("time_ms",System.currentTimeMillis())
                    .put("event",event==null?"":event)
                    .put("package",pkg)
                    .put("nodes",nodes);
            append(new File(path),row.toString());
        }catch(Throwable ignored){}
    }

    private static void collect(AccessibilityNodeInfo n,JSONArray out,int depth,int max)throws Exception{
        if(n==null||out.length()>=max||depth>20)return;
        JSONObject o=new JSONObject();
        CharSequence text=n.getText(),desc=n.getContentDescription();
        o.put("text",text==null?"":String.valueOf(text));
        o.put("desc",desc==null?"":String.valueOf(desc));
        o.put("view_id",n.getViewIdResourceName()==null?"":n.getViewIdResourceName());
        o.put("class",n.getClassName()==null?"":String.valueOf(n.getClassName()));
        o.put("clickable",n.isClickable());
        o.put("editable",n.isEditable());
        o.put("scrollable",n.isScrollable());
        o.put("enabled",n.isEnabled());
        android.graphics.Rect r=new android.graphics.Rect();
        n.getBoundsInScreen(r);
        o.put("bounds",r.flattenToString());
        out.put(o);
        for(int i=0;i<n.getChildCount()&&out.length()<max;i++){
            AccessibilityNodeInfo child=n.getChild(i);
            if(child!=null){
                try{collect(child,out,depth+1,max);}finally{child.recycle();}
            }
        }
    }

    private static void append(File f,String line)throws Exception{
        File parent=f.getParentFile();
        if(parent!=null&&!parent.exists()&&!parent.mkdirs())throw new IllegalStateException("Cannot create folder.");
        try(FileOutputStream out=new FileOutputStream(f,true)){
            out.write((line+"\n").getBytes(StandardCharsets.UTF_8));
        }
    }

    private static String safe(Exception e){String m=e.getMessage();return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;}
}
