package com.anamika.ai.research;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.SharedPreferences;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Owner-started local research notebook. Records only UI text Android exposes.
 * Password fields are intentionally excluded and model weights are not retrained.
 */
public final class ResearchLearningStore {
    private static final String PREFS="anamika_research";
    private static final String ACTIVE="active";
    private static final String QUERY="query";
    private static final String FILE="file";
    private ResearchLearningStore(){ }

    public static String start(Context c,String query){
        try{
            File dir=new File(c.getFilesDir(),"knowledge"); if(!dir.exists()&&!dir.mkdirs()) return "";
            String stamp=new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            File f=new File(dir,"research_"+stamp+".jsonl");
            JSONObject head=new JSONObject().put("type","session").put("query",query).put("started",System.currentTimeMillis());
            append(f,head.toString());
            c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().putBoolean(ACTIVE,true).putString(QUERY,query).putString(FILE,f.getAbsolutePath()).apply();
            return f.getAbsolutePath();
        }catch(Exception e){return "";}
    }

    public static String stop(Context c){
        SharedPreferences p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
        String path=p.getString(FILE,"");
        try{ if(!path.isEmpty()) append(new File(path),new JSONObject().put("type","end").put("ended",System.currentTimeMillis()).toString()); }catch(Exception ignored){}
        p.edit().putBoolean(ACTIVE,false).apply();
        return path;
    }

    public static boolean isActive(Context c){ return c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getBoolean(ACTIVE,false); }
    public static String latestSummary(Context c,int maxChars){
        try{
            File dir=new File(c.getFilesDir(),"knowledge"); File[] files=dir.listFiles((d,n)->n.startsWith("research_")&&n.endsWith(".jsonl"));
            if(files==null||files.length==0)return "";
            java.util.Arrays.sort(files,(a,b)->Long.compare(b.lastModified(),a.lastModified()));
            byte[] data=java.nio.file.Files.readAllBytes(files[0].toPath());
            String text=new String(data,StandardCharsets.UTF_8);
            if(text.length()>maxChars) text=text.substring(text.length()-maxChars);
            return "LATEST OWNER RESEARCH RECORD (visible/public UI only; passwords excluded):\n"+text;
        }catch(Exception e){return "";}
    }

    public static void capture(AccessibilityService service, AccessibilityEvent event){
        if(!isActive(service) || event==null || event.isPassword()) return;
        CharSequence pkg=event.getPackageName(); if(pkg==null) return;
        String p=pkg.toString();
        if(p.equals(service.getPackageName())) return;
        AccessibilityNodeInfo root=service.getRootInActiveWindow(); if(root==null) return;
        Set<String> texts=new LinkedHashSet<>(); collect(root,texts,0);
        if(texts.isEmpty()) return;
        String file=service.getSharedPreferences(PREFS,Context.MODE_PRIVATE).getString(FILE,""); if(file.isEmpty()) return;
        try{
            JSONArray arr=new JSONArray(); int count=0; for(String t:texts){ if(count++>=120) break; arr.put(t); }
            JSONObject o=new JSONObject().put("type","visible_ui").put("time",System.currentTimeMillis()).put("package",p).put("event",event.getEventType()).put("text",arr);
            append(new File(file),o.toString());
        }catch(Exception ignored){}
    }

    private static void collect(AccessibilityNodeInfo n, Set<String> out,int depth){
        if(n==null||depth>18) return;
        if(!n.isPassword()){
            add(out,n.getText()); add(out,n.getContentDescription()); add(out,n.getHintText());
        }
        for(int i=0;i<n.getChildCount();i++){ AccessibilityNodeInfo ch=n.getChild(i); if(ch!=null) collect(ch,out,depth+1); }
    }
    private static void add(Set<String> out,CharSequence cs){ if(cs==null)return; String s=cs.toString().trim(); if(s.length()>=2&&s.length()<=500)out.add(s); }
    private static synchronized void append(File f,String s)throws Exception{ try(FileOutputStream o=new FileOutputStream(f,true)){o.write((s+"\n").getBytes(StandardCharsets.UTF_8));} }
}
